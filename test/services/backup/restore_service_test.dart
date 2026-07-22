import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/backup/restore_bundle.dart';
import 'package:fl_clash/services/backup/restore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Database db;
  late RestorePaths paths;

  Profile profile(int id, {int? scriptId}) => Profile(
    id: id,
    label: 'profile-$id',
    autoUpdateDuration: const Duration(hours: 24),
    scriptId: scriptId,
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('restore-service-test-');
    db = Database(NativeDatabase.memory());
    paths = RestorePaths(
      profilesDirectory: p.join(temp.path, 'profiles'),
      scriptsDirectory: p.join(temp.path, 'scripts'),
    );
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('rejects missing profile yaml before changing the database', () async {
    final service = RestoreService(database: db, paths: paths);

    await expectLater(
      service.restore(
        RestoreBundle(
          sourceFormat: BackupSourceFormat.workerUnifiedV1,
          profiles: [profile(1)],
        ),
      ),
      throwsA(isA<RestoreValidationException>()),
    );
    expect(await db.profilesDao.query().get(), isEmpty);
  });

  test('rejects script metadata without a non-empty JavaScript file', () async {
    final script = Script(
      id: 9,
      label: 'missing',
      lastUpdateTime: DateTime.utc(2026),
    );
    await expectLater(
      RestoreService(database: db, paths: paths).restore(
        RestoreBundle(
          sourceFormat: BackupSourceFormat.slclashProfilesV2,
          profiles: [profile(1, scriptId: 9)],
          scripts: [script],
          files: [
            StagedRestoreFile(
              relativePath: 'profiles/1.yaml',
              bytes: Uint8List.fromList('proxies: []'.codeUnits),
            ),
          ],
        ),
      ),
      throwsA(isA<RestoreValidationException>()),
    );
    expect(await db.profilesDao.query().get(), isEmpty);
  });

  test('commits profile and invalidates its provider cache', () async {
    final provider = File(p.join(paths.providersDirectory, '1', 'cache.yaml'));
    await provider.parent.create(recursive: true);
    await provider.writeAsString('stale');
    final stages = <String>[];
    final service = RestoreService(
      database: db,
      paths: paths,
      onProgress: (stage, profileCount) {
        stages.add('$stage:$profileCount');
      },
    );

    final result = await service.restore(
      RestoreBundle(
        sourceFormat: BackupSourceFormat.workerUnifiedV1,
        profiles: [profile(1)],
        currentProfileId: 1,
        providerCachePolicy: ProviderCachePolicy.invalidateRestoredProfiles,
        files: [
          StagedRestoreFile(
            relativePath: 'profiles/1.yaml',
            bytes: Uint8List.fromList('proxies: []'.codeUnits),
          ),
        ],
      ),
    );

    expect(result.currentProfileId, 1);
    expect((await db.profilesDao.query().get()).single.id, 1);
    expect(
      await File(p.join(paths.profilesDirectory, '1.yaml')).readAsString(),
      'proxies: []',
    );
    expect(await provider.parent.exists(), false);
    expect(stages, [
      'validated:1',
      'database-restored:1',
      'files-committed:1',
      'archive-committed:1',
      'committed:1',
    ]);
  });

  test('override invalidates snapshots and orphan provider caches', () async {
    final old = profile(9);
    await db.restore([old], [], [], [], [], isOverride: true);
    await db.customStatement(
      'INSERT INTO proxy_groups_snapshots '
      '(profile_id, groups, snapshot_version, updated_at) VALUES (?, ?, ?, ?)',
      [9, '[]', 1, DateTime.now().millisecondsSinceEpoch],
    );
    final orphan = File(p.join(paths.providersDirectory, '9', 'stale.yaml'));
    await orphan.parent.create(recursive: true);
    await orphan.writeAsString('stale');

    await RestoreService(database: db, paths: paths).restore(
      RestoreBundle(
        sourceFormat: BackupSourceFormat.workerUnifiedV1,
        profiles: [profile(1)],
        files: [
          StagedRestoreFile(
            relativePath: 'profiles/1.yaml',
            bytes: Uint8List.fromList('proxies: []'.codeUnits),
          ),
        ],
        providerCachePolicy: ProviderCachePolicy.invalidateRestoredProfiles,
      ),
    );

    expect(await db.proxyGroupsSnapshotsDao.getSnapshot(9), isNull);
    expect(await orphan.parent.exists(), false);
  });

  test('filesystem failure rolls back database and replaced files', () async {
    final old = profile(1);
    await db.restore([old], [], [], [], [], isOverride: true);
    final oldFile = File(p.join(paths.profilesDirectory, '1.yaml'));
    await oldFile.parent.create(recursive: true);
    await oldFile.writeAsString('old');
    // A regular file where the scripts directory must be forces failure after
    // the profile file has already been switched.
    await File(paths.scriptsDirectory).writeAsString('blocker');
    final script = Script(
      id: 9,
      label: 'script',
      lastUpdateTime: DateTime.utc(2026),
    );
    final service = RestoreService(database: db, paths: paths);

    await expectLater(
      service.restore(
        RestoreBundle(
          sourceFormat: BackupSourceFormat.slclashProfilesV2,
          profiles: [profile(2, scriptId: 9)],
          scripts: [script],
          files: [
            StagedRestoreFile(
              relativePath: 'profiles/2.yaml',
              bytes: Uint8List.fromList('proxies: []'.codeUnits),
            ),
            StagedRestoreFile(
              relativePath: 'scripts/9.js',
              bytes: Uint8List.fromList('return {};'.codeUnits),
            ),
          ],
        ),
      ),
      throwsA(anything),
    );

    expect((await db.profilesDao.query().get()).single.id, 1);
    expect(await oldFile.readAsString(), 'old');
    expect(
      await File(p.join(paths.profilesDirectory, '2.yaml')).exists(),
      false,
    );
  });

  test('settings persistence failure rolls back database and files', () async {
    final old = profile(1);
    await db.restore([old], [], [], [], [], isOverride: true);
    final oldFile = File(p.join(paths.profilesDirectory, '1.yaml'));
    await oldFile.parent.create(recursive: true);
    await oldFile.writeAsString('old');
    var storedConfig = const Config(
      themeProps: defaultThemeProps,
      overrideDns: false,
    );
    var firstWrite = true;
    final service = RestoreService(
      database: db,
      paths: paths,
      readConfig: () async => storedConfig,
      writeConfig: (config) async {
        storedConfig = config;
        if (firstWrite) {
          firstWrite = false;
          return false;
        }
        return true;
      },
    );

    await expectLater(
      service.restore(
        RestoreBundle(
          sourceFormat: BackupSourceFormat.slclashProfilesV2,
          profiles: [profile(2)],
          config: const Config(
            themeProps: defaultThemeProps,
            overrideDns: true,
          ),
          files: [
            StagedRestoreFile(
              relativePath: 'profiles/2.yaml',
              bytes: Uint8List.fromList('proxies: []'.codeUnits),
            ),
          ],
        ),
      ),
      throwsA(isA<RestoreValidationException>()),
    );

    expect((await db.profilesDao.query().get()).single.id, 1);
    expect(await oldFile.readAsString(), 'old');
    expect(storedConfig.overrideDns, false);
  });

  test(
    'restore failure preserves the previous Worker archive snapshot',
    () async {
      final archivePath = p.join(temp.path, 'unified', 'worker-v1.zip');
      final oldArchive = File(archivePath);
      await oldArchive.parent.create(recursive: true);
      await oldArchive.writeAsString('old-archive');
      final service = RestoreService(
        database: db,
        paths: RestorePaths(
          profilesDirectory: paths.profilesDirectory,
          scriptsDirectory: paths.scriptsDirectory,
          workerUnifiedArchivePath: archivePath,
        ),
        readConfig: () async => const Config(themeProps: defaultThemeProps),
        writeConfig: (_) async => false,
      );

      await expectLater(
        service.restore(
          RestoreBundle(
            sourceFormat: BackupSourceFormat.workerUnifiedV1,
            profiles: [profile(1)],
            config: const Config(themeProps: defaultThemeProps),
            workerUnifiedArchive: Uint8List.fromList('new-archive'.codeUnits),
            replaceWorkerUnifiedArchive: true,
            files: [
              StagedRestoreFile(
                relativePath: 'profiles/1.yaml',
                bytes: Uint8List.fromList('proxies: []'.codeUnits),
              ),
            ],
          ),
        ),
        throwsA(isA<RestoreValidationException>()),
      );

      expect(await oldArchive.readAsString(), 'old-archive');
      expect(await db.profilesDao.query().get(), isEmpty);
    },
  );

  test('restore without a Worker snapshot clears the stale snapshot', () async {
    final archivePath = p.join(temp.path, 'unified', 'worker-v1.zip');
    final oldArchive = File(archivePath);
    await oldArchive.parent.create(recursive: true);
    await oldArchive.writeAsString('stale-archive');

    await RestoreService(
      database: db,
      paths: RestorePaths(
        profilesDirectory: paths.profilesDirectory,
        scriptsDirectory: paths.scriptsDirectory,
        workerUnifiedArchivePath: archivePath,
      ),
    ).restore(
      RestoreBundle(
        sourceFormat: BackupSourceFormat.slclashProfilesV2,
        profiles: [profile(1)],
        replaceWorkerUnifiedArchive: true,
        files: [
          StagedRestoreFile(
            relativePath: 'profiles/1.yaml',
            bytes: Uint8List.fromList('proxies: []'.codeUnits),
          ),
        ],
      ),
    );

    expect(await oldArchive.exists(), false);
  });

  test('restored settings retain current device WebDAV credentials', () async {
    const localDav = DAVProps(
      uri: 'https://local.example/dav',
      user: 'local-user',
      password: 'local-secret',
    );
    Config? storedConfig = const Config(
      themeProps: defaultThemeProps,
      davProps: localDav,
    );
    final result =
        await RestoreService(
          database: db,
          paths: paths,
          readConfig: () async => storedConfig,
          writeConfig: (config) async {
            storedConfig = config;
            return true;
          },
        ).restore(
          RestoreBundle(
            sourceFormat: BackupSourceFormat.slclashProfilesV2,
            profiles: [profile(1)],
            config: const Config(
              themeProps: defaultThemeProps,
              overrideDns: true,
              davProps: DAVProps(
                uri: 'https://backup.example/dav',
                user: 'backup-user',
                password: 'backup-secret',
              ),
            ),
            files: [
              StagedRestoreFile(
                relativePath: 'profiles/1.yaml',
                bytes: Uint8List.fromList('proxies: []'.codeUnits),
              ),
            ],
          ),
        );

    expect(result.config?.davProps, localDav);
    expect(storedConfig?.davProps, localDav);
    expect(storedConfig?.overrideDns, true);
  });
}
