part of 'database.dart';

@DataClassName('RawProxyGroupsSnapshot')
class ProxyGroupsSnapshots extends Table {
  @override
  String get tableName => 'proxy_groups_snapshots';

  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get groups => text().map(const GroupsConverter())();

  TextColumn get profileFingerprint => text().nullable()();

  IntColumn get snapshotVersion =>
      integer().withDefault(const Constant(kProxyGroupsSnapshotVersion))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId};
}

@DriftAccessor(tables: [ProxyGroupsSnapshots])
class ProxyGroupsSnapshotsDao extends DatabaseAccessor<Database>
    with _$ProxyGroupsSnapshotsDaoMixin {
  ProxyGroupsSnapshotsDao(super.attachedDatabase);

  Future<RawProxyGroupsSnapshot?> getSnapshot(int profileId) {
    return (select(
      proxyGroupsSnapshots,
    )..where((t) => t.profileId.equals(profileId))).getSingleOrNull();
  }

  Future<void> putSnapshot({
    required int profileId,
    required List<Group> groups,
    String? profileFingerprint,
  }) {
    return into(proxyGroupsSnapshots).insertOnConflictUpdate(
      ProxyGroupsSnapshotsCompanion.insert(
        profileId: Value(profileId),
        groups: groups,
        profileFingerprint: Value(profileFingerprint),
        snapshotVersion: const Value(kProxyGroupsSnapshotVersion),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteSnapshot(int profileId) {
    return (delete(
      proxyGroupsSnapshots,
    )..where((t) => t.profileId.equals(profileId))).go();
  }

  Future<void> deleteSnapshots(Iterable<int> profileIds) async {
    final ids = profileIds.toSet();
    if (ids.isEmpty) return;
    await (delete(
      proxyGroupsSnapshots,
    )..where((t) => t.profileId.isIn(ids))).go();
  }

  Future<void> deleteAllSnapshots() => delete(proxyGroupsSnapshots).go();
}
