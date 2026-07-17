import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/yaml.dart';
import 'package:fl_clash/services/backup/worker_v1_parser.dart';
import 'package:yaml/yaml.dart';

import 'identity.dart';
import 'manifest_builder.dart';
import 'models.dart';
import 'profile_projector.dart';
import 'validator.dart';

class UnifiedV1Exporter {
  const UnifiedV1Exporter();

  Uint8List build(UnifiedExportInput input) {
    if (input.profiles.isEmpty) {
      throw StateError('Cannot export an empty unified archive');
    }
    for (final profile in input.profiles) {
      if (profile.updateIntervalMinutes <= 0 ||
          profile.updateIntervalMinutes > maxClientUpdateIntervalMinutes) {
        throw RangeError.range(
          profile.updateIntervalMinutes,
          1,
          maxClientUpdateIntervalMinutes,
          'updateIntervalMinutes',
        );
      }
    }
    final createdAt = input.createdAt ?? DateTime.now();
    final trusted = const WorkerV1Parser().parse(input.trustedArchive);
    final trustedBase = trusted.manifest.raw['publicBaseUrl'];
    if (trustedBase != unifiedBackupPublicBaseUrl) {
      throw StateError('Trusted archive belongs to another Worker');
    }
    final trustedItems = (trusted.profilesYaml['items'] as List)
        .cast<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    final fixedToken = _fixedToken(trustedItems);
    final trustedByAndroidId = <int, _TrustedIdentity>{};
    for (final item in trustedItems) {
      final uid = item['uid'] as String;
      final id = int.parse(uid.substring(1), radix: 16);
      final airport = trusted.manifest.airports.singleWhere(
        (value) => value['profileUid'] == uid,
      );
      trustedByAndroidId[id] = _TrustedIdentity(
        identity: UnifiedIdentity(
          slug: airport['slug'] as String,
          subscriptionId: airport['subscriptionId'] as String,
          profileUid: uid,
        ),
      );
    }

    final config = _plain(loadYaml(utf8.decode(trusted.files['config.yaml']!)));
    if (config is! Map) throw StateError('Trusted config.yaml is invalid');
    final configMap = Map<Object?, Object?>.from(config);
    final providers = configMap['proxy-providers'] is Map
        ? Map<Object?, Object?>.from(configMap['proxy-providers'] as Map)
        : <Object?, Object?>{};
    final files = <String, List<int>>{};
    final airports = <Map<String, Object?>>[];
    final profileItems = <Map<String, Object?>>[];
    final seenUids = <String>{};
    final seenSlugs = <String>{};

    for (final profile in input.profiles) {
      final identity =
          trustedByAndroidId[profile.androidId]?.identity ??
          deriveUnifiedIdentity(profile.androidId);
      if (!seenUids.add(identity.profileUid) || !seenSlugs.add(identity.slug)) {
        throw StateError('Unified profile identity collision');
      }
      final projected = projectProfile(profile.yaml);
      final profileHash = sha256.convert(profile.yaml).toString();
      final providerHash = sha256.convert(projected.providerYaml).toString();
      final versionId = 'sha256-${profileHash.substring(0, 16)}';
      final versionRoot = 'providers/${identity.slug}/versions/$versionId';
      final distribution = <String, Object?>{
        'providerName': profile.name,
        'sourceHost': '',
        if (profile.subscriptionInfo != null)
          'subscriptionUserinfo': _subscriptionUserinfo(
            profile.subscriptionInfo!,
          ),
        'clientUpdatePolicy': {
          'allowAutoUpdate': profile.autoUpdate,
          'updateIntervalMinutes': profile.updateIntervalMinutes,
        },
      };
      final meta = <String, Object?>{
        'schemaVersion': 1,
        'providerSlug': identity.slug,
        'subscriptionId': identity.subscriptionId,
        'uid': identity.profileUid,
        'versionId': versionId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'sourceSha256': profileHash,
        'nodeCount': projected.nodeCount,
        'generatorVersion': input.generatorVersion,
        'distribution': distribution,
        'artifacts': {
          'raw': {
            'key': '$versionRoot/raw.yaml',
            'sha256': profileHash,
            'contentLength': profile.yaml.length,
          },
          'provider': {
            'key': '$versionRoot/provider.yaml',
            'sha256': providerHash,
            'contentLength': projected.providerYaml.length,
          },
          'profile': {
            'key': '$versionRoot/profile.yaml',
            'sha256': profileHash,
            'contentLength': profile.yaml.length,
          },
        },
      };
      files['profiles/${identity.profileUid}.yaml'] = profile.yaml;
      files['providers/${identity.slug}/provider.yaml'] =
          projected.providerYaml;
      files['providers/${identity.slug}/profile.yaml'] = profile.yaml;
      files['providers/${identity.slug}/meta.json'] = utf8.encode(
        jsonEncode(meta),
      );
      providers[identity.slug] = {
        'type': 'http',
        'url':
            '$unifiedBackupPublicBaseUrl/provider/${identity.slug}/$fixedToken',
        'path': './providers/${identity.slug}.yaml',
        'interval': profile.updateIntervalMinutes * 60,
      };
      final extra = profile.subscriptionInfo;
      profileItems.add({
        'uid': identity.profileUid,
        'type': 'remote',
        'name': profile.name,
        'file': '${identity.profileUid}.yaml',
        'url':
            '$unifiedBackupPublicBaseUrl/config/${identity.slug}/$fixedToken',
        'updated': profile.updated,
        'option': {
          'allow_auto_update': profile.autoUpdate,
          'update_interval': profile.updateIntervalMinutes,
        },
        'extra': ?extra,
      });
      airports.add({
        'slug': identity.slug,
        'subscriptionId': identity.subscriptionId,
        'name': profile.name,
        'profileUid': identity.profileUid,
        'versionId': versionId,
        'nodeCount': projected.nodeCount,
        'providerSha256': providerHash,
        'profileSha256': profileHash,
      });
    }
    configMap['proxy-providers'] = providers;
    final current = input.profiles
        .where((profile) => profile.androidId == input.currentAndroidId)
        .firstOrNull;
    final currentIdentity = current == null
        ? airports.first['profileUid']
        : (trustedByAndroidId[current.androidId]?.identity ??
                  deriveUnifiedIdentity(current.androidId))
              .profileUid;
    files['config.yaml'] = utf8.encode(
      '${yaml.encode(configMap).trimRight()}\n',
    );
    files['verge.yaml'] = trusted.files['verge.yaml']!;
    files['profiles.yaml'] = utf8.encode(
      '${yaml.encode({'current': currentIdentity, 'items': profileItems}).trimRight()}\n',
    );
    validateUnifiedFiles(files, airports);
    final manifest = buildUnifiedManifest(
      createdAt: createdAt,
      generatorVersion: input.generatorVersion,
      files: files,
      airports: airports,
      mainConfig: Map<String, Object?>.from(
        trusted.manifest.raw['mainConfig'] as Map,
      ),
      publicBaseUrl: unifiedBackupPublicBaseUrl,
    );
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile.bytes(entry.key, entry.value)
          ..lastModTime = createdAt.millisecondsSinceEpoch ~/ 1000,
      );
    }
    archive.addFile(
      ArchiveFile.string('manifest.json', jsonEncode(manifest))
        ..lastModTime = createdAt.millisecondsSinceEpoch ~/ 1000,
    );
    return Uint8List.fromList(ZipEncoder().encode(archive, level: 0));
  }

  String _fixedToken(List<Map<String, Object?>> items) {
    final tokens = items.map((item) {
      final uri = Uri.parse(item['url'] as String);
      if (uri.pathSegments.length != 3 || uri.pathSegments.first != 'config') {
        throw StateError('Trusted profile has an invalid fixed URL');
      }
      return uri.pathSegments.last;
    }).toSet();
    if (tokens.length != 1 || tokens.single.isEmpty) {
      throw StateError('Trusted profiles do not share one fixed token');
    }
    return tokens.single;
  }

  String _subscriptionUserinfo(Map<String, int> info) =>
      'upload=${info['upload'] ?? 0}; download=${info['download'] ?? 0}; '
      'total=${info['total'] ?? 0}; expire=${info['expire'] ?? 0}';
}

class _TrustedIdentity {
  const _TrustedIdentity({required this.identity});
  final UnifiedIdentity identity;
}

Object? _plain(Object? value) {
  if (value is YamlMap) {
    return {for (final entry in value.entries) entry.key: _plain(entry.value)};
  }
  if (value is YamlList) return value.map(_plain).toList();
  return value;
}
