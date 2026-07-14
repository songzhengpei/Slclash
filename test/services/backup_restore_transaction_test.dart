import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/restore_bridge.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/backup_restore/backup_restore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database transaction rolls back when file commit fails', () async {
    final database = Database(NativeDatabase.memory());
    addTearDown(database.close);
    addTearDown(clearPendingBackupRestoreCommit);

    final original = Profile(
      id: 1,
      label: 'original',
      autoUpdateDuration: const Duration(days: 1),
    );
    final replacement = Profile(
      id: 2,
      label: 'replacement',
      autoUpdateDuration: const Duration(days: 1),
    );
    await database.profilesDao.setAll([original]);

    final pending = _FailingPending({replacement.id});
    setPendingBackupRestoreCommit(pending);

    await expectLater(
      () => database.restoreProfilesOnly(
        [replacement],
        isOverride: true,
      ),
      throwsStateError,
    );

    final profiles = await database.profilesDao.query().get();
    expect(profiles.map((profile) => profile.id), [original.id]);
    expect(pending.rolledBack, isTrue);
    expect(pending.completed, isTrue);
  });

  test('file rollback restores profiles and Provider cache', () async {
    final root = await Directory.systemTemp.createTemp(
      'slclash-restore-transaction-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final profiles = Directory('${root.path}/profiles')
      ..createSync(recursive: true);
    final scripts = Directory('${root.path}/scripts')
      ..createSync(recursive: true);
    final providers = Directory('${profiles.path}/providers')
      ..createSync(recursive: true);
    final staging = Directory('${root.path}/staging')
      ..createSync(recursive: true);
    final rollback = Directory('${root.path}/rollback');
    final source = File('${staging.path}/new.yaml')
      ..writeAsStringSync('new-profile');
    final target = File('${profiles.path}/10.yaml')
      ..writeAsStringSync('old-profile');
    final oldCache = File('${providers.path}/10/proxies/cache')
      ..createSync(recursive: true)
      ..writeAsStringSync('old-cache');

    final model = UnifiedRestoreModel(
      format: BackupArchiveFormat.workerUnifiedV1,
      profiles: [
        Profile(
          id: 10,
          label: 'worker',
          url: 'https://example.invalid',
          autoUpdateDuration: const Duration(days: 1),
        ),
      ],
      profileFiles: [
        RestoreSourceFile(
          source: source,
          relativeTarget: '10.yaml',
        ),
      ],
      invalidateProviderCaches: true,
      stagingDirectory: staging,
    );
    final committer = RestoreFileCommitter(
      profilesDirectory: profiles,
      scriptsDirectory: scripts,
      providersDirectory: providers,
      rollbackDirectory: rollback,
    );

    await committer.apply(model, replaceExisting: false);
    expect(await target.readAsString(), 'new-profile');
    expect(await oldCache.exists(), isFalse);

    await committer.rollback();
    expect(await target.readAsString(), 'old-profile');
    expect(await oldCache.readAsString(), 'old-cache');
    await committer.complete();
  });
}

class _FailingPending implements PendingBackupRestoreCommit {
  _FailingPending(this.restoredProfileIds);

  @override
  final Set<int> restoredProfileIds;

  bool rolledBack = false;
  bool completed = false;

  @override
  bool get invalidateProviderCaches => true;

  @override
  List<ProxyGroup> get proxyGroups => const [];

  @override
  Future<void> commitFiles({required bool isOverride}) async {
    throw StateError('simulated file commit failure');
  }

  @override
  Future<void> rollbackFiles() async {
    rolledBack = true;
  }

  @override
  Future<void> complete() async {
    completed = true;
  }
}
