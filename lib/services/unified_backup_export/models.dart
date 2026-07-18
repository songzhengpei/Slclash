import 'dart:typed_data';

class UnifiedExportProfile {
  const UnifiedExportProfile({
    required this.androidId,
    required this.name,
    required this.yaml,
    required this.updated,
    required this.autoUpdate,
    required this.updateIntervalMinutes,
    this.subscriptionInfo,
    this.sourceUrl,
  });

  final int androidId;
  final String name;
  final Uint8List yaml;
  final int updated;
  final bool autoUpdate;
  final int updateIntervalMinutes;
  final Map<String, int>? subscriptionInfo;

  /// Local-only identity hint. It is never serialized into the archive.
  final String? sourceUrl;
}

const maxClientUpdateIntervalMinutes = 153722867280;

class UnifiedExportInput {
  const UnifiedExportInput({
    required this.profiles,
    required this.currentAndroidId,
    required this.trustedArchive,
    required this.generatorVersion,
    this.createdAt,
  });

  final List<UnifiedExportProfile> profiles;
  final int? currentAndroidId;
  final Uint8List trustedArchive;
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
