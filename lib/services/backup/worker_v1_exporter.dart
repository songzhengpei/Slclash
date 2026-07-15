import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'backup_error.dart';
import 'worker_v1_models.dart';

const workerV1CapsuleMediaType =
    'application/vnd.mihomo-unified-backup+zip; version=1';

const workerV1CompatibilityConfig =
    'mixed-port: 7890\n'
    'allow-lan: false\n'
    'mode: rule\n'
    'log-level: info\n';

const workerV1CompatibilityConfigSha256 =
    '451444cc8d6401ec9a7b57ed977053039e00a8b451827ec37b0e15ca8f808ec9';

class WorkerV1ExportProfile {
  const WorkerV1ExportProfile({required this.name, required this.url});

  final String name;
  final String url;
}

/// Rebuilds the Worker v1 compatibility view exclusively from Worker-issued
/// packages. Identity, metadata, and raw artifacts are never synthesized.
class WorkerV1Exporter {
  const WorkerV1Exporter();

  Uint8List export({
    required List<WorkerV1ExportProfile> profiles,
    required String? currentProfileUrl,
    required List<WorkerV1Package> trustedPackages,
    DateTime? createdAt,
  }) {
    if (profiles.isEmpty) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Cannot export a Worker archive without profiles',
      );
    }
    final sources = _indexSources(trustedPackages);
    final selected = profiles
        .map((profile) {
          final source = sources[profile.url];
          if (source == null) {
            throw const BackupFormatException(
              BackupErrorCode.missingTrustedMetadata,
              'A profile has no Worker-issued export capsule',
            );
          }
          return (profile: profile, source: source);
        })
        .toList(growable: false);
    final origins = selected.map((item) => item.source.publicBaseUrl).toSet();
    final uids = selected.map((item) => item.source.uid).toSet();
    final slugs = selected.map((item) => item.source.slug).toSet();
    if (origins.length != 1 ||
        uids.length != selected.length ||
        slugs.length != selected.length) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Trusted Worker identities conflict',
      );
    }
    final current = selected.where(
      (item) => item.profile.url == currentProfileUrl,
    );
    final currentUid = current.isEmpty
        ? selected.first.source.uid
        : current.single.source.uid;
    final files = <String, List<int>>{
      'config.yaml': utf8.encode(workerV1CompatibilityConfig),
      'verge.yaml': utf8.encode('{}\n'),
      'profiles.yaml': utf8.encode(_profilesYaml(selected, currentUid)),
    };
    final airports = <Map<String, Object?>>[];
    for (final item in selected) {
      final source = item.source;
      for (final path in source.artifactPaths) {
        files[path] = source.package.files[path]!;
      }
      airports.add({...source.airport, 'name': item.profile.name});
    }
    final manifestFiles = <String, Object?>{
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
    };
    final manifest = <String, Object?>{
      'format': 'mihomo-unified-backup',
      'formatVersion': 1,
      'archiveType': 'unified-subscription-archive',
      'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'generator': 'worker',
      'generatorVersion': '1.0.0',
      'publicBaseUrl': origins.single,
      'mainConfig': const {
        'configId': 'system-minimal-compat',
        'versionId': 'sha256-451444cc8d6401ec',
        'name': 'Clash Verge compatibility config',
        'sourceSha256': workerV1CompatibilityConfigSha256,
      },
      'airports': airports,
      'files': manifestFiles,
    };
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }
    archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Map<String, _TrustedSource> _indexSources(List<WorkerV1Package> packages) {
    final result = <String, _TrustedSource>{};
    for (final package in packages) {
      final items = package.profilesYaml['items'] as List;
      final airports = {
        for (final airport in package.manifest.airports)
          airport['profileUid'] as String: airport,
      };
      for (final raw in items) {
        final item = Map<String, Object?>.from(raw as Map);
        final uid = item['uid'] as String;
        final url = item['url'] as String;
        final airport = airports[uid]!;
        final slug = airport['slug'] as String;
        final paths = [
          'profiles/$uid.yaml',
          'providers/$slug/provider.yaml',
          'providers/$slug/profile.yaml',
          'providers/$slug/meta.json',
        ];
        final meta = package.files[paths.last]!;
        if (!_isNonEmptyJsonObject(meta)) {
          throw const BackupFormatException(
            BackupErrorCode.missingTrustedMetadata,
            'Worker ProviderVersionMeta is empty or invalid',
          );
        }
        final source = _TrustedSource(
          package: package,
          airport: airport,
          uid: uid,
          slug: slug,
          publicBaseUrl: package.manifest.raw['publicBaseUrl'] as String,
          artifactPaths: paths,
        );
        final previous = result[url];
        if (previous != null &&
            previous.airport['versionId'] != airport['versionId']) {
          throw const BackupFormatException(
            BackupErrorCode.invalidProfiles,
            'Worker capsules disagree about a subscription version',
          );
        }
        result[url] = source;
      }
    }
    return result;
  }

  bool _isNonEmptyJsonObject(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      return value is Map && value.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _profilesYaml(
    List<({WorkerV1ExportProfile profile, _TrustedSource source})> profiles,
    String current,
  ) {
    final buffer = StringBuffer('current: $current\nitems:\n');
    for (final item in profiles) {
      buffer
        ..writeln('  - uid: ${item.source.uid}')
        ..writeln('    type: remote')
        ..writeln('    name: ${jsonEncode(item.profile.name)}')
        ..writeln('    file: ${item.source.uid}.yaml')
        ..writeln('    url: ${jsonEncode(item.profile.url)}');
    }
    return buffer.toString();
  }
}

class _TrustedSource {
  const _TrustedSource({
    required this.package,
    required this.airport,
    required this.uid,
    required this.slug,
    required this.publicBaseUrl,
    required this.artifactPaths,
  });

  final WorkerV1Package package;
  final Map<String, Object?> airport;
  final String uid;
  final String slug;
  final String publicBaseUrl;
  final List<String> artifactPaths;
}
