import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
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

  test('override preserves scripts rules links and proxy groups', () async {
    final bytes = _clashVergeBackup();
    final imported = const ClashVergeBackupParser().parse(bytes);
    final temp = await Directory.systemTemp.createTemp('clash-verge-scope-');
    final db = Database(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });
    final script = Script(
      id: 9,
      label: 'keep-script',
      lastUpdateTime: DateTime.utc(2026),
    );
    const rule = Rule(
      id: 10,
      ruleAction: RuleAction.DOMAIN,
      content: 'example.com',
      ruleTarget: 'DIRECT',
    );
    await db.restore(
      [imported.profiles.first.copyWith(scriptId: script.id)],
      [script],
      [rule],
      [const ProfileRuleLink(ruleId: 10, scene: RuleScene.added, order: 'a')],
      [
        const ProxyGroup(
          id: 11,
          name: 'Keep Group',
          type: GroupType.Selector,
          proxies: ['DIRECT'],
        ),
      ],
      isOverride: true,
    );
    final scriptFile = File(p.join(temp.path, 'scripts', '9.js'));
    await scriptFile.parent.create(recursive: true);
    await scriptFile.writeAsString('keep');

    await UnifiedBackupService(
      database: db,
      paths: RestorePaths(
        profilesDirectory: p.join(temp.path, 'profiles'),
        scriptsDirectory: p.join(temp.path, 'scripts'),
      ),
    ).restoreBytes(bytes, override: true);

    expect((await db.scriptsDao.query().get()).single.label, 'keep-script');
    expect((await db.rulesDao.queryAllRules()).single.id, 10);
    expect((await db.rulesDao.queryAllLinks()).single.ruleId, 10);
    expect(
      (await db.proxyGroupsDao.queryAll().get()).single.name,
      'Keep Group',
    );
    expect(await scriptFile.readAsString(), 'keep');
  });

  test('same Verge UID does not duplicate profile when YAML changes', () async {
    final temp = await Directory.systemTemp.createTemp('clash-verge-update-');
    final db = Database(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });
    final service = UnifiedBackupService(
      database: db,
      paths: RestorePaths(
        profilesDirectory: p.join(temp.path, 'profiles'),
        scriptsDirectory: p.join(temp.path, 'scripts'),
      ),
    );
    await service.restoreBytes(
      _clashVergeBackup(remoteYaml: 'proxies: []\n'),
      override: false,
    );
    final first = (await db.profilesDao.query().get()).first;
    await service.restoreBytes(
      _clashVergeBackup(
        remoteYaml: 'proxies:\n  - name: updated\n    type: direct\n',
      ),
      override: false,
    );

    final profiles = await db.profilesDao.query().get();
    expect(profiles, hasLength(2));
    final updated = profiles.singleWhere(
      (profile) => profile.label == 'Remote',
    );
    expect(updated.id, first.id);
    expect(
      await File(
        p.join(temp.path, 'profiles', '${first.id}.yaml'),
      ).readAsString(),
      contains('updated'),
    );
  });

  test('compatible import appends new profiles after existing order', () async {
    final temp = await Directory.systemTemp.createTemp('clash-verge-order-');
    final db = Database(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });
    const existing = Profile(
      id: 42,
      label: 'Existing',
      autoUpdateDuration: Duration(days: 1),
      order: 7,
    );
    await db.restoreProfilesOnly([existing]);
    await UnifiedBackupService(
      database: db,
      paths: RestorePaths(
        profilesDirectory: p.join(temp.path, 'profiles'),
        scriptsDirectory: p.join(temp.path, 'scripts'),
      ),
    ).restoreBytes(_clashVergeBackup(), override: false);
    final profiles = await db.profilesDao.query().get();
    expect(profiles.map((profile) => profile.label), [
      'Existing',
      'Remote',
      'Local',
    ]);
    expect(profiles.map((profile) => profile.order), [7, 8, 9]);
  });

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

  test('rejects malformed remote identity fields and update policy', () {
    for (final item in [
      '''
  - uid: Rremote1
    type: remote
    name: Missing URL
    file: Rremote1.yaml
''',
      '''
  - uid: Rremote1
    type: remote
    name: Wrong File
    file: other.yaml
    url: https://example.test/sub
''',
      '''
  - uid: Rremote1
    type: remote
    name: Bad Interval
    file: Rremote1.yaml
    url: https://example.test/sub
    option:
      update_interval: 0
''',
    ]) {
      expect(
        () => const ClashVergeBackupParser().parse(
          _clashVergeBackup(profilesYaml: 'current: Rremote1\nitems:\n$item'),
        ),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.code,
            'code',
            BackupErrorCode.invalidProfiles,
          ),
        ),
      );
    }
  });

  test('rejects duplicate subscription UID and file', () {
    expect(
      () => const ClashVergeBackupParser().parse(
        _clashVergeBackup(
          profilesYaml: '''
current: Rremote1
items:
  - uid: Rremote1
    type: remote
    name: First
    file: Rremote1.yaml
    url: https://example.test/one
  - uid: Rremote1
    type: remote
    name: Second
    file: Rremote1.yaml
    url: https://example.test/two
''',
        ),
      ),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.code,
          'code',
          BackupErrorCode.invalidProfiles,
        ),
      ),
    );
  });
}

Uint8List _clashVergeBackup({
  bool includeRemoteYaml = true,
  String? remoteYaml,
  String? profilesYaml,
}) {
  final profilesContent =
      profilesYaml ??
      '''
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
''';
  final archive = Archive()
    ..addFile(ArchiveFile.string('config.yaml', 'mixed-port: 7890\n'))
    ..addFile(ArchiveFile.string('verge.yaml', 'language: zh\n'))
    ..addFile(ArchiveFile.string('profiles.yaml', profilesContent))
    ..addFile(ArchiveFile.string('profiles/Llocal1.yaml', 'proxies: []\n'))
    ..addFile(
      ArchiveFile.string('profiles/mhelper.yaml', 'prepend-rules: []\n'),
    );
  if (includeRemoteYaml) {
    archive.addFile(
      ArchiveFile.string(
        'profiles/Rremote1.yaml',
        remoteYaml ?? 'proxies:\n  - name: remote-node\n    type: direct\n',
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
