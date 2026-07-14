import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'backup_error.dart';
import 'backup_limits.dart';
import 'safe_zip_reader.dart';
import 'worker_v1_models.dart';

class WorkerV1Parser {
  const WorkerV1Parser({this.limits = const BackupLimits()});

  final BackupLimits limits;

  WorkerV1Package parse(List<int> archiveBytes) {
    final zip = SafeZipReader(limits: limits).read(archiveBytes);
    final manifestBytes = zip.files['manifest.json'];
    if (manifestBytes == null) {
      throw const BackupFormatException(
        BackupErrorCode.missingManifest,
        'manifest.json is missing',
      );
    }
    if (manifestBytes.length > limits.maxManifestBytes) {
      throw const BackupFormatException(
        BackupErrorCode.entryTooLarge,
        'manifest.json exceeds its size limit',
      );
    }
    final rawManifest = _decodeJsonMap(manifestBytes);
    if (rawManifest['format'] != 'mihomo-unified-backup' ||
        rawManifest['archiveType'] != 'unified-subscription-archive' ||
        rawManifest['formatVersion'] != 1) {
      throw const BackupFormatException(
        BackupErrorCode.unsupportedFormat,
        'Backup format or version is not supported',
      );
    }
    _requireManifestShape(rawManifest);
    final fileEntries = _parseFileEntries(rawManifest['files']);

    final actualPaths = zip.files.keys
        .where((path) => path != 'manifest.json')
        .toSet();
    if (!actualPaths.containsAll(fileEntries.keys) ||
        !fileEntries.keys.toSet().containsAll(actualPaths)) {
      throw const BackupFormatException(
        BackupErrorCode.unexpectedFile,
        'Manifest file list does not match ZIP contents',
      );
    }
    for (final entry in fileEntries.entries) {
      final content = zip.files[entry.key]!;
      if (content.length != entry.value.contentLength) {
        throw const BackupFormatException(
          BackupErrorCode.sizeMismatch,
          'A manifest content length does not match',
        );
      }
      if (sha256.convert(content).toString() != entry.value.sha256) {
        throw const BackupFormatException(
          BackupErrorCode.hashMismatch,
          'A manifest hash does not match',
        );
      }
      if (entry.value.required && content.isEmpty) {
        throw const BackupFormatException(
          BackupErrorCode.missingRequiredFile,
          'A required backup file is empty',
        );
      }
    }
    for (final path in const ['config.yaml', 'verge.yaml', 'profiles.yaml']) {
      if (fileEntries[path]?.required != true || zip.files[path] == null) {
        throw const BackupFormatException(
          BackupErrorCode.missingRequiredFile,
          'A required root file is missing',
        );
      }
    }

    final airports = _parseAirports(rawManifest['airports']);
    for (final airport in airports) {
      final uid = airport['profileUid'];
      if (uid is! String ||
          !RegExp(r'^R[0-9a-f]{8}$').hasMatch(uid) ||
          fileEntries['profiles/$uid.yaml']?.required != true) {
        throw const BackupFormatException(
          BackupErrorCode.missingRequiredFile,
          'An airport profile is missing or invalid',
        );
      }
    }
    final profilesBytes = zip.files['profiles.yaml']!;
    if (profilesBytes.length > limits.maxProfilesBytes) {
      throw const BackupFormatException(
        BackupErrorCode.entryTooLarge,
        'profiles.yaml exceeds its size limit',
      );
    }
    final profiles = _decodeYamlMap(profilesBytes);
    if (profiles['current'] is! String || profiles['items'] is! List) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'profiles.yaml has an invalid shape',
      );
    }
    return WorkerV1Package(
      manifest: WorkerV1Manifest(
        raw: Map<String, Object?>.unmodifiable(rawManifest),
        files: Map<String, WorkerV1FileEntry>.unmodifiable(fileEntries),
        airports: List<Map<String, Object?>>.unmodifiable(airports),
      ),
      profilesYaml: Map<String, Object?>.unmodifiable(profiles),
      files: zip.files,
    );
  }

  Map<String, Object?> _decodeJsonMap(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (value is Map<String, dynamic>) return value;
    } catch (_) {
      // Converted to the stable domain error below.
    }
    throw const BackupFormatException(
      BackupErrorCode.invalidManifest,
      'manifest.json is not a valid JSON object',
    );
  }

  void _requireManifestShape(Map<String, Object?> manifest) {
    if (manifest['createdAt'] is! String ||
        DateTime.tryParse(manifest['createdAt'] as String) == null ||
        manifest['generator'] != 'worker' ||
        manifest['generatorVersion'] != '1.0.0' ||
        manifest['publicBaseUrl'] is! String ||
        manifest['mainConfig'] is! Map ||
        manifest['airports'] is! List ||
        manifest['files'] is! Map) {
      throw const BackupFormatException(
        BackupErrorCode.invalidManifest,
        'manifest.json is missing required fields',
      );
    }
    final baseUrl = Uri.tryParse(manifest['publicBaseUrl'] as String);
    final mainConfig = manifest['mainConfig'] as Map;
    if (baseUrl == null ||
        baseUrl.scheme != 'https' ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        mainConfig['configId'] is! String ||
        mainConfig['versionId'] is! String ||
        mainConfig['name'] is! String ||
        mainConfig['sourceSha256'] is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(mainConfig['sourceSha256'] as String)) {
      throw const BackupFormatException(
        BackupErrorCode.invalidManifest,
        'manifest.json contains invalid metadata',
      );
    }
  }

  Map<String, WorkerV1FileEntry> _parseFileEntries(Object? value) {
    if (value is! Map) {
      throw const BackupFormatException(
        BackupErrorCode.invalidManifest,
        'Invalid files map',
      );
    }
    final result = <String, WorkerV1FileEntry>{};
    for (final item in value.entries) {
      if (item.key is! String || item.value is! Map) {
        throw const BackupFormatException(
          BackupErrorCode.invalidManifest,
          'Invalid file entry',
        );
      }
      final path = item.key as String;
      final data = item.value as Map;
      final hash = data['sha256'];
      final length = data['contentLength'];
      final required = data['required'];
      if (path == 'manifest.json' ||
          path.endsWith('/') ||
          hash is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
          length is! int ||
          length < 0 ||
          required is! bool) {
        throw const BackupFormatException(
          BackupErrorCode.invalidManifest,
          'Invalid file metadata',
        );
      }
      result[path] = WorkerV1FileEntry(
        sha256: hash,
        contentLength: length,
        required: required,
      );
    }
    return result;
  }

  List<Map<String, Object?>> _parseAirports(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const BackupFormatException(
        BackupErrorCode.invalidManifest,
        'Invalid airports list',
      );
    }
    final result = <Map<String, Object?>>[];
    for (final item in value) {
      if (item is! Map) {
        throw const BackupFormatException(
          BackupErrorCode.invalidManifest,
          'Invalid airport entry',
        );
      }
      final airport = <String, Object?>{};
      for (final entry in item.entries) {
        if (entry.key is! String) {
          throw const BackupFormatException(
            BackupErrorCode.invalidManifest,
            'Invalid airport field',
          );
        }
        airport[entry.key as String] = entry.value;
      }
      if (airport['slug'] is! String ||
          airport['subscriptionId'] is! String ||
          airport['name'] is! String ||
          airport['profileUid'] is! String ||
          airport['versionId'] is! String ||
          airport['nodeCount'] is! int ||
          airport['providerSha256'] is! String ||
          airport['profileSha256'] is! String) {
        throw const BackupFormatException(
          BackupErrorCode.invalidManifest,
          'Invalid airport metadata',
        );
      }
      result.add(Map<String, Object?>.unmodifiable(airport));
    }
    return result;
  }

  Map<String, Object?> _decodeYamlMap(List<int> bytes) {
    try {
      final decoded = loadYaml(utf8.decode(bytes, allowMalformed: false));
      final converted = _yamlToDart(decoded);
      if (converted is Map<String, Object?>) return converted;
    } catch (_) {
      // Converted to the stable domain error below.
    }
    throw const BackupFormatException(
      BackupErrorCode.invalidProfiles,
      'profiles.yaml is not a valid mapping',
    );
  }

  Object? _yamlToDart(Object? value) {
    if (value is YamlMap || value is Map) {
      final result = <String, Object?>{};
      for (final entry in (value as Map).entries) {
        if (entry.key is! String) {
          throw const FormatException('Non-string YAML key');
        }
        result[entry.key as String] = _yamlToDart(entry.value);
      }
      return result;
    }
    if (value is YamlList || value is List) {
      return (value as List).map(_yamlToDart).toList(growable: false);
    }
    return value;
  }
}
