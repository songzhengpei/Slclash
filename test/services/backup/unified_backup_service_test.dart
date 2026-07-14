import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/services/backup/restore_service.dart';
import 'package:fl_clash/services/backup/unified_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'v2 backup preserves custom profile, groups, settings and defaults',
    () async {
      final temp = await Directory.systemTemp.createTemp('unified-v2-test-');
      final db = Database(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        await temp.delete(recursive: true);
      });
      final metadata = {
        'backupType': 'profiles_only_v2',
        'currentProfileId': 7,
        'profiles': [
          {
            'id': 7,
            'label': 'custom',
            'url': 'https://example.test/sub',
            'overwriteType': 'custom',
          },
        ],
        'scripts': <Object>[],
        'rules': <Object>[],
        'links': <Object>[],
        'proxyGroups': [
          {
            'profileId': 7,
            'id': 70,
            'name': 'Custom Group',
            'type': 'select',
            'proxies': ['DIRECT'],
          },
        ],
        'config': {
          'currentProfileId': 7,
          'overrideDns': true,
          'themeProps': <String, Object?>{},
        },
      };
      final archive = Archive()
        ..addFile(ArchiveFile.string('metadata.json', jsonEncode(metadata)))
        ..addFile(ArchiveFile.string('profiles/7.yaml', 'proxies: []'));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final result = await UnifiedBackupService(
        database: db,
        paths: RestorePaths(
          profilesDirectory: p.join(temp.path, 'profiles'),
          scriptsDirectory: p.join(temp.path, 'scripts'),
        ),
      ).restoreBytes(bytes, override: true);

      final restored = (await db.profilesDao.query().get()).single;
      expect(restored.overwriteType, OverwriteType.custom);
      expect(restored.autoUpdateDuration, const Duration(days: 1));
      expect(
        (await db.proxyGroupsDao.query(7).get()).single.name,
        'Custom Group',
      );
      expect(result.config?.overrideDns, true);
      expect(result.currentProfileId, 7);
    },
  );
}
