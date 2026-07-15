import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/backup/restore_service.dart';
import 'package:fl_clash/services/backup/unified_backup_service.dart';
import 'package:fl_clash/services/backup/worker_v1_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'traditional v2.0.1 database backup restores groups and settings',
    () async {
      final temp = await Directory.systemTemp.createTemp('unified-v201-test-');
      final oldDbFile = File(p.join(temp.path, 'old.sqlite'));
      final oldDb = Database(NativeDatabase(oldDbFile));
      final profile = Profile(
        id: 42,
        label: 'v2.0.1',
        autoUpdateDuration: const Duration(days: 1),
        overwriteType: OverwriteType.custom,
      );
      await oldDb.restore(
        [profile],
        const [],
        const [],
        const [],
        [
          const ProxyGroup(
            profileId: 42,
            id: 420,
            name: 'Legacy Group',
            type: GroupType.Selector,
            proxies: ['DIRECT'],
          ),
        ],
        isOverride: true,
      );
      await oldDb.close();

      final config = const Config(
        currentProfileId: 42,
        overrideDns: true,
        themeProps: defaultThemeProps,
      ).toJson()..['version'] = 3;
      final archive = Archive()
        ..addFile(
          ArchiveFile.bytes('database.sqlite', await oldDbFile.readAsBytes()),
        )
        ..addFile(ArchiveFile.string('config.json', jsonEncode(config)))
        ..addFile(ArchiveFile.string('profiles/42.yaml', 'proxies: []\n'));
      final targetDb = Database(NativeDatabase.memory());
      addTearDown(() async {
        await targetDb.close();
        await temp.delete(recursive: true);
      });

      final result =
          await UnifiedBackupService(
            database: targetDb,
            paths: RestorePaths(
              profilesDirectory: p.join(temp.path, 'restored-profiles'),
              scriptsDirectory: p.join(temp.path, 'restored-scripts'),
            ),
          ).restoreBytes(
            Uint8List.fromList(ZipEncoder().encode(archive)),
            override: true,
          );

      expect((await targetDb.profilesDao.query().get()).single.id, 42);
      expect(
        (await targetDb.proxyGroupsDao.query(42).get()).single.name,
        'Legacy Group',
      );
      expect(result.config?.overrideDns, true);
    },
  );

  test('Worker v1 archive writes profile and fixed URL end to end', () async {
    final temp = await Directory.systemTemp.createTemp('unified-worker-test-');
    final db = Database(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });

    final snapshotPath = p.join(temp.path, 'unified', 'worker-v1.zip');
    final archiveBytes = _workerArchive();
    final result = await UnifiedBackupService(
      database: db,
      paths: RestorePaths(
        profilesDirectory: p.join(temp.path, 'profiles'),
        scriptsDirectory: p.join(temp.path, 'scripts'),
        workerUnifiedArchivePath: snapshotPath,
      ),
    ).restoreBytes(archiveBytes, override: true);

    final profile = (await db.profilesDao.query().get()).single;
    expect(profile.url, 'https://vault.example/config/example/fixed-token');
    expect(result.currentProfileId, profile.id);
    expect(
      await File(
        p.join(temp.path, 'profiles', '${profile.id}.yaml'),
      ).readAsString(),
      'proxies: []\n',
    );
    expect(await File(snapshotPath).readAsBytes(), archiveBytes);
    expect(
      const WorkerV1Parser()
          .parse(await File(snapshotPath).readAsBytes())
          .manifest
          .airports
          .length,
      1,
    );
  });

  test('Slclash v2 backup preserves its embedded Worker snapshot', () async {
    final temp = await Directory.systemTemp.createTemp('unified-wrapper-test-');
    final db = Database(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });
    final worker = _workerArchive();
    final id = int.parse('1234abcd', radix: 16);
    final metadata = {
      'backupType': 'profiles_only_v2',
      'currentProfileId': id,
      'profiles': [
        {
          'id': id,
          'label': 'Example',
          'url': 'https://vault.example/config/example/fixed-token',
        },
      ],
      'scripts': <Object>[],
      'rules': <Object>[],
      'links': <Object>[],
      'proxyGroups': <Object>[],
    };
    final outer = Archive()
      ..addFile(ArchiveFile.string('metadata.json', jsonEncode(metadata)))
      ..addFile(ArchiveFile.string('profiles/$id.yaml', 'proxies: []\n'))
      ..addFile(ArchiveFile.bytes('subscription-center/worker-v1.zip', worker));
    final snapshot = p.join(temp.path, 'unified', 'worker-v1.zip');
    await UnifiedBackupService(
      database: db,
      paths: RestorePaths(
        profilesDirectory: p.join(temp.path, 'profiles'),
        scriptsDirectory: p.join(temp.path, 'scripts'),
        workerUnifiedArchivePath: snapshot,
      ),
    ).restoreBytes(
      Uint8List.fromList(ZipEncoder().encode(outer)),
      override: true,
    );
    expect(await File(snapshot).readAsBytes(), worker);
  });

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

Uint8List _workerArchive() {
  final profile = utf8.encode('proxies: []\n');
  final provider = utf8.encode('proxies: []\n');
  final files = <String, List<int>>{
    'config.yaml': utf8.encode('proxy-providers: {}\n'),
    'verge.yaml': utf8.encode('{}\n'),
    'profiles.yaml': utf8.encode('''
current: R1234abcd
items:
  - uid: R1234abcd
    type: remote
    name: Example
    file: R1234abcd.yaml
    url: https://vault.example/config/example/fixed-token
'''),
    'profiles/R1234abcd.yaml': profile,
    'providers/example/provider.yaml': provider,
    'providers/example/profile.yaml': profile,
    'providers/example/meta.json': utf8.encode('{}\n'),
  };
  final manifestFiles = <String, Object?>{
    for (final entry in files.entries)
      entry.key: {
        'sha256': sha256.convert(entry.value).toString(),
        'contentLength': entry.value.length,
        'required':
            entry.key == 'config.yaml' ||
            entry.key == 'verge.yaml' ||
            entry.key == 'profiles.yaml' ||
            entry.key.startsWith('profiles/'),
      },
  };
  final manifest = {
    'format': 'mihomo-unified-backup',
    'formatVersion': 1,
    'archiveType': 'unified-subscription-archive',
    'createdAt': '2026-07-15T00:00:00Z',
    'generator': 'worker',
    'generatorVersion': '1.0.0',
    'publicBaseUrl': 'https://vault.example',
    'mainConfig': {
      'configId': 'main',
      'versionId': 'v1',
      'name': 'Main',
      'sourceSha256': '1' * 64,
    },
    'airports': [
      {
        'slug': 'example',
        'subscriptionId': 'subscription',
        'name': 'Example',
        'profileUid': 'R1234abcd',
        'versionId': 'v1',
        'nodeCount': 0,
        'providerSha256': sha256.convert(provider).toString(),
        'profileSha256': sha256.convert(profile).toString(),
      },
    ],
    'files': manifestFiles,
  };
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
