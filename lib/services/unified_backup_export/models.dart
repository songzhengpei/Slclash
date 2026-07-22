import 'dart:typed_data';

class UnifiedExportProfile {
  const UnifiedExportProfile({
    required this.androidId,
    required this.name,
    required this.sourceUrl,
    required this.yaml,
    this.providerSourceYaml,
    required this.updated,
    required this.autoUpdate,
    required this.updateIntervalMinutes,
    this.subscriptionInfo,
    this.externalProvidersFlattened = false,
    this.localFile = false,
  });

  final int androidId;
  final String name;
  final String sourceUrl;
  final Uint8List yaml;
  final Uint8List? providerSourceYaml;
  final int updated;
  final bool autoUpdate;
  final int updateIntervalMinutes;
  final Map<String, int>? subscriptionInfo;
  final bool externalProvidersFlattened;
  final bool localFile;
}

const maxClientUpdateIntervalMinutes = 153722867280;

class UnifiedExportInput {
  const UnifiedExportInput({
    required this.profiles,
    required this.currentAndroidId,
    required this.generatorVersion,
    this.trustedArchive,
    this.createdAt,
  });

  final List<UnifiedExportProfile> profiles;
  final int? currentAndroidId;
  final Uint8List? trustedArchive;
  final String generatorVersion;
  final DateTime? createdAt;
}

class UnifiedIdentity {
  const UnifiedIdentity({
    required this.slug,
    required this.subscriptionId,
    required this.profileUid,
  });

  final String slug;
  final String subscriptionId;
  final String profileUid;
}
