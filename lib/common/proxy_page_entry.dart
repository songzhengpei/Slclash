/// Pure first-entry plan for Proxy page. Product [ProxiesView] uses this
/// only to decide ensureReady; it does not change Core or selection.
class ProxyPageEntryPlan {
  const ProxyPageEntryPlan({
    required this.ownerProfileId,
    required this.currentProfileId,
    required this.groupsIsEmpty,
    required this.expired,
    required this.snapshotHydrated,
  });

  final int? ownerProfileId;
  final int? currentProfileId;
  final bool groupsIsEmpty;
  final bool expired;
  final bool snapshotHydrated;

  bool get ownerMismatch => ownerProfileId != currentProfileId;

  /// Same predicate as historical ProxiesView.initState `groupsEmpty`.
  bool get treatAsEmpty => ownerMismatch || groupsIsEmpty;

  bool get ensureReady => treatAsEmpty || expired;

  bool get forceApply => treatAsEmpty;

  /// Diagnostic id for 4C.1B P-matrix. Not a user-visible state.
  String get scenarioId {
    if (ownerMismatch) {
      return 'P8_owner_mismatch';
    }
    if (groupsIsEmpty && !snapshotHydrated) {
      return 'P3_no_snapshot';
    }
    if (snapshotHydrated && expired) {
      return 'P2_stale_snapshot';
    }
    if (!groupsIsEmpty && !expired) {
      return 'P1_fresh_or_warm';
    }
    if (groupsIsEmpty && snapshotHydrated) {
      return 'P2_stale_after_hydrate';
    }
    return 'P_other';
  }
}
