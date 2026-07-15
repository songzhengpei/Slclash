import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'backup_error.dart';

const workerV1CompatibilityConfig =
    'mixed-port: 7890\n'
    'allow-lan: false\n'
    'mode: rule\n'
    'log-level: info\n';

const workerV1CompatibilityConfigSha256 =
    '451444cc8d6401ec9a7b57ed977053039e00a8b451827ec37b0e15ca8f808ec9';

class WorkerV1ExportProfile {
  const WorkerV1ExportProfile({
    required this.id,
    required this.name,
    required this.url,
    required this.yaml,
    this.updated,
    this.updateIntervalMinutes = 60,
    this.allowAutoUpdate = true,
  });

  final int id;
  final String name;
  final String url;
  final Uint8List yaml;
  final DateTime? updated;
  final int updateIntervalMinutes;
  final bool allowAutoUpdate;
}

/// Builds the Worker v1 compatibility view from Slclash's current profiles.
/// config.yaml is deliberately static and is never an authoritative source.
class WorkerV1Exporter {
  const WorkerV1Exporter();

  Uint8List export({
    required List<WorkerV1ExportProfile> profiles,
    required int? currentProfileId,
    DateTime? createdAt,
  }) {
    if (profiles.isEmpty) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Cannot export a Worker archive without profiles',
      );
    }
    final parsed = profiles.map(_parseProfile).toList(growable: false);
    final origins = parsed.map((item) => item.origin).toSet();
    final slugs = parsed.map((item) => item.slug).toSet();
    if (origins.length != 1 || slugs.length != parsed.length) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Worker subscription URLs need one public base URL and unique slugs',
      );
    }
    final current = parsed.where((item) => item.profile.id == currentProfileId);
    final currentItem = current.isEmpty ? parsed.first : current.single;
    final files = <String, List<int>>{
      'config.yaml': utf8.encode(workerV1CompatibilityConfig),
      'verge.yaml': utf8.encode('{}\n'),
      'profiles.yaml': utf8.encode(_profilesYaml(parsed, currentItem.uid)),
    };
    final airports = <Map<String, Object?>>[];
    for (final item in parsed) {
      final profileBytes = item.profile.yaml;
      final profileHash = sha256.convert(profileBytes).toString();
      final meta = utf8.encode('{}\n');
      files['profiles/${item.uid}.yaml'] = profileBytes;
      files['providers/${item.slug}/provider.yaml'] = profileBytes;
      files['providers/${item.slug}/profile.yaml'] = profileBytes;
      files['providers/${item.slug}/meta.json'] = meta;
      airports.add({
        'slug': item.slug,
        'subscriptionId': item.slug,
        'name': item.profile.name,
        'profileUid': item.uid,
        'versionId': 'sha256-${profileHash.substring(0, 16)}',
        'nodeCount': _nodeCount(profileBytes),
        'providerSha256': profileHash,
        'profileSha256': profileHash,
      });
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

  _ParsedExportProfile _parseProfile(WorkerV1ExportProfile profile) {
    if (profile.id < 0 || profile.id > 0xffffffff) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Profile id cannot be represented by Worker v1',
      );
    }
    final uri = Uri.tryParse(profile.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.pathSegments.length != 3 ||
        uri.pathSegments[0] != 'config' ||
        !RegExp(r'^[a-z0-9][a-z0-9-]{0,62}$').hasMatch(uri.pathSegments[1]) ||
        uri.pathSegments[2].isEmpty) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Profile URL is not a fixed Worker /config/{slug}/{token} URL',
      );
    }
    return _ParsedExportProfile(
      profile: profile,
      uid: 'R${profile.id.toRadixString(16).padLeft(8, '0')}',
      slug: uri.pathSegments[1],
      origin: uri.replace(path: '', query: null, fragment: null).toString(),
    );
  }

  String _profilesYaml(List<_ParsedExportProfile> profiles, String current) {
    final buffer = StringBuffer('current: $current\nitems:\n');
    for (final item in profiles) {
      final profile = item.profile;
      buffer
        ..writeln('  - uid: ${item.uid}')
        ..writeln('    type: remote')
        ..writeln('    name: ${jsonEncode(profile.name)}')
        ..writeln('    file: ${item.uid}.yaml')
        ..writeln('    url: ${jsonEncode(profile.url)}')
        ..writeln('    option:')
        ..writeln('      update_interval: ${profile.updateIntervalMinutes}')
        ..writeln('      allow_auto_update: ${profile.allowAutoUpdate}');
      if (profile.updated != null) {
        buffer.writeln(
          '    updated: ${profile.updated!.toUtc().millisecondsSinceEpoch ~/ 1000}',
        );
      }
    }
    return buffer.toString();
  }

  int _nodeCount(List<int> bytes) {
    try {
      final yaml = loadYaml(utf8.decode(bytes, allowMalformed: false));
      if (yaml is Map && yaml['proxies'] is List) {
        return (yaml['proxies'] as List).length;
      }
    } catch (_) {
      // Profile validation remains the caller's responsibility.
    }
    return 0;
  }
}

class _ParsedExportProfile {
  const _ParsedExportProfile({
    required this.profile,
    required this.uid,
    required this.slug,
    required this.origin,
  });

  final WorkerV1ExportProfile profile;
  final String uid;
  final String slug;
  final String origin;
}
