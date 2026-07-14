import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

import 'models.dart';
import 'parse_utils.dart';

class LegacyBackupParser {
  const LegacyBackupParser({required this.limits});

  final BackupArchiveLimits limits;
  static const _utils = BackupParseUtils();

  Future<UnifiedRestoreModel> parseProfilesBackup(
    StagedBackupArchive staged,
  ) async {
    final metadata = await _utils.readJsonObject(
      staged.requireFile(
        profilesBackupMetadataName,
        maxBytes: limits.maxMetadataBytes,
      ),
      profilesBackupMetadataName,
    );
    final format = switch (metadata['backupType']) {
      profilesBackupTypeV2 => BackupArchiveFormat.profilesV2,
      profilesBackupType => BackupArchiveFormat.profilesV1,
      final value => throw BackupRestoreException(
          BackupRestoreErrorCode.unsupportedVersion,
          '不支持的传统备份版本：$value',
        ),
    };
    final isV2 = format == BackupArchiveFormat.profilesV2;
    final rawProfiles = metadata['profiles'];
    if (rawProfiles is! List || rawProfiles.isEmpty) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        '传统备份不包含 Profile',
      );
    }

    final profiles = <Profile>[];
    final profileIds = <int>{};
    final profileFiles = <RestoreSourceFile>[];
    for (var index = 0; index < rawProfiles.length; index++) {
      final profile = _adaptProfile(
        _utils.objectMap(
          rawProfiles[index],
          field: 'metadata.profiles[$index]',
        ),
        legacyV1: !isV2,
      );
      if (!profileIds.add(profile.id)) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidProfile,
          '传统备份含有重复 Profile ID：${profile.id}',
        );
      }
      profiles.add(profile);
      final source = _findProfileFile(staged, profile.id);
      await _utils.readYamlObject(source, '${profile.id}.yaml');
      profileFiles.add(
        RestoreSourceFile(
          source: source,
          relativeTarget: '${profile.id}.yaml',
        ),
      );
    }

    final scripts = isV2
        ? _parseScripts(metadata['scripts'])
        : const <Script>[];
    final scriptIds = scripts.map((script) => script.id).toSet();
    final scriptFiles = <RestoreSourceFile>[];
    for (final script in scripts) {
      final source = staged.files['scripts/${script.id}.js'];
      if (source == null) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.missingRequiredFile,
          '缺少脚本文件：${script.id}.js',
        );
      }
      scriptFiles.add(
        RestoreSourceFile(
          source: source,
          relativeTarget: '${script.id}.js',
        ),
      );
    }

    for (final profile in profiles) {
      if (profile.overwriteType == OverwriteType.script &&
          (profile.scriptId == null || !scriptIds.contains(profile.scriptId))) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidRelationship,
          'Profile ${profile.id} 引用了不存在的脚本',
        );
      }
    }

    final rules = isV2 ? _parseRules(metadata['rules']) : const <Rule>[];
    final links = isV2
        ? _parseLinks(metadata['links'])
        : const <ProfileRuleLink>[];
    _utils.validateRelationships(
      profiles: profiles,
      rules: rules,
      links: links,
    );

    final requested = _utils.intValue(metadata['currentProfileId']);
    return UnifiedRestoreModel(
      format: format,
      profiles: profiles,
      scripts: scripts,
      rules: rules,
      links: links,
      currentProfileId:
          requested != null && profileIds.contains(requested)
              ? requested
              : profiles.first.id,
      profileFiles: profileFiles,
      scriptFiles: scriptFiles,
      providerFiles: _collectProviderFiles(staged),
      stagingDirectory: staged.directory,
    );
  }

  Future<UnifiedRestoreModel> parseDatabaseBackup(
    StagedBackupArchive staged,
  ) async {
    final legacyDatabase = Database(
      NativeDatabase(staged.requireFile(backupDatabaseName)),
    );
    try {
      final profiles = await legacyDatabase.profilesDao.query().get();
      final scripts = await legacyDatabase.scriptsDao.query().get();
      final rules = await legacyDatabase.rules.all()
          .map((item) => item.toRule())
          .get();
      final links = await legacyDatabase.profileRuleLinks.all()
          .map((item) => item.toLink())
          .get();
      final proxyGroups = await legacyDatabase.proxyGroups.all()
          .map((item) => item.toProxyGroup())
          .get();

      if (profiles.isEmpty) {
        throw const BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          '旧备份数据库不包含 Profile',
        );
      }
      _utils.validateRelationships(
        profiles: profiles,
        rules: rules,
        links: links,
      );

      final profileFiles = <RestoreSourceFile>[];
      for (final profile in profiles) {
        final source = _findProfileFile(staged, profile.id);
        await _utils.readYamlObject(source, '${profile.id}.yaml');
        profileFiles.add(
          RestoreSourceFile(
            source: source,
            relativeTarget: '${profile.id}.yaml',
          ),
        );
      }

      final scriptFiles = <RestoreSourceFile>[];
      for (final script in scripts) {
        final source = staged.files['scripts/${script.id}.js'];
        if (source != null) {
          scriptFiles.add(
            RestoreSourceFile(
              source: source,
              relativeTarget: '${script.id}.js',
            ),
          );
        } else if (profiles.any(
          (profile) =>
              profile.overwriteType == OverwriteType.script &&
              profile.scriptId == script.id,
        )) {
          throw BackupRestoreException(
            BackupRestoreErrorCode.missingRequiredFile,
            '旧备份缺少脚本文件：${script.id}.js',
          );
        }
      }

      final config = await _readOptionalConfig(staged);
      final requested = _utils.intValue(config?['currentProfileId']);
      final ids = profiles.map((profile) => profile.id).toSet();
      return UnifiedRestoreModel(
        format: BackupArchiveFormat.legacyDatabase,
        profiles: profiles,
        scripts: scripts,
        rules: rules,
        links: links,
        proxyGroups: proxyGroups,
        currentProfileId:
            requested != null && ids.contains(requested)
                ? requested
                : profiles.first.id,
        profileFiles: profileFiles,
        scriptFiles: scriptFiles,
        providerFiles: _collectProviderFiles(staged),
        legacyConfigMap: config,
        stagingDirectory: staged.directory,
      );
    } finally {
      await legacyDatabase.close();
    }
  }

  Future<UnifiedRestoreModel> parseConfigBackup(
    StagedBackupArchive staged,
  ) async {
    final config = await _utils.readJsonObject(
      staged.requireFile(
        configJsonName,
        maxBytes: limits.maxMetadataBytes,
      ),
      configJsonName,
    );
    final version = _utils.intValue(config['version']) ?? 0;
    if (version != 0 && version != 1) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.unsupportedVersion,
        '不支持的旧备份配置版本：$version',
      );
    }
    final rawProfiles = config['profiles'];
    if (rawProfiles is! List || rawProfiles.isEmpty) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        '旧备份配置不包含 Profile',
      );
    }

    final profiles = <Profile>[];
    final ids = <int>{};
    final profileFiles = <RestoreSourceFile>[];
    for (var index = 0; index < rawProfiles.length; index++) {
      final profile = _adaptProfile(
        _utils.objectMap(
          rawProfiles[index],
          field: 'config.profiles[$index]',
        ),
        legacyV1: true,
      );
      if (!ids.add(profile.id)) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidProfile,
          '旧备份含有重复 Profile ID：${profile.id}',
        );
      }
      profiles.add(profile);
      final source = _findProfileFile(staged, profile.id);
      await _utils.readYamlObject(source, '${profile.id}.yaml');
      profileFiles.add(
        RestoreSourceFile(
          source: source,
          relativeTarget: '${profile.id}.yaml',
        ),
      );
    }

    final requested = _utils.intValue(config['currentProfileId']);
    return UnifiedRestoreModel(
      format: BackupArchiveFormat.legacyConfig,
      profiles: profiles,
      currentProfileId:
          requested != null && ids.contains(requested)
              ? requested
              : profiles.first.id,
      profileFiles: profileFiles,
      providerFiles: _collectProviderFiles(staged),
      legacyConfigMap: config,
      stagingDirectory: staged.directory,
    );
  }

  Profile _adaptProfile(
    Map<String, Object?> map, {
    required bool legacyV1,
  }) {
    final id = _utils.intValue(map['id']);
    if (id == null || id <= 0) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidProfile,
        'Profile ID 无效',
      );
    }
    var overwriteType = _utils.enumByName(
          OverwriteType.values,
          map['overwriteType']?.toString(),
        ) ??
        OverwriteType.standard;
    var scriptId = _utils.intValue(map['scriptId']);
    if (legacyV1 || overwriteType == OverwriteType.custom) {
      overwriteType = OverwriteType.standard;
      scriptId = null;
    }

    final durationMicros = _utils.intValue(map['autoUpdateDuration']);
    final durationMillis = _utils.intValue(map['autoUpdateDurationMillis']);
    final duration = durationMicros != null && durationMicros > 0
        ? Duration(microseconds: durationMicros)
        : durationMillis != null && durationMillis > 0
            ? Duration(milliseconds: durationMillis)
            : defaultUpdateDuration;

    final rawSubscription = map['subscriptionInfo'];
    final subscription = rawSubscription is Map
        ? SubscriptionInfo(
            upload: _utils.intValue(rawSubscription['upload']) ?? 0,
            download: _utils.intValue(rawSubscription['download']) ?? 0,
            total: _utils.intValue(rawSubscription['total']) ?? 0,
            expire: _utils.intValue(rawSubscription['expire']) ?? 0,
          )
        : null;

    return Profile(
      id: id,
      label: map['label']?.toString() ?? '',
      currentGroupName: map['currentGroupName']?.toString(),
      url: map['url']?.toString() ?? '',
      lastUpdateDate: _utils.dateTime(map['lastUpdateDate']),
      autoUpdateDuration: duration,
      subscriptionInfo: subscription,
      autoUpdate:
          map['autoUpdate'] is bool ? map['autoUpdate']! as bool : true,
      selectedMap: _utils.stringMap(map['selectedMap']),
      computedSelectedMap: _utils.stringMap(map['computedSelectedMap']),
      unfoldSet: _utils.stringSet(map['unfoldSet']),
      overwriteType: overwriteType,
      scriptId: scriptId,
      order: _utils.intValue(map['order']),
    );
  }

  List<Script> _parseScripts(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        'scripts 元数据不是数组',
      );
    }
    final result = <Script>[];
    final ids = <int>{};
    for (var index = 0; index < raw.length; index++) {
      try {
        final script = Script.fromJson(
          _utils.objectMap(raw[index], field: 'scripts[$index]'),
        );
        if (!ids.add(script.id)) {
          throw BackupRestoreException(
            BackupRestoreErrorCode.invalidMetadata,
            'scripts 含有重复 ID：${script.id}',
          );
        }
        result.add(script);
      } on BackupRestoreException {
        rethrow;
      } catch (error) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          '脚本元数据无效：$index',
          error,
        );
      }
    }
    return result;
  }

  List<Rule> _parseRules(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        'rules 元数据不是数组',
      );
    }
    final result = <Rule>[];
    final ids = <int>{};
    for (var index = 0; index < raw.length; index++) {
      try {
        final rule = Rule.fromJson(
          _utils.objectMap(raw[index], field: 'rules[$index]'),
        );
        if (!ids.add(rule.id)) {
          throw BackupRestoreException(
            BackupRestoreErrorCode.invalidMetadata,
            'rules 含有重复 ID：${rule.id}',
          );
        }
        result.add(rule);
      } on BackupRestoreException {
        rethrow;
      } catch (error) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          '规则元数据无效：$index',
          error,
        );
      }
    }
    return result;
  }

  List<ProfileRuleLink> _parseLinks(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        'links 元数据不是数组',
      );
    }
    final result = <ProfileRuleLink>[];
    for (var index = 0; index < raw.length; index++) {
      final map = _utils.objectMap(raw[index], field: 'links[$index]');
      final ruleId = _utils.intValue(map['ruleId']);
      if (ruleId == null) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          '关联元数据缺少 ruleId：$index',
        );
      }
      final sceneName = map['scene']?.toString();
      final scene = _utils.enumByName(RuleScene.values, sceneName);
      if (sceneName != null && scene == null) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidMetadata,
          '关联元数据 scene 无效：$sceneName',
        );
      }
      result.add(
        ProfileRuleLink(
          profileId: _utils.intValue(map['profileId']),
          ruleId: ruleId,
          scene: scene,
          order: map['order']?.toString(),
        ),
      );
    }
    return result;
  }

  File _findProfileFile(StagedBackupArchive staged, int id) {
    final source = staged.files['profiles/$id.yaml'] ??
        staged.files['$id.yaml'];
    if (source == null) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.missingRequiredFile,
        '缺少 Profile 配置文件：$id.yaml',
      );
    }
    return source;
  }

  List<RestoreSourceFile> _collectProviderFiles(
    StagedBackupArchive staged,
  ) {
    const prefix = 'profiles/providers/';
    return [
      for (final entry in staged.files.entries)
        if (entry.key.startsWith(prefix) &&
            entry.key.length > prefix.length)
          RestoreSourceFile(
            source: entry.value,
            relativeTarget: entry.key.substring(prefix.length),
          ),
    ];
  }

  Future<Map<String, Object?>?> _readOptionalConfig(
    StagedBackupArchive staged,
  ) {
    final file = staged.files[configJsonName];
    return file == null
        ? Future<Map<String, Object?>?>.value(null)
        : _utils.readJsonObject(file, configJsonName);
  }
}
