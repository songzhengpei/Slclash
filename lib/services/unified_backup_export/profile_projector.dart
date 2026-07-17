import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/common/yaml.dart';
import 'package:yaml/yaml.dart';

class ProjectedProfile {
  const ProjectedProfile({required this.providerYaml, required this.nodeCount});

  final Uint8List providerYaml;
  final int nodeCount;
}

ProjectedProfile projectProfile(Uint8List profileBytes) {
  final value = loadYaml(utf8.decode(profileBytes, allowMalformed: false));
  if (value is! YamlMap) {
    throw const FormatException('Profile YAML root must be a mapping');
  }
  final proxies = value['proxies'];
  if (proxies is! YamlList || proxies.isEmpty) {
    throw const FormatException('Profile has no materialized proxy nodes');
  }
  final normalized = proxies.map(_plain).toList(growable: false);
  if (normalized.any((node) => node is! Map || node.isEmpty)) {
    throw const FormatException('Profile contains an invalid proxy node');
  }
  final text = '${yaml.encode({'proxies': normalized}).trimRight()}\n';
  return ProjectedProfile(
    providerYaml: Uint8List.fromList(utf8.encode(text)),
    nodeCount: normalized.length,
  );
}

Object? _plain(Object? value) {
  if (value is YamlMap) {
    return {for (final entry in value.entries) entry.key: _plain(entry.value)};
  }
  if (value is YamlList) return value.map(_plain).toList();
  return value;
}
