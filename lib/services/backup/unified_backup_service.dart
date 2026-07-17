import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/unified_backup_export/models.dart';
import 'package:path/path.dart' as p;

import 'backup_format_detector.dart';
import 'legacy_backup_parser.dart';
import 'restore_bundle.dart';
import 'restore_service.dart';
import 'worker_v1_parser.dart';
import 'worker_v1_models.dart';

/// The single format-detection, conversion and commit entry point used by
/// local-file and WebDAV restores.
class UnifiedBackupService {
  UnifiedBackupService({
    required this.database,
    required this.paths,
    this.validateProfileYaml,
    this.readConfig,
    this.writeConfig,
  });

  final Database database;
  final RestorePaths paths;
  final ProfileYamlValidator? validateProfileYaml;
  final RestoreConfigReader? readConfig;
  final RestoreConfigWriter? writeConfig;

  Future<RestoreCommitResult> restoreBytes(
    Uint8List bytes, {
    required bool override,
  }) async {
    final format = const BackupFormatDetector().detectBytes(bytes);
    final bundle = switch (format) {
      BackupFormat.workerUnifiedV1 => _workerBundle(
        const WorkerV1Parser().parse(bytes),
        bytes,
      ),
      _ => await _legacyBundle(const LegacyBackupParser().parseBytes(bytes)),
    };
    return RestoreService(
      database: database,
      paths: paths,
      validateProfileYaml: validateProfileYaml,
      readConfig: readConfig,
      writeConfig: writeConfig,
    ).restore(bundle, override: override);
  }

  Future<RestoreBundle> _legacyBundleV3(LegacyParsedPackage package) async {
    // v3 format is treated like v2 for core logic
    // The Clash Verge Rev compatibility projections (profiles.yaml, profiles/R*.yaml)
    // are in the outer ZIP but don't affect Slclash restore
    final profiles = package.profiles
        .map((raw) {
          final map = _normalizeLegacyProfile(raw);
          return Profile.fromJson(map);
        })
        .toList(growable: false);
    final scripts = _maps(
      package.metadata['scripts'],
    ).map(Script.fromJson).toList();
    final rules = _maps(package.metadata['rules']).map(Rule.fromJson).toList();
    final links = _maps(package.metadata['links']).map(_linkFromJson).toList();
    final proxyGroups = _maps(
      package.metadata['proxyGroups'],
    ).map(ProxyGroup.fromJson).toList();
    final config = _restoreConfig(
      package.metadata['config'] is Map
          ? Map<String, dynamic>.from(package.metadata['config'] as Map)
          : package.config,
    );
    final workerUnifiedArchive = _validatedEmbeddedWorkerArchiveV3(
      package,
      profiles,
    );
    return RestoreBundle(
      sourceFormat: BackupSourceFormat.slclashProfilesV2, // v3 treated as v2
      profiles: profiles,
      scripts: scripts,
      rules: rules,
      links: links,
      proxyGroups: proxyGroups,
      config: config,
      currentProfileId: package.currentProfileId,
      files: _currentFiles(package.files, profiles, scripts),
      providerCachePolicy: ProviderCachePolicy.invalidateRestoredProfiles,
      workerUnifiedArchive: workerUnifiedArchive,
      replaceWorkerUnifiedArchive: true,
    );
  }

  RestoreBundle _workerBundle(WorkerV1Package package, Uint8List archiveBytes) {
    final publicBaseUrl = package.manifest.raw['publicBaseUrl'] as String;
    final items = package.profilesYaml['items'];
    if (items is! List || items.isEmpty) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'profiles.yaml contains no profiles',
      );
    }
    final profiles = <Profile>[];
    final files = <StagedRestoreFile>[];
    final uidToId = <String, int>{};
    for (final raw in items) {
      if (raw is! Map) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'profiles.yaml contains an invalid profile',
        );
      }
      final item = Map<String, Object?>.from(raw);
      final uid = item['uid'];
      final name = item['name'];
      final fileName = item['file'];
      final url = item['url'];
      if (uid is! String ||
          !RegExp(r'^R[0-9a-f]{8}$').hasMatch(uid) ||
          name is! String ||
          fileName != '$uid.yaml' ||
          url is! String ||
          !url.startsWith('$publicBaseUrl/config/')) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'profiles.yaml contains invalid profile fields',
        );
      }
      final id = int.parse(uid.substring(1), radix: 16);
      if (uidToId.containsValue(id)) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'profiles.yaml contains duplicate profile identifiers',
        );
      }
      uidToId[uid] = id;
      final yaml = package.files['profiles/$fileName'];
      if (yaml == null || yaml.isEmpty) {
        throw const BackupFormatException(
          BackupErrorCode.missingRequiredFile,
          'A required profile file is missing',
        );
      }
      final option = item['option'] is Map
          ? Map<Object?, Object?>.from(item['option'] as Map)
          : const <Object?, Object?>{};
      final allowAutoUpdate = option['allow_auto_update'];
      final updateIntervalMinutes = option['update_interval'];
      if ((allowAutoUpdate != null && allowAutoUpdate is! bool) ||
          (updateIntervalMinutes != null &&
              (updateIntervalMinutes is! int ||
                  updateIntervalMinutes <= 0 ||
                  updateIntervalMinutes > maxClientUpdateIntervalMinutes))) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'profiles.yaml contains an invalid client update policy',
        );
      }
      final extra = item['extra'] is Map
          ? Map<Object?, Object?>.from(item['extra'] as Map)
          : const <Object?, Object?>{};
      final updated = item['updated'];
      profiles.add(
        Profile(
          id: id,
          label: name,
          url: url,
          lastUpdateDate: updated is int
              ? DateTime.fromMillisecondsSinceEpoch(updated * 1000, isUtc: true)
              : null,
          autoUpdateDuration: Duration(
            minutes: updateIntervalMinutes is int ? updateIntervalMinutes : 60,
          ),
          autoUpdate: allowAutoUpdate is bool ? allowAutoUpdate : true,
          subscriptionInfo: extra.isEmpty
              ? null
              : SubscriptionInfo(
                  upload: _integer(extra['upload']),
                  download: _integer(extra['download']),
                  total: _integer(extra['total']),
                  expire: _integer(extra['expire']),
                ),
        ),
      );
      files.add(
        StagedRestoreFile(
          relativePath: 'profiles/$id.yaml',
          bytes: Uint8List.fromList(yaml),
        ),
      );
    }
    final currentUid = package.profilesYaml['current'];
    if (currentUid is! String || uidToId[currentUid] == null) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'profiles.yaml current profile is invalid',
      );
    }
    return RestoreBundle(
      sourceFormat: BackupSourceFormat.workerUnifiedV1,
      profiles: profiles,
      currentProfileId: uidToId[currentUid],
      files: files,
      providerCachePolicy: ProviderCachePolicy.invalidateRestoredProfiles,
      workerUnifiedArchive: Uint8List.fromList(archiveBytes),
      replaceWorkerUnifiedArchive: true,
    );
  }

  Future<RestoreBundle> _legacyBundle(LegacyParsedPackage package) async {
    if (package.format == BackupFormat.traditional) {
      return _traditionalBundle(package);
    }
    if (package.format == BackupFormat.profilesOnlyV3) {
      return _legacyBundleV3(package);
    }
    final isV2 = package.format == BackupFormat.profilesOnlyV2;
    final profiles = package.profiles
        .map((raw) {
          final map = _normalizeLegacyProfile(raw);
          if (!isV2) {
            map['scriptId'] = null;
            map['overwriteType'] = OverwriteType.standard.name;
          }
          return Profile.fromJson(map);
        })
        .toList(growable: false);
    final scripts = isV2
        ? _maps(package.metadata['scripts']).map(Script.fromJson).toList()
        : <Script>[];
    final rules = isV2
        ? _maps(package.metadata['rules']).map(Rule.fromJson).toList()
        : <Rule>[];
    final links = isV2
        ? _maps(package.metadata['links']).map(_linkFromJson).toList()
        : <ProfileRuleLink>[];
    final proxyGroups = isV2
        ? _maps(
            package.metadata['proxyGroups'],
          ).map(ProxyGroup.fromJson).toList()
        : <ProxyGroup>[];
    final config = _restoreConfig(
      isV2 && package.metadata['config'] is Map
          ? Map<String, dynamic>.from(package.metadata['config'] as Map)
          : package.config,
    );
    final workerUnifiedArchive = _validatedEmbeddedWorkerArchive(
      package,
      profiles,
    );
    return RestoreBundle(
      sourceFormat: isV2
          ? BackupSourceFormat.slclashProfilesV2
          : package.format == BackupFormat.profilesOnlyV1
          ? BackupSourceFormat.slclashProfilesV1
          : BackupSourceFormat.slclashLegacyV201,
      profiles: profiles,
      scripts: scripts,
      rules: rules,
      links: links,
      proxyGroups: proxyGroups,
      config: config,
      currentProfileId: package.currentProfileId,
      files: _currentFiles(package.files, profiles, scripts),
      // Provider caches are derived data. Invalidating them prevents restored
      // metadata and stale cache contents from disagreeing.
      providerCachePolicy: ProviderCachePolicy.invalidateRestoredProfiles,
      workerUnifiedArchive: workerUnifiedArchive,
      replaceWorkerUnifiedArchive: true,
    );
  }

  Future<RestoreBundle> _traditionalBundle(LegacyParsedPackage package) async {
    final temp = await Directory.systemTemp.createTemp('slclash-restore-');
    final oldDbFile = File(p.join(temp.path, 'database.sqlite'));
    await oldDbFile.writeAsBytes(
      package.files['database.sqlite']!,
      flush: true,
    );
    final old = Database(NativeDatabase(oldDbFile));
    try {
      final profiles = await old.profilesDao.query().get();
      final scripts = await old.scriptsDao.query().get();
      final rules = await old.rulesDao.queryAllRules();
      final links = await old.rulesDao.queryAllLinks();
      final proxyGroups = await old.proxyGroupsDao.queryAll().get();
      return RestoreBundle(
        sourceFormat: BackupSourceFormat.slclashDatabase,
        profiles: profiles,
        scripts: scripts,
        rules: rules,
        links: links,
        proxyGroups: proxyGroups,
        config: _restoreConfig(package.config),
        currentProfileId: package.currentProfileId,
        files: _currentFiles(package.files, profiles, scripts),
        providerCachePolicy: ProviderCachePolicy.invalidateRestoredProfiles,
        replaceWorkerUnifiedArchive: true,
      );
    } finally {
      await old.close();
      await temp.delete(recursive: true);
    }
  }
}

Uint8List? _validatedEmbeddedWorkerArchive(
  LegacyParsedPackage package,
  List<Profile> profiles,
) {
  final bytes = package.files['subscription-center/worker-v1.zip'];
  if (bytes == null) return null;
  final worker = const WorkerV1Parser().parse(bytes);
  final outerProfiles = {for (final profile in profiles) profile.id: profile};
  final items = worker.profilesYaml['items'];
  if (items is! List) {
    throw const BackupFormatException(
      BackupErrorCode.invalidProfiles,
      'Embedded subscription-center snapshot has invalid profiles',
    );
  }
  for (final value in items) {
    if (value is! Map || value['uid'] is! String || value['file'] is! String) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Embedded subscription-center snapshot has invalid profile identity',
      );
    }
    final uid = value['uid'] as String;
    final id = int.parse(uid.substring(1), radix: 16);
    final outer = outerProfiles[id];
    final innerYaml = worker.files['profiles/${value['file']}'];
    final outerYaml = package.files['profiles/$id.yaml'];
    if (outer == null ||
        outer.url != value['url'] ||
        innerYaml == null ||
        outerYaml == null ||
        !_sameBytes(innerYaml, outerYaml)) {
      throw const BackupFormatException(
        BackupErrorCode.hashMismatch,
        'Slclash backup and subscription-center snapshot disagree',
      );
    }
  }
  return Uint8List.fromList(bytes);
}

Uint8List? _validatedEmbeddedWorkerArchiveV3(
  LegacyParsedPackage package,
  List<Profile> profiles,
) {
  final bytes = package.files['subscription-center/worker-v1.zip'];
  if (bytes == null) return null;
  final worker = const WorkerV1Parser().parse(bytes);
  final outerProfiles = {for (final profile in profiles) profile.id: profile};
  final items = worker.profilesYaml['items'];
  if (items is! List) {
    throw const BackupFormatException(
      BackupErrorCode.invalidProfiles,
      'Embedded subscription-center snapshot has invalid profiles',
    );
  }

  // v3: Validate outer profiles.yaml matches embedded Worker capsule
  final outerProfilesYaml = package.files['profiles.yaml'];
  final innerProfilesYaml = worker.files['profiles.yaml'];
  if (outerProfilesYaml == null ||
      innerProfilesYaml == null ||
      !_sameBytes(outerProfilesYaml, innerProfilesYaml)) {
    throw const BackupFormatException(
      BackupErrorCode.hashMismatch,
      'Outer profiles.yaml does not match embedded Worker capsule',
    );
  }

  for (final value in items) {
    if (value is! Map || value['uid'] is! String || value['file'] is! String) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Embedded subscription-center snapshot has invalid profile identity',
      );
    }
    final uid = value['uid'] as String;
    final id = int.parse(uid.substring(1), radix: 16);
    final outer = outerProfiles[id];
    final innerYaml = worker.files['profiles/${value['file']}'];
    final outerYaml = package.files['profiles/$id.yaml'];
    if (outer == null ||
        outer.url != value['url'] ||
        innerYaml == null ||
        outerYaml == null ||
        !_sameBytes(innerYaml, outerYaml)) {
      throw const BackupFormatException(
        BackupErrorCode.hashMismatch,
        'Slclash backup and subscription-center snapshot disagree',
      );
    }

    // v3: Validate outer profiles/R*.yaml matches embedded Worker capsule
    final outerRYaml = package.files['profiles/$uid.yaml'];
    final innerRYaml = worker.files['profiles/$uid.yaml'];
    if (outerRYaml == null ||
        innerRYaml == null ||
        !_sameBytes(outerRYaml, innerRYaml)) {
      throw BackupFormatException(
        BackupErrorCode.hashMismatch,
        'Outer profiles/$uid.yaml does not match embedded Worker capsule',
      );
    }
  }
  return Uint8List.fromList(bytes);
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<StagedRestoreFile> _currentFiles(
  Map<String, Uint8List> archive,
  List<Profile> profiles,
  List<Script> scripts,
) {
  final result = <StagedRestoreFile>[];
  for (final profile in profiles) {
    final bytes = archive['profiles/${profile.id}.yaml'];
    if (bytes != null) {
      result.add(
        StagedRestoreFile(
          relativePath: 'profiles/${profile.id}.yaml',
          bytes: bytes,
        ),
      );
    }
  }
  for (final script in scripts) {
    final bytes = archive['scripts/${script.id}.js'];
    if (bytes != null) {
      result.add(
        StagedRestoreFile(
          relativePath: 'scripts/${script.id}.js',
          bytes: bytes,
        ),
      );
    }
  }
  return result;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Expected a list');
  return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

ProfileRuleLink _linkFromJson(Map<String, dynamic> map) => ProfileRuleLink(
  profileId: map['profileId'] as int?,
  ruleId: map['ruleId'] as int,
  scene: map['scene'] == null
      ? null
      : RuleScene.values.byName(map['scene'] as String),
  order: map['order'] as String?,
);

int _integer(Object? value) => value is int ? value : 0;

Map<String, dynamic> _normalizeLegacyProfile(Map<String, dynamic> raw) {
  final map = Map<String, dynamic>.from(raw);
  map.putIfAbsent(
    'autoUpdateDuration',
    () => const Duration(days: 1).inMicroseconds,
  );
  map.putIfAbsent('label', () => '');
  map.putIfAbsent('url', () => '');
  map.putIfAbsent('autoUpdate', () => true);
  map.putIfAbsent('selectedMap', () => <String, String>{});
  map.putIfAbsent('computedSelectedMap', () => <String, String>{});
  map.putIfAbsent('unfoldSet', () => <String>[]);
  map.putIfAbsent('overwriteType', () => OverwriteType.standard.name);
  return map;
}

Config? _restoreConfig(Map<String, dynamic>? source) {
  if (source == null) return null;
  final map = Map<String, Object?>.from(source);
  map['appSettingProps'] ??= map['appSetting'];
  map['davProps'] ??= map['dav'];
  map['proxiesStyleProps'] ??= map['proxiesStyle'];
  map['themeProps'] ??= defaultThemeProps.toJson();
  try {
    return Config.realFromJson(map);
  } catch (error) {
    throw BackupFormatException(
      BackupErrorCode.unsupportedFormat,
      'Backup settings are invalid: $error',
    );
  }
}
