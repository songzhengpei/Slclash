import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/services/backup/backup_format_detector.dart';
import 'package:fl_clash/services/backup/clash_verge_backup_parser.dart';
import 'package:fl_clash/services/backup/restore_service.dart';
import 'package:fl_clash/services/backup/unified_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('detects and parses only Clash Verge Rev subscription profiles', () {
    final bytes = _clashVergeBackup();
    expect(
      const BackupFormatDetector().detectBytes(bytes),
      BackupFormat.clashVergeRev,
    );
    final package = const ClashVergeBackupParser().parse(bytes);
    expect(package.profiles.map((profile) => profile.label), [
      'Remote',
      'Local',
    ]);
    expect(package.profiles.first.url, 'https://airport.example/sub');
    expect(package.profiles.last.url, isEmpty);
    expect(package.profiles.map((profile) => profile.order), [0, 1]);
    expect(package.currentProfileId, package.profiles.first.id);
    expect(package.files, hasLength(2));
  });

  test(
    'restores Verge subscriptions without restoring Verge settings',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'clash-verge-restore-',
      );
      final db = Database(NativeDatabase.memory());
      final trustedArchive = File(p.join(temp.path, 'worker-v1.zip'));
      await trustedArchive.writeAsBytes([1, 2, 3]);
      addTearDown(() async {
        await db.close();
        await temp.delete(recursive: true);
      });
      var configWrites = 0;
      final result = await UnifiedBackupService(
        database: db,
        paths: RestorePaths(
          profilesDirectory: p.join(temp.path, 'profiles'),
          scriptsDirectory: p.join(temp.path, 'scripts'),
          workerUnifiedArchivePath: p.join(temp.path, 'worker-v1.zip'),
        ),
        writeConfig: (_) async {
          configWrites++;
          return true;
        },
      ).restoreBytes(_clashVergeBackup(), override: true);

      final profiles = await db.profilesDao.query().get();
      expect(profiles.map((profile) => profile.label), ['Remote', 'Local']);
      expect(result.currentProfileId, profiles.first.id);
      expect(result.config, isNull);
      expect(configWrites, 0);
      expect(await trustedArchive.readAsBytes(), [1, 2, 3]);
    },
  );

  test('rejects missing referenced subscription YAML', () {
    expect(
      () => const ClashVergeBackupParser().parse(
        _clashVergeBackup(includeRemoteYaml: false),
      ),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.code,
          'code',
          BackupErrorCode.missingRequiredFile,
        ),
      ),
    );
  });
}

Uint8List _clashVergeBackup({bool includeRemoteYaml = true}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('config.yaml', 'mixed-port: 7890\n'))
    ..addFile(ArchiveFile.string('verge.yaml', 'language: zh\n'))
    ..addFile(
      ArchiveFile.string('profiles.yaml', '''
current: Rremote1
items:
  - uid: Rremote1
    type: remote
    name: Remote
    file: Rremote1.yaml
    url: https://airport.example/sub
    updated: 1700000000
    option:
      allow_auto_update: true
      update_interval: 120
    extra:
      upload: 1
      download: 2
      total: 3
      expire: 4
  - uid: mhelper
    type: merge
    file: mhelper.yaml
  - uid: Llocal1
    type: local
    name: Local
    file: Llocal1.yaml
'''),
    )
    ..addFile(ArchiveFile.string('profiles/Llocal1.yaml', 'proxies: []\n'))
    ..addFile(
      ArchiveFile.string('profiles/mhelper.yaml', 'prepend-rules: []\n'),
    );
  if (includeRemoteYaml) {
    archive.addFile(
      ArchiveFile.string(
        'profiles/Rremote1.yaml',
        'proxies:\n  - name: remote-node\n    type: direct\n',
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
