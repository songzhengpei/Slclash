import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/common/preferences.dart';
import 'package:fl_clash/common/restore_bridge.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/backup_restore/backup_restore.dart';
import 'package:path/path.dart' as p;

class ProfilesRestoreData {
  const ProfilesRestoreData({
    required this.currentProfileId,
    required this.profiles,
    required this.backupType,
    this.scripts,
    this.rules,
    this.links,
  });

  final int? currentProfileId;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>>? scripts;
  final List<Map<String, dynamic>>? rules;
  final List<Map<String, dynamic>>? links;
  final String backupType;

  bool get isV2 => backupType == profilesBackupTypeV2;
}

Future<ProfilesRestoreData> restoreProfilesOnlyTask() async {
  await clearPendingBackupRestoreCommit();

  final backupFile = File(await appPath.backupFilePath);
  final stagingDirectory = Directory(await appPath.restoreDirPath);
  final model = await const BackupArchiveParser().parse(
    backupFile,
    stagingDirectory: stagingDirectory,
  );

  try {
    for (final item in model.profileFiles) {
      final message = await coreController.validateConfig(item.source.path);
      if (message.isNotEmpty) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidProfile,
          'Profile 配置无法被内核加载',
        );
      }
    }

    final pending = _PendingBackupRestoreCommit(model);
    setPendingBackupRestoreCommit(pending);

    return ProfilesRestoreData(
      currentProfileId: model.currentProfileId,
      profiles: model.profiles.map((item) => item.toJson()).toList(),
      backupType: model.format == BackupArchiveFormat.profilesV1
          ? profilesBackupType
          : profilesBackupTypeV2,
      scripts: model.scripts.map((item) => item.toJson()).toList(),
      rules: model.rules.map((item) => item.toJson()).toList(),
      links: model.links
          .map(
            (item) => <String, dynamic>{
              'profileId': item.profileId,
              'ruleId': item.ruleId,
              'scene': item.scene?.name,
              'order': item.order,
            },
          )
          .toList(),
    );
  } catch (_) {
    await model.dispose();
    rethrow;
  }
}

class _PendingBackupRestoreCommit implements PendingBackupRestoreCommit {
  _PendingBackupRestoreCommit(this.model);

  final UnifiedRestoreModel model;
  RestoreFileCommitter? _committer;
  Map<String, Object?>? _previousConfigMap;
  bool _configChanged = false;

  @override
  List<ProxyGroup> get proxyGroups => model.proxyGroups;

  @override
  Set<int> get restoredProfileIds =>
      model.profiles.map((profile) => profile.id).toSet();

  @override
  bool get invalidateProviderCaches => model.invalidateProviderCaches;

  @override
  Future<void> commitFiles({required bool isOverride}) async {
    final profilesDirectory = Directory(await appPath.profilesPath);
    final scriptsDirectory = Directory(await appPath.scriptsDirPath);
    final providersDirectory = Directory(await appPath.getProvidersRootPath());
    final homeDirectory = await appPath.homeDirPath;
    final rollbackDirectory = Directory(
      p.join(homeDirectory, '.backup-restore-rollback'),
    );
    _committer = RestoreFileCommitter(
      profilesDirectory: profilesDirectory,
      scriptsDirectory: scriptsDirectory,
      providersDirectory: providersDirectory,
      rollbackDirectory: rollbackDirectory,
    );

    await _committer!.apply(
      model,
      replaceExisting: isOverride,
    );

    final configMap = model.legacyConfigMap;
    if (configMap != null) {
      _previousConfigMap = await preferences.getConfigMap();
      final restoredConfig = Config.realFromJson(configMap).copyWith(
        currentProfileId: model.currentProfileId,
      );
      final saved = await preferences.saveConfig(restoredConfig);
      if (!saved) {
        throw const BackupRestoreException(
          BackupRestoreErrorCode.fileCommitFailure,
          '旧备份用户设置写入失败',
        );
      }
      _configChanged = true;
    }
  }

  @override
  Future<void> rollbackFiles() async {
    await _committer?.rollback();
    if (_configChanged) {
      final previous = _previousConfigMap;
      if (previous == null) {
        final sharedPreferences =
            await preferences.sharedPreferencesCompleter.future;
        await sharedPreferences?.remove(configKey);
      } else {
        await preferences.saveConfig(Config.realFromJson(previous));
      }
      _configChanged = false;
    }
  }

  @override
  Future<void> complete() async {
    await _committer?.complete();
    await model.dispose();
  }
}
