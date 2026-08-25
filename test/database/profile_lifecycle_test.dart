import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Database db;

  setUp(() {
    db = Database(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Profile profile(int id) => Profile(
    id: id,
    label: 'profile-$id',
    url: 'https://example.com/$id',
    autoUpdateDuration: const Duration(hours: 1),
  );

  test('authoritative delete removes all profile-owned DB rows', () async {
    const profileId = 1;
    const ruleId = 11;
    await db.profiles.put(profile(profileId).toCompanion());
    await db.rules.put(
      const Rule(
        id: ruleId,
        ruleAction: RuleAction.DOMAIN,
        content: 'example.com',
        ruleTarget: 'DIRECT',
      ).toCompanion(),
    );
    await db.profileRuleLinks.put(
      const ProfileRuleLink(
        profileId: profileId,
        ruleId: ruleId,
        scene: RuleScene.custom,
      ).toCompanion(),
    );
    await db.proxyGroups.put(
      const ProxyGroup(
        profileId: profileId,
        id: 21,
        name: 'custom',
        type: GroupType.Selector,
      ).toCompanion(),
    );
    await db.proxyGroupsSnapshotsDao.putSnapshot(
      profileId: profileId,
      groups: const [],
      profileFingerprint: 'old',
    );

    await db.deleteProfileLifetime(profileId);

    expect(await db.profilesDao.query().get(), isEmpty);
    expect(await db.rulesDao.queryAllLinks(), isEmpty);
    expect(await db.proxyGroupsDao.query(profileId).get(), isEmpty);
    expect(await db.proxyGroupsSnapshotsDao.getSnapshot(profileId), isNull);
    // Rules can be shared/global; only the owned link is deleted.
    expect((await db.rulesDao.queryAllRules()).single.id, ruleId);
  });

  test('late snapshot write cannot recreate state after delete', () async {
    const profileId = 2;
    await db.profiles.put(profile(profileId).toCompanion());
    expect(
      await db.putProfileSnapshotIfExists(
        profileId: profileId,
        groups: const [],
        profileFingerprint: 'before-delete',
      ),
      isTrue,
    );

    await db.deleteProfileLifetime(profileId);

    expect(
      await db.putProfileSnapshotIfExists(
        profileId: profileId,
        groups: const [],
        profileFingerprint: 'late-prefetch',
      ),
      isFalse,
    );
    expect(await db.proxyGroupsSnapshotsDao.getSnapshot(profileId), isNull);
  });

  test(
    'delete transaction rolls relations back when profile delete fails',
    () async {
      const profileId = 3;
      const ruleId = 31;
      await db.profiles.put(profile(profileId).toCompanion());
      await db.rules.put(
        const Rule(
          id: ruleId,
          ruleAction: RuleAction.DOMAIN,
          content: 'rollback.example',
          ruleTarget: 'DIRECT',
        ).toCompanion(),
      );
      await db.profileRuleLinks.put(
        const ProfileRuleLink(
          profileId: profileId,
          ruleId: ruleId,
          scene: RuleScene.custom,
        ).toCompanion(),
      );
      await db.proxyGroups.put(
        const ProxyGroup(
          profileId: profileId,
          id: 32,
          name: 'rollback',
          type: GroupType.Selector,
        ).toCompanion(),
      );
      await db.proxyGroupsSnapshotsDao.putSnapshot(
        profileId: profileId,
        groups: const [],
        profileFingerprint: 'rollback',
      );
      await db.customStatement(
        'CREATE TRIGGER fail_profile_delete '
        'BEFORE DELETE ON profiles '
        "BEGIN SELECT RAISE(ABORT, 'forced delete failure'); END",
      );

      await expectLater(db.deleteProfileLifetime(profileId), throwsA(anything));

      expect((await db.profilesDao.query().get()).single.id, profileId);
      expect(await db.rulesDao.queryAllLinks(), hasLength(1));
      expect(await db.proxyGroupsDao.query(profileId).get(), hasLength(1));
      expect(
        await db.proxyGroupsSnapshotsDao.getSnapshot(profileId),
        isNotNull,
      );
    },
  );
}
