import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/yaml.dart';
import 'package:fl_clash/services/backup/worker_v1_parser.dart';
import 'package:fl_clash/services/backup/worker_v1_models.dart';
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
    final trustedArchive = input.trustedArchive;
    final trusted = trustedArchive == null
        ? null
        : const WorkerV1Parser().parse(trustedArchive);
    final trustedBase = trusted?.manifest.raw['publicBaseUrl'];
    if (trusted != null && !isTrustedUnifiedBackupBaseUrl(trustedBase)) {
      throw StateError('Trusted archive belongs to another Worker');
    }
    final standalone = trusted == null;
    final outputBaseUrl = standalone
        ? standaloneUnifiedBackupBaseUrl
        : trustedBase as String;
    final trustedItems = standalone
        ? <Map<String, Object?>>[]
        : (trusted.profilesYaml['items'] as List)
              .cast<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .toList();
    final fixedToken = standalone
        ? standaloneUnifiedBackupToken
        : _fixedToken(trustedItems);
    final trustedByAndroidId = <int, _TrustedIdentity>{};
    final trustedByClashVergeId = <int, _TrustedIdentity>{};
    final trustedByProfileHash = <String, List<_TrustedIdentity>>{};
    if (trusted != null) {
      for (final item in trustedItems) {
        final uid = item['uid'] as String;
        final id = int.parse(uid.substring(1), radix: 16);
        final airport = trusted.manifest.airports.singleWhere(
          (value) => value['profileUid'] == uid,
        );
        final trustedIdentity = _TrustedIdentity(
          identity: UnifiedIdentity(
            slug: airport['slug'] as String,
            subscriptionId: airport['subscriptionId'] as String,
            profileUid: uid,
          ),
          meta: Map<String, Object?>.from(
            jsonDecode(
                  utf8.decode(
                    trusted.files['providers/${airport['slug']}/meta.json']!,
                  ),
                )
                as Map,
          ),
        );
        trustedByAndroidId[id] = trustedIdentity;
        trustedByClashVergeId[deriveClashVergeProfileId(uid)] = trustedIdentity;
        final profileHash = airport['profileSha256'] as String;
        trustedByProfileHash
            .putIfAbsent(profileHash, () => <_TrustedIdentity>[])
            .add(trustedIdentity);
      }
    }

    final configMap = standalone
        ? <Object?, Object?>{}
        : _trustedConfig(trusted);
    final providers = configMap['proxy-providers'] is Map
        ? Map<Object?, Object?>.from(configMap['proxy-providers'] as Map)
        : <Object?, Object?>{};
    final files = <String, List<int>>{};
    final airports = <Map<String, Object?>>[];
    final profileItems = <Map<String, Object?>>[];
    final seenUids = <String>{};
    final seenSlugs = <String>{};
    final claimedTrustedUids = <String>{};
    final prepared = input.profiles
        .map((profile) {
          final profileHash = sha256.convert(profile.yaml).toString();
          final hashMatches = trustedByProfileHash[profileHash];
          final candidate =
              trustedByAndroidId[profile.androidId] ??
              trustedByClashVergeId[profile.androidId] ??
              (hashMatches != null && hashMatches.length == 1
                  ? hashMatches.single
                  : null);
          final trustedIdentity =
              candidate != null &&
                  claimedTrustedUids.add(candidate.identity.profileUid)
              ? candidate
              : null;
          final identity =
              trustedIdentity?.identity ??
              deriveUnifiedIdentity(profile.androidId);
          if (!seenUids.add(identity.profileUid) ||
              !seenSlugs.add(identity.slug)) {
            throw StateError('Unified profile identity collision');
          }
          final projected = projectProfile(profile.yaml);
          final providerHash = sha256
              .convert(projected.providerYaml)
              .toString();
          final versionId = 'sha256-${profileHash.substring(0, 16)}';
          return _PreparedProfile(
            profile: profile,
            identity: identity,
            projected: projected,
            profileHash: profileHash,
            providerHash: providerHash,
            versionId: versionId,
            trustedMeta: trustedIdentity?.meta,
          );
        })
        .toList(growable: false);
    final preparedBySlug = {
      for (final item in prepared) item.identity.slug: item,
    };

    for (final item in prepared) {
      final profile = item.profile;
      final identity = item.identity;
      final projected = item.projected;
      final profileHash = item.profileHash;
      final providerHash = item.providerHash;
      final versionId = item.versionId;
      final allowAutoUpdate = standalone ? false : profile.autoUpdate;
      final versionRoot = 'providers/${identity.slug}/versions/$versionId';
      final dependencyState = _rewriteDependencyState(item, preparedBySlug);
      final distribution = <String, Object?>{
        'providerName': profile.name,
        'sourceHost': '',
        if (profile.subscriptionInfo != null)
          'subscriptionUserinfo': _subscriptionUserinfo(
            profile.subscriptionInfo!,
          ),
        'clientUpdatePolicy': {
          'allowAutoUpdate': allowAutoUpdate,
          'updateIntervalMinutes': profile.updateIntervalMinutes,
        },
      };
      final meta = <String, Object?>{
        'schemaVersion': dependencyState == null ? 1 : 2,
        'providerSlug': identity.slug,
        'subscriptionId': identity.subscriptionId,
        'uid': identity.profileUid,
        'versionId': versionId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'sourceSha256': profileHash,
        'nodeCount': dependencyState?.nodeCount ?? projected.nodeCount,
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
        if (dependencyState != null) ...{
          'nodeStats': dependencyState.nodeStats,
          'internalDependencies': dependencyState.dependencies,
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
        'url': '$outputBaseUrl/provider/${identity.slug}/$fixedToken',
        'path': './providers/${identity.slug}.yaml',
        'interval': profile.updateIntervalMinutes * 60,
      };
      final extra = profile.subscriptionInfo;
      profileItems.add({
        'uid': identity.profileUid,
        'type': 'remote',
        'name': profile.name,
        'file': '${identity.profileUid}.yaml',
        'url': '$outputBaseUrl/config/${identity.slug}/$fixedToken',
        'updated': profile.updated,
        'option': {
          'allow_auto_update': allowAutoUpdate,
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
        'nodeCount': dependencyState?.nodeCount ?? projected.nodeCount,
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
        : prepared
              .singleWhere(
                (item) => item.profile.androidId == current.androidId,
              )
              .identity
              .profileUid;
    files['config.yaml'] = utf8.encode(
      '${yaml.encode(configMap).trimRight()}\n',
    );
    files['verge.yaml'] = standalone
        ? utf8.encode('language: zh\n')
        : trusted.files['verge.yaml']!;
    files['profiles.yaml'] = utf8.encode(
      '${yaml.encode({'current': currentIdentity, 'items': profileItems}).trimRight()}\n',
    );
    validateUnifiedFiles(files, airports);
    final configHash = sha256.convert(files['config.yaml']!).toString();
    final manifest = buildUnifiedManifest(
      createdAt: createdAt,
      generatorVersion: input.generatorVersion,
      files: files,
      airports: airports,
      mainConfig: standalone
          ? {
              'configId': 'slclash-standalone',
              'versionId': 'sha256-${configHash.substring(0, 16)}',
              'name': 'Slclash standalone snapshot',
              'sourceSha256': configHash,
            }
          : Map<String, Object?>.from(
              trusted.manifest.raw['mainConfig'] as Map,
            ),
      publicBaseUrl: outputBaseUrl,
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

  Map<Object?, Object?> _trustedConfig(WorkerV1Package trusted) {
    final config = _plain(loadYaml(utf8.decode(trusted.files['config.yaml']!)));
    if (config is! Map) throw StateError('Trusted config.yaml is invalid');
    return Map<Object?, Object?>.from(config);
  }

  String _subscriptionUserinfo(Map<String, int> info) =>
      'upload=${info['upload'] ?? 0}; download=${info['download'] ?? 0}; '
      'total=${info['total'] ?? 0}; expire=${info['expire'] ?? 0}';
}

class _TrustedIdentity {
  const _TrustedIdentity({required this.identity, required this.meta});
  final UnifiedIdentity identity;
  final Map<String, Object?> meta;
}

class _PreparedProfile {
  const _PreparedProfile({
    required this.profile,
    required this.identity,
    required this.projected,
    required this.profileHash,
    required this.providerHash,
    required this.versionId,
    required this.trustedMeta,
  });

  final UnifiedExportProfile profile;
  final UnifiedIdentity identity;
  final ProjectedProfile projected;
  final String profileHash;
  final String providerHash;
  final String versionId;
  final Map<String, Object?>? trustedMeta;
}

class _DependencyState {
  const _DependencyState({
    required this.nodeCount,
    required this.nodeStats,
    required this.dependencies,
  });

  final int nodeCount;
  final Map<String, Object?> nodeStats;
  final List<Map<String, Object?>> dependencies;
}

_DependencyState? _rewriteDependencyState(
  _PreparedProfile parent,
  Map<String, _PreparedProfile> preparedBySlug,
) {
  if (parent.profile.externalProvidersFlattened) return null;
  final trusted = parent.trustedMeta;
  if (trusted == null || trusted['schemaVersion'] != 2) return null;
  final rawStats = trusted['nodeStats'];
  final rawDependencies = trusted['internalDependencies'];
  if (rawStats is! Map || rawDependencies is! List || rawDependencies.isEmpty) {
    throw StateError(
      'Trusted schema v2 Provider is missing dependency statistics',
    );
  }
  final stats = Map<String, Object?>.from(rawStats);
  final inline = stats['inline'];
  final effective = stats['effective'];
  if (inline != parent.projected.nodeCount ||
      effective is! int ||
      effective <= 0) {
    throw StateError('Trusted Provider dependency statistics are stale');
  }
  final dependencies = <Map<String, Object?>>[];
  for (final raw in rawDependencies) {
    if (raw is! Map || raw['slug'] is! String) {
      throw StateError('Trusted Provider dependency identity is invalid');
    }
    final original = Map<String, Object?>.from(raw);
    final target = preparedBySlug[original['slug']];
    if (target == null || original['profileSha256'] != target.profileHash) {
      throw StateError(
        'Trusted Provider dependency content changed; refresh the Worker snapshot',
      );
    }
    dependencies.add({
      ...original,
      'subscriptionId': target.identity.subscriptionId,
      'uid': target.identity.profileUid,
      'versionId': target.versionId,
      'nodeCount': target.projected.nodeCount,
      'providerSha256': target.providerHash,
      'profileSha256': target.profileHash,
    });
  }
  final computedEffective =
      parent.projected.nodeCount +
      dependencies.fold<int>(
        0,
        (sum, dependency) => sum + (dependency['effectiveCount'] as int),
      );
  if (computedEffective != effective) {
    throw StateError('Trusted Provider effective node count is inconsistent');
  }
  return _DependencyState(
    nodeCount: effective,
    nodeStats: stats,
    dependencies: dependencies,
  );
}

Object? _plain(Object? value) {
  if (value is YamlMap) {
    return {for (final entry in value.entries) entry.key: _plain(entry.value)};
  }
  if (value is YamlList) return value.map(_plain).toList();
  return value;
}
