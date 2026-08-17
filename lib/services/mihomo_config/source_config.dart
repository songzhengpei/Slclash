import 'dart:convert';

import 'package:yaml/yaml.dart';

typedef MihomoConfigMap = Map<String, dynamic>;

/// Parses a Mihomo YAML document into isolate-safe plain Dart structures.
MihomoConfigMap parseMihomoSourceConfig(String source) {
  final document = loadYaml(source);
  final plain = toPlainDartStructure(document);
  if (plain is! Map<String, dynamic>) {
    throw const FormatException('Mihomo source config root must be a map');
  }
  return plain;
}

/// Converts YAML collections (and nested ordinary collections) into fresh,
/// plain Dart structures containing only JSON-compatible scalar values.
dynamic toPlainDartStructure(dynamic value) {
  if (value is YamlMap || value is Map) {
    final result = <String, dynamic>{};
    for (final entry in (value as Map).entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('Mihomo config map key must be a string: $key');
      }
      result[key] = toPlainDartStructure(entry.value);
    }
    return result;
  }
  if (value is YamlList || value is List) {
    return (value as List).map(toPlainDartStructure).toList();
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw FormatException(
    'Unsupported Mihomo config value type: ${value.runtimeType}',
  );
}

/// Uses the original source as a preservation base while keeping normalized
/// Mihomo values authoritative. Lists are replaced, not structurally merged.
MihomoConfigMap mergeSourceWithNormalized(
  MihomoConfigMap source,
  MihomoConfigMap normalized,
) {
  final result = Map<String, dynamic>.from(
    toPlainDartStructure(source) as Map<String, dynamic>,
  );
  for (final entry in normalized.entries) {
    final sourceValue = result[entry.key];
    final normalizedValue = entry.value;
    if (sourceValue is Map && normalizedValue is Map) {
      result[entry.key] = mergeSourceWithNormalized(
        Map<String, dynamic>.from(
          toPlainDartStructure(sourceValue) as Map<String, dynamic>,
        ),
        Map<String, dynamic>.from(
          toPlainDartStructure(normalizedValue) as Map<String, dynamic>,
        ),
      );
    } else {
      result[entry.key] = toPlainDartStructure(normalizedValue);
    }
  }
  return result;
}

/// Resolves the non-Script runtime base from ONE profile snapshot so the
/// generic source parse and the Mihomo normalization always consume the same
/// bytes (no source B + normalized A). Any failure in snapshot reading, source
/// parsing, Core normalization, or overlay abandons preservation entirely and
/// falls back to the normalized-only path; a partially preserved overlay is
/// never produced.
Future<MihomoConfigMap> resolveSnapshotRuntimeBase({
  required Future<List<int>> Function() loadSnapshot,
  required Future<MihomoConfigMap> Function(List<int> snapshot)
      normalizeSnapshot,
  required Future<MihomoConfigMap> Function() fallbackNormalized,
  void Function(Object error, StackTrace stackTrace)? onPreservationFailure,
}) async {
  try {
    final snapshot = await loadSnapshot();
    final sourceConfig = parseMihomoSourceConfig(utf8.decode(snapshot));
    final normalizedConfig = await normalizeSnapshot(snapshot);
    return mergeSourceWithNormalized(sourceConfig, normalizedConfig);
  } catch (error, stackTrace) {
    onPreservationFailure?.call(error, stackTrace);
    return fallbackNormalized();
  }
}
