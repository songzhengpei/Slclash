import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/string.dart';
import 'package:fl_clash/common/yaml.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class UnifiedMaterializedProfile {
  const UnifiedMaterializedProfile({
    required this.yaml,
    required this.externalProvidersFlattened,
  });

  final Uint8List yaml;
  final bool externalProvidersFlattened;
}

Future<UnifiedMaterializedProfile> materializeProfileForUnifiedExport({
  required int profileId,
  required Uint8List profileBytes,
  required String profilesDirectory,
}) async {
  final decoded = loadYaml(utf8.decode(profileBytes, allowMalformed: false));
  if (decoded is! YamlMap) {
    throw const FormatException('Profile YAML root must be a mapping');
  }
  final config = Map<Object?, Object?>.from(_plain(decoded) as Map);
  final definitions = config['proxy-providers'];
  if (definitions is! Map || definitions.isEmpty) {
    return UnifiedMaterializedProfile(
      yaml: profileBytes,
      externalProvidersFlattened: false,
    );
  }

  final nodes = <Object?>[
    if (config['proxies'] case final List existing) ...existing,
  ];
  final providerNodeNames = <String, List<String>>{};

  for (final entry in definitions.entries) {
    final providerName = entry.key?.toString() ?? '';
    if (providerName.isEmpty || entry.value is! Map) {
      throw const FormatException('Profile contains an invalid proxy Provider');
    }
    final definition = Map<Object?, Object?>.from(entry.value as Map);
    final providerNodes = await _readProviderNodes(
      profileId: profileId,
      providerName: providerName,
      definition: definition,
      profilesDirectory: profilesDirectory,
    );
    final names = <String>[];
    for (final node in providerNodes) {
      if (node is! Map || node.isEmpty || node['name'] is! String) {
        throw FormatException(
          'Provider "$providerName" contains an invalid proxy node',
        );
      }
      nodes.add(node);
      names.add(node['name'] as String);
    }
    providerNodeNames[providerName] = names;
  }

  if (nodes.isEmpty) {
    throw const FormatException('Profile has no materialized proxy nodes');
  }
  config['proxies'] = nodes;
  _materializeProxyGroups(config, providerNodeNames);
  config.remove('proxy-providers');
  final text = '${yaml.encode(config).trimRight()}\n';
  return UnifiedMaterializedProfile(
    yaml: Uint8List.fromList(utf8.encode(text)),
    externalProvidersFlattened: true,
  );
}

Future<List<Object?>> _readProviderNodes({
  required int profileId,
  required String providerName,
  required Map<Object?, Object?> definition,
  required String profilesDirectory,
}) async {
  final payload = definition['payload'];
  if (payload is List && payload.isNotEmpty) {
    return List<Object?>.from(payload);
  }

  final candidates = <String>[];
  final url = definition['url'];
  if (url is String && url.isNotEmpty) {
    candidates.add(
      p.join(
        profilesDirectory,
        'providers',
        '$profileId',
        'proxies',
        url.toMd5(),
      ),
    );
  }
  final configuredPath = definition['path'];
  if (configuredPath is String && configuredPath.isNotEmpty) {
    candidates.add(
      p.isAbsolute(configuredPath)
          ? configuredPath
          : p.normalize(p.join(profilesDirectory, configuredPath)),
    );
  }

  for (final path in candidates.toSet()) {
    final file = File(path);
    if (!await file.exists()) continue;
    final decoded = loadYaml(
      utf8.decode(await file.readAsBytes(), allowMalformed: false),
    );
    if (decoded is! YamlMap || decoded['proxies'] is! YamlList) {
      throw FormatException(
        'Provider "$providerName" cache is not a valid proxy Provider',
      );
    }
    final proxies = decoded['proxies'] as YamlList;
    if (proxies.isEmpty) {
      throw FormatException('Provider "$providerName" cache has no nodes');
    }
    return proxies.map(_plain).toList(growable: false);
  }

  throw FormatException(
    'Provider "$providerName" has no local node data; load it before backup',
  );
}

void _materializeProxyGroups(
  Map<Object?, Object?> config,
  Map<String, List<String>> providerNodeNames,
) {
  final groups = config['proxy-groups'];
  if (groups is! List) return;
  for (final value in groups) {
    if (value is! Map) continue;
    final group = value;
    final uses = group['use'];
    if (uses is! List || uses.isEmpty) continue;
    final names = <Object?>[
      if (group['proxies'] case final List existing) ...existing,
    ];
    for (final provider in uses) {
      final materialized = providerNodeNames[provider.toString()];
      if (materialized == null) {
        throw FormatException(
          'Proxy group references unknown Provider "$provider"',
        );
      }
      names.addAll(materialized);
    }
    group['proxies'] = names;
    group.remove('use');
  }
}

Object? _plain(Object? value) {
  if (value is YamlMap) {
    return {for (final entry in value.entries) entry.key: _plain(entry.value)};
  }
  if (value is YamlList) return value.map(_plain).toList();
  return value;
}
