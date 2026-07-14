import 'dart:io';

import 'package:fl_clash/models/models.dart';

enum BackupArchiveFormat {
  workerUnifiedV1,
  profilesV2,
  profilesV1,
  legacyDatabase,
  legacyConfig,
}

enum BackupRestoreErrorCode {
  invalidArchive,
  unsafePath,
  duplicatePath,
  archiveLimitExceeded,
  unsupportedFormat,
  unsupportedVersion,
  missingRequiredFile,
  invalidManifest,
  hashMismatch,
  invalidMetadata,
  invalidProfile,
  invalidRelationship,
  invalidWorkerUrl,
  databaseFailure,
  fileCommitFailure,
  postRestoreValidationFailure,
}

class BackupRestoreException implements Exception {
  const BackupRestoreException(this.code, this.message, [this.cause]);

  final BackupRestoreErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class BackupArchiveLimits {
  const BackupArchiveLimits({
    this.maxArchiveBytes = 64 * 1024 * 1024,
    this.maxEntryCount = 4096,
    this.maxEntryBytes = 32 * 1024 * 1024,
    this.maxExpandedBytes = 128 * 1024 * 1024,
    this.maxManifestBytes = 1024 * 1024,
    this.maxMetadataBytes = 4 * 1024 * 1024,
  });

  final int maxArchiveBytes;
  final int maxEntryCount;
  final int maxEntryBytes;
  final int maxExpandedBytes;
  final int maxManifestBytes;
  final int maxMetadataBytes;
}

class RestoreSourceFile {
  const RestoreSourceFile({
    required this.source,
    required this.relativeTarget,
  });

  final File source;
  final String relativeTarget;
}

class UnifiedRestoreModel {
  const UnifiedRestoreModel({
    required this.format,
    required this.profiles,
    required this.profileFiles,
    required this.stagingDirectory,
    this.scripts = const [],
    this.rules = const [],
    this.links = const [],
    this.proxyGroups = const [],
    this.scriptFiles = const [],
    this.providerFiles = const [],
    this.currentProfileId,
    this.invalidateProviderCaches = false,
    this.legacyConfigMap,
  });

  final BackupArchiveFormat format;
  final List<Profile> profiles;
  final List<Script> scripts;
  final List<Rule> rules;
  final List<ProfileRuleLink> links;
  final List<ProxyGroup> proxyGroups;
  final int? currentProfileId;
  final List<RestoreSourceFile> profileFiles;
  final List<RestoreSourceFile> scriptFiles;
  final List<RestoreSourceFile> providerFiles;
  final bool invalidateProviderCaches;
  final Map<String, Object?>? legacyConfigMap;
  final Directory stagingDirectory;

  bool get isWorkerUnified =>
      format == BackupArchiveFormat.workerUnifiedV1;

  Future<void> dispose() async {
    if (await stagingDirectory.exists()) {
      await stagingDirectory.delete(recursive: true);
    }
  }
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.format,
    required this.profileCount,
    required this.currentProfileId,
  });

  final BackupArchiveFormat format;
  final int profileCount;
  final int? currentProfileId;
}
