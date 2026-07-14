import 'dart:typed_data';

import 'package:fl_clash/models/models.dart';

enum BackupSourceFormat {
  workerUnifiedV1,
  slclashProfilesV2,
  slclashProfilesV1,
  slclashDatabase,
  slclashLegacyV201,
}

enum ProviderCachePolicy { preserve, invalidateRestoredProfiles }

class StagedRestoreFile {
  final String relativePath;
  final Uint8List bytes;

  StagedRestoreFile({required this.relativePath, required this.bytes});
}

/// Format-neutral, fully parsed input to the restore commit pipeline.
///
/// Parsers own format conversion. This model intentionally contains current
/// application models only, so no archive/version branching reaches the
/// database or filesystem commit code.
class RestoreBundle {
  final BackupSourceFormat sourceFormat;
  final List<Profile> profiles;
  final List<Script> scripts;
  final List<Rule> rules;
  final List<ProfileRuleLink> links;
  final List<ProxyGroup> proxyGroups;
  final Config? config;
  final int? currentProfileId;
  final List<StagedRestoreFile> files;
  final ProviderCachePolicy providerCachePolicy;

  const RestoreBundle({
    required this.sourceFormat,
    required this.profiles,
    this.scripts = const [],
    this.rules = const [],
    this.links = const [],
    this.proxyGroups = const [],
    this.config,
    this.currentProfileId,
    this.files = const [],
    this.providerCachePolicy = ProviderCachePolicy.preserve,
  });
}

class RestoreValidationException implements Exception {
  final String message;

  const RestoreValidationException(this.message);

  @override
  String toString() => 'RestoreValidationException: $message';
}

class RestoreCommitResult {
  final int? currentProfileId;
  final Set<int> restoredProfileIds;
  final Config? config;

  const RestoreCommitResult({
    required this.currentProfileId,
    required this.restoredProfileIds,
    this.config,
  });
}
