import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/services/backup/backup_format_detector.dart';
import 'package:fl_clash/services/backup/backup_limits.dart';
import 'package:fl_clash/services/backup/safe_zip_reader.dart';

class LegacyParsedPackage {
  final BackupFormat format;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? config;
  final Map<String, Uint8List> files;

  const LegacyParsedPackage({
    required this.format,
    required this.metadata,
    required this.files,
    this.config,
  });

  List<Map<String, dynamic>> get profiles =>
      _objectList(metadata['profiles'], field: 'profiles');

  int? get currentProfileId =>
      metadata['currentProfileId'] as int? ??
      config?['currentProfileId'] as int?;
}

class LegacyBackupParser {
  final BackupFormatDetector detector;
  final BackupLimits limits;

  const LegacyBackupParser({
    this.detector = const BackupFormatDetector(),
    this.limits = const BackupLimits(),
  });

  LegacyParsedPackage parseBytes(Uint8List bytes) {
    final zip = SafeZipReader(limits: limits).read(bytes);
    final files = zip.files.map(
      (name, content) => MapEntry(name, Uint8List.fromList(content)),
    );
    final format = detector.detectFiles(files);
    if (format == BackupFormat.workerUnifiedV1) {
      throw const BackupFormatException(
        BackupErrorCode.unsupportedFormat,
        'Worker unified backups must use the unified package parser',
      );
    }

    switch (format) {
      case BackupFormat.profilesOnlyV1:
      case BackupFormat.profilesOnlyV2:
        final metadata = _jsonObject(files['metadata.json']!, 'metadata.json');
        _validateProfiles(metadata);
        return LegacyParsedPackage(
          format: format,
          metadata: metadata,
          files: files,
        );
      case BackupFormat.traditional:
        final config = _jsonObject(files['config.json']!, 'config.json');
        return LegacyParsedPackage(
          format: format,
          metadata: <String, dynamic>{
            'currentProfileId': config['currentProfileId'],
          },
          config: config,
          files: files,
        );
      case BackupFormat.legacyConfigOnly:
        final config = _jsonObject(files['config.json']!, 'config.json');
        _validateProfiles(config);
        return LegacyParsedPackage(
          format: format,
          metadata: <String, dynamic>{
            'profiles': config['profiles'],
            'currentProfileId': config['currentProfileId'],
          },
          config: config,
          files: files,
        );
      case BackupFormat.workerUnifiedV1:
        throw StateError('unreachable');
    }
  }
}

Map<String, dynamic> _jsonObject(Uint8List bytes, String name) {
  try {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map) throw const FormatException('expected JSON object');
    return Map<String, dynamic>.from(value);
  } catch (error) {
    throw BackupFormatException(
      BackupErrorCode.unsupportedFormat,
      'Invalid $name: $error',
    );
  }
}

void _validateProfiles(Map<String, dynamic> source) {
  _objectList(source['profiles'], field: 'profiles');
}

List<Map<String, dynamic>> _objectList(Object? value, {required String field}) {
  if (value is! List) {
    throw BackupFormatException(
      BackupErrorCode.invalidProfiles,
      '$field must be a list',
    );
  }
  try {
    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  } catch (error) {
    throw BackupFormatException(
      BackupErrorCode.invalidProfiles,
      '$field must contain JSON objects: $error',
    );
  }
}
