import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/models/models.dart';

import 'models.dart';
import 'parse_utils.dart';

class WorkerUnifiedBackupParser {
  const WorkerUnifiedBackupParser({
    required this.limits,
    required this.workerBaseUrl,
  });

  final BackupArchiveLimits limits;
  final String workerBaseUrl;

  static const _utils = BackupParseUtils();

  Future<UnifiedRestoreModel> parse(StagedBackupArchive staged) async {
    final manifest = await _utils.readJsonObject(
      staged.requireFile(
        'manifest.json',
        maxBytes: limits.maxManifestBytes,
      ),
      'manifest.json',
    );
    _validateManifestHeader(manifest);

    final manifestFiles = _utils.objectMap(
      manifest['files'],
      field: 'manifest.files',
    );
    await _validateManifestFiles(staged, manifestFiles);

    final config = await _utils.readYamlObject(
      staged.requireFile('config.yaml'),
      'config.yaml',
    );
    if (config.isEmpty) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        'config.yaml 为空',
      );
    }
    await _utils.readYamlObject(
      staged.requireFile('verge.yaml'),
      'verge.yaml',
    );
    final profilesYaml = await _utils.readYamlObject(
      staged.requireFile('profiles.yaml'),
      'profiles.yaml',
    );

    final airports = _readAirports(manifest);
    final rawItems = profilesYaml['items'];
    final currentUid = profilesYaml['current'];
    if (rawItems is! List ||
        rawItems.isEmpty ||
        currentUid is! String ||
        !airports.containsKey(currentUid)) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        'profiles.yaml 的 current/items 无效',
      );
    }

    final profiles = <Profile>[];
    final profileFiles = <RestoreSourceFile>[];
    final idByUid = <String, int>{};
    final usedIds = <int>{};

    for (var index = 0; index < rawItems.length; index++) {
      final item = _utils.objectMap(
        rawItems[index],
        field: 'profiles.items[$index]',
      );
      final uid = item['uid'];
      if (uid is! String || !airports.containsKey(uid)) {
        throw const BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          'profiles.yaml 含有 manifest 未声明的 Profile',
        );
      }
      if (idByUid.containsKey(uid)) {
        throw const BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          'profiles.yaml 含有重复 Profile UID',
        );
      }

      final airport = airports[uid]!;
      final slug = airport['slug']! as String;
      final name = item['name'];
      final url = item['url'];
      final fileName = item['file'];
      if (name is! String ||
          name.trim().isEmpty ||
          url is! String ||
          fileName != '$uid.yaml') {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          'profiles.yaml Profile 字段无效：$uid',
        );
      }
      _validateProfileUrl(url, slug);

      final profilePath = 'profiles/$uid.yaml';
      final sourceProfile = staged.requireFile(profilePath);
      await _utils.readYamlObject(sourceProfile, profilePath);
      _crossCheckArtifactHashes(
        staged: staged,
        manifestFiles: manifestFiles,
        airport: airport,
        uid: uid,
        slug: slug,
      );

      final id = _utils.stableProfileId(uid, usedIds);
      usedIds.add(id);
      idByUid[uid] = id;
      final option = item['option'] == null
          ? <String, Object?>{}
          : _utils.objectMap(
              item['option'],
              field: 'profiles.items[$index].option',
            );
      final extra = item['extra'] == null
          ? null
          : _utils.objectMap(
              item['extra'],
              field: 'profiles.items[$index].extra',
            );
      final interval = _utils.intValue(option['update_interval']);
      final updated = _utils.intValue(item['updated']);

      profiles.add(
        Profile(
          id: id,
          label: name.trim(),
          url: url,
          lastUpdateDate: updated == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  updated * 1000,
                  isUtc: true,
                ).toLocal(),
          autoUpdateDuration: interval != null && interval > 0
              ? Duration(minutes: interval)
              : defaultUpdateDuration,
          subscriptionInfo: extra == null
              ? null
              : SubscriptionInfo(
                  upload: _utils.intValue(extra['upload']) ?? 0,
                  download: _utils.intValue(extra['download']) ?? 0,
                  total: _utils.intValue(extra['total']) ?? 0,
                  expire: _utils.intValue(extra['expire']) ?? 0,
                ),
          autoUpdate: option['allow_auto_update'] is bool
              ? option['allow_auto_update']! as bool
              : true,
          order: index,
        ),
      );
      profileFiles.add(
        RestoreSourceFile(
          source: sourceProfile,
          relativeTarget: '$id.yaml',
        ),
      );
    }

    if (profiles.length != airports.length) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        'manifest 与 profiles.yaml 的 Profile 数量不一致',
      );
    }

    return UnifiedRestoreModel(
      format: BackupArchiveFormat.workerUnifiedV1,
      profiles: profiles,
      currentProfileId: idByUid[currentUid],
      profileFiles: profileFiles,
      invalidateProviderCaches: true,
      stagingDirectory: staged.directory,
    );
  }

  void _validateManifestHeader(Map<String, Object?> manifest) {
    if (manifest['format'] != 'mihomo-unified-backup' ||
        manifest['archiveType'] != 'unified-subscription-archive') {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidManifest,
        'manifest.json 不是统一母包',
      );
    }
    final version = _utils.intValue(manifest['formatVersion']);
    if (version != 1) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.unsupportedVersion,
        '不支持的统一母包版本：${manifest['formatVersion']}',
      );
    }
    final publicBaseUrl = manifest['publicBaseUrl'];
    if (publicBaseUrl is! String ||
        _utils.normalizeBaseUrl(publicBaseUrl) !=
            _utils.normalizeBaseUrl(workerBaseUrl)) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidWorkerUrl,
        '统一母包来源不是当前固定 Worker 地址',
      );
    }
  }

  Future<void> _validateManifestFiles(
    StagedBackupArchive staged,
    Map<String, Object?> manifestFiles,
  ) async {
    for (final requiredPath in const [
      'config.yaml',
      'verge.yaml',
      'profiles.yaml',
    ]) {
      if (!manifestFiles.containsKey(requiredPath)) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.missingRequiredFile,
          'manifest 缺少必需文件声明：$requiredPath',
        );
      }
    }

    final declared = <String>{};
    for (final entry in manifestFiles.entries) {
      final path = _utils.canonicalArchivePath(entry.key);
      if (path != entry.key || !declared.add(path)) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidManifest,
          'manifest 包含重复或非规范路径：${entry.key}',
        );
      }
      final descriptor = _utils.objectMap(
        entry.value,
        field: 'manifest.files.${entry.key}',
      );
      final required = descriptor['required'];
      if (required is! bool) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidManifest,
          'manifest 文件 required 字段无效：${entry.key}',
        );
      }
      final file = staged.files[path];
      if (file == null) {
        if (required) {
          throw BackupRestoreException(
            BackupRestoreErrorCode.missingRequiredFile,
            '统一母包缺少必需文件：$path',
          );
        }
        continue;
      }
      final expectedLength = _utils.intValue(descriptor['contentLength']);
      final expectedHash = descriptor['sha256'];
      if (expectedLength == null ||
          expectedLength < 0 ||
          expectedHash is! String ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedHash)) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidManifest,
          'manifest 文件摘要字段无效：$path',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.length != expectedLength ||
          sha256.convert(bytes).toString().toLowerCase() !=
              expectedHash.toLowerCase()) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.hashMismatch,
          '文件长度或哈希与 manifest 不一致：$path',
        );
      }
    }

    for (final path in staged.files.keys) {
      if (path != 'manifest.json' && !manifestFiles.containsKey(path)) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidManifest,
          '统一母包含有未声明文件：$path',
        );
      }
    }
  }

  Map<String, Map<String, Object?>> _readAirports(
    Map<String, Object?> manifest,
  ) {
    final raw = manifest['airports'];
    if (raw is! List || raw.isEmpty) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidManifest,
        'manifest.airports 为空或无效',
      );
    }
    final byUid = <String, Map<String, Object?>>{};
    final slugs = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final airport = _utils.objectMap(
        raw[index],
        field: 'manifest.airports[$index]',
      );
      final uid = airport['profileUid'];
      final slug = airport['slug'];
      if (uid is! String ||
          uid.isEmpty ||
          slug is! String ||
          !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(slug) ||
          byUid.containsKey(uid) ||
          !slugs.add(slug)) {
        throw const BackupRestoreException(
          BackupRestoreErrorCode.invalidManifest,
          'manifest.airports 包含重复或无效标识',
        );
      }
      byUid[uid] = airport;
    }
    return byUid;
  }

  void _crossCheckArtifactHashes({
    required StagedBackupArchive staged,
    required Map<String, Object?> manifestFiles,
    required Map<String, Object?> airport,
    required String uid,
    required String slug,
  }) {
    final profilePath = 'profiles/$uid.yaml';
    final manifestProfileHash = _manifestHash(manifestFiles, profilePath);
    final airportProfileHash = airport['profileSha256'];
    if (airportProfileHash is! String ||
        airportProfileHash.toLowerCase() !=
            manifestProfileHash.toLowerCase()) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.hashMismatch,
        'Profile 摘要交叉校验失败：$uid',
      );
    }

    final providerPath = 'providers/$slug/provider.yaml';
    if (staged.files.containsKey(providerPath)) {
      final providerHash = airport['providerSha256'];
      final manifestProviderHash = _manifestHash(
        manifestFiles,
        providerPath,
      );
      if (providerHash is! String ||
          providerHash.toLowerCase() !=
              manifestProviderHash.toLowerCase()) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.hashMismatch,
          'Provider 摘要交叉校验失败：$slug',
        );
      }
    }
  }

  String _manifestHash(Map<String, Object?> files, String path) {
    final descriptor = _utils.objectMap(
      files[path],
      field: 'manifest.files.$path',
    );
    final hash = descriptor['sha256'];
    if (hash is! String) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.invalidManifest,
        'manifest 缺少文件摘要：$path',
      );
    }
    return hash;
  }

  void _validateProfileUrl(String value, String slug) {
    final uri = Uri.tryParse(value);
    final expectedBase = Uri.parse(workerBaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.host.toLowerCase() != expectedBase.host.toLowerCase() ||
        uri.port != expectedBase.port ||
        uri.pathSegments.length != 3 ||
        uri.pathSegments[0] != 'config' ||
        uri.pathSegments[1] != slug ||
        uri.pathSegments[2].isEmpty) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.invalidWorkerUrl,
        'Profile 订阅地址不是 Worker 固定地址：$slug',
      );
    }
  }
}
