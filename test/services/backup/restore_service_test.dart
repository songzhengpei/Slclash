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

  test('commits profile and invalidates its provider cache', () async {
    final provider = File(p.join(paths.providersDirectory, '1', 'cache.yaml'));
    await provider.parent.create(recursive: true);
    await provider.writeAsString('stale');
    final service = RestoreService(database: db, paths: paths);

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
}
