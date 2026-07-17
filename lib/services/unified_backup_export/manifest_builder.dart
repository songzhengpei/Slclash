import 'package:crypto/crypto.dart';

Map<String, Object?> buildUnifiedManifest({
  required DateTime createdAt,
  required String generatorVersion,
  required Map<String, List<int>> files,
  required List<Map<String, Object?>> airports,
  required Map<String, Object?> mainConfig,
  required String publicBaseUrl,
}) => {
  'format': 'mihomo-unified-backup',
  'formatVersion': 1,
  'archiveType': 'unified-subscription-archive',
  'createdAt': createdAt.toUtc().toIso8601String(),
  'generator': 'slclash',
  'generatorVersion': generatorVersion,
  'publicBaseUrl': publicBaseUrl,
  'mainConfig': mainConfig,
  'airports': airports,
  'files': {
    for (final entry in files.entries)
      entry.key: {
        'sha256': sha256.convert(entry.value).toString(),
        'contentLength': entry.value.length,
        'required':
            entry.key == 'config.yaml' ||
            entry.key == 'verge.yaml' ||
            entry.key == 'profiles.yaml' ||
            entry.key.startsWith('profiles/'),
      },
  },
};
