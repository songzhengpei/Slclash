import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/unified_backup_export/models.dart';
import 'package:yaml/yaml.dart';

import 'backup_error.dart';
import 'restore_bundle.dart';
import 'safe_zip_reader.dart';

class ClashVergeBackupPackage {
  const ClashVergeBackupPackage({
    required this.profiles,
    required this.currentProfileId,
    required this.files,
  });

  final List<Profile> profiles;
  final int? currentProfileId;
  final List<StagedRestoreFile> files;
}

/// Imports only subscription entries from an official Clash Verge Rev backup.
/// Application settings and profile helpers are intentionally ignored.
class ClashVergeBackupParser {
  const ClashVergeBackupParser();

  ClashVergeBackupPackage parse(Uint8List bytes) {
    final zip = const SafeZipReader().read(bytes);
    final profilesYaml = zip.files['profiles.yaml'];
    if (profilesYaml == null) {
      throw const BackupFormatException(
        BackupErrorCode.missingRequiredFile,
        'Clash Verge Rev backup is missing profiles.yaml',
      );
    }
    final root = _yamlObject(profilesYaml, 'profiles.yaml');
    final rawItems = root['items'];
    if (rawItems is! List) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Clash Verge Rev profiles.yaml items must be a list',
      );
    }

    final profiles = <Profile>[];
    final files = <StagedRestoreFile>[];
    final uidToId = <String, int>{};
    final ids = <int>{};
    final seenUids = <String>{};
    final seenFiles = <String>{};
    for (var index = 0; index < rawItems.length; index++) {
      final raw = rawItems[index];
      if (raw is! Map) continue;
      final item = Map<Object?, Object?>.from(raw);
      final type = item['type'];
      if (type != 'remote' && type != 'local') continue;
      final uid = item['uid'];
      final fileName = item['file'];
      if (uid is! String || uid.isEmpty || fileName is! String) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'Clash Verge Rev subscription identity is invalid',
        );
      }
      if (!seenUids.add(uid) ||
          !seenFiles.add(fileName) ||
          fileName != '$uid.yaml') {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'Clash Verge Rev subscription identity or file is duplicated',
        );
      }
      final url = item['url'];
      if (type == 'remote' && (url is! String || url.trim().isEmpty)) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'Clash Verge Rev remote subscription URL is missing',
        );
      }
      final yamlBytes = zip.files['profiles/$fileName'];
      if (yamlBytes == null || yamlBytes.isEmpty) {
        throw BackupFormatException(
          BackupErrorCode.missingRequiredFile,
          'Clash Verge Rev subscription file is missing: $fileName',
        );
      }
      final id = int.parse(
        sha256
            .convert(utf8.encode('clash-verge-rev\n$uid'))
            .toString()
            .substring(0, 15),
        radix: 16,
      );
      if (!ids.add(id)) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'Clash Verge Rev subscription identity collision',
        );
      }
      uidToId[uid] = id;
      final option = item['option'] is Map
          ? Map<Object?, Object?>.from(item['option'] as Map)
          : const <Object?, Object?>{};
      final interval = option['update_interval'];
      if (interval != null &&
          (interval is! int ||
              interval <= 0 ||
              interval > maxClientUpdateIntervalMinutes)) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'Clash Verge Rev update interval is invalid',
        );
      }
      final allowAutoUpdate = option['allow_auto_update'];
      if (allowAutoUpdate != null && allowAutoUpdate is! bool) {
        throw const BackupFormatException(
          BackupErrorCode.invalidProfiles,
          'Clash Verge Rev auto update policy is invalid',
        );
      }
      final intervalMinutes = interval is int ? interval : 1440;
      final extra = item['extra'] is Map
          ? Map<Object?, Object?>.from(item['extra'] as Map)
          : const <Object?, Object?>{};
      final updated = item['updated'];
      profiles.add(
        Profile(
          id: id,
          label: item['name'] is String ? item['name'] as String : uid,
          url: type == 'remote' ? url as String : '',
          lastUpdateDate: updated is int
              ? DateTime.fromMillisecondsSinceEpoch(updated * 1000, isUtc: true)
              : null,
          autoUpdateDuration: Duration(minutes: intervalMinutes),
          autoUpdate: type == 'remote' && allowAutoUpdate != false,
          subscriptionInfo: extra.isEmpty
              ? null
              : SubscriptionInfo(
                  upload: _integer(extra['upload']),
                  download: _integer(extra['download']),
                  total: _integer(extra['total']),
                  expire: _integer(extra['expire']),
                ),
          order: profiles.length,
        ),
      );
      files.add(
        StagedRestoreFile(
          relativePath: 'profiles/$id.yaml',
          bytes: Uint8List.fromList(yamlBytes),
        ),
      );
    }
    if (profiles.isEmpty) {
      throw const BackupFormatException(
        BackupErrorCode.invalidProfiles,
        'Clash Verge Rev backup contains no subscription profiles',
      );
    }
    final current = root['current'];
    return ClashVergeBackupPackage(
      profiles: List.unmodifiable(profiles),
      currentProfileId: current is String ? uidToId[current] : null,
      files: List.unmodifiable(files),
    );
  }
}

Map<Object?, Object?> _yamlObject(List<int> bytes, String name) {
  try {
    final value = loadYaml(utf8.decode(bytes, allowMalformed: false));
    if (value is! Map) throw const FormatException('expected YAML object');
    return Map<Object?, Object?>.from(value);
  } catch (error) {
    throw BackupFormatException(
      BackupErrorCode.invalidYaml,
      'Invalid $name: $error',
    );
  }
}

int _integer(Object? value) => value is int ? value : 0;
