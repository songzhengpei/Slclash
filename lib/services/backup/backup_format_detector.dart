import 'dart:convert';
import 'dart:typed_data';

import 'backup_error.dart';
import 'safe_zip_reader.dart';

export 'backup_error.dart';

enum BackupFormat {
  workerUnifiedV1,
  profilesOnlyV1,
  profilesOnlyV2,
  clashVergeRev,
  traditional,
  legacyConfigOnly,
}

class BackupFormatDetector {
  const BackupFormatDetector();

  BackupFormat detectBytes(Uint8List bytes) {
    final zip = const SafeZipReader().read(bytes);
    return detectFiles(
      zip.files.map(
        (name, content) => MapEntry(name, Uint8List.fromList(content)),
      ),
    );
  }

  BackupFormat detectFiles(Map<String, Uint8List> files) {
    if (files.containsKey('manifest.json')) {
      return BackupFormat.workerUnifiedV1;
    }

    if (files.containsKey('metadata.json')) {
      final metadata = _readJsonObject(files, 'metadata.json');
      return switch (metadata['backupType']) {
        'profiles_only_v1' => BackupFormat.profilesOnlyV1,
        'profiles_only_v2' => BackupFormat.profilesOnlyV2,
        'profiles_only_v3' => throw const BackupFormatException(
          BackupErrorCode.unsupportedFormat,
          'profiles_only_v3 backups are no longer supported',
        ),
        final Object? value => throw BackupFormatException(
          BackupErrorCode.unsupportedFormat,
          'Unsupported profiles backup type: ${value ?? '(missing)'}',
        ),
      };
    }

    if (files.containsKey('profiles.yaml') &&
        files.containsKey('config.yaml') &&
        files.containsKey('verge.yaml') &&
        files.keys.any(
          (name) => name.startsWith('profiles/') && name.endsWith('.yaml'),
        )) {
      return BackupFormat.clashVergeRev;
    }

    final hasDatabase = files.containsKey('database.sqlite');
    final hasConfig = files.containsKey('config.json');
    if (hasDatabase && hasConfig) return BackupFormat.traditional;
    if (hasDatabase) {
      throw const BackupFormatException(
        BackupErrorCode.missingRequiredFile,
        'Traditional backup is missing config.json',
      );
    }
    if (hasConfig) {
      final config = _readJsonObject(files, 'config.json');
      final version = config['version'];
      if ((version == null || version == 0) && config['profiles'] is List) {
        return BackupFormat.legacyConfigOnly;
      }
      throw BackupFormatException(
        BackupErrorCode.unsupportedFormat,
        'Unsupported config-only backup version: ${version ?? '(missing)'}',
      );
    }
    throw const BackupFormatException(
      BackupErrorCode.unsupportedFormat,
      'Unrecognized backup format',
    );
  }
}

Map<String, dynamic> _readJsonObject(
  Map<String, Uint8List> files,
  String name,
) {
  final content = files[name];
  if (content == null) {
    throw BackupFormatException(
      BackupErrorCode.missingRequiredFile,
      'Missing $name',
    );
  }
  try {
    final value = jsonDecode(utf8.decode(content));
    if (value is! Map) throw const FormatException('expected JSON object');
    return Map<String, dynamic>.from(value);
  } catch (error) {
    throw BackupFormatException(
      BackupErrorCode.unsupportedFormat,
      'Invalid $name: $error',
    );
  }
}
