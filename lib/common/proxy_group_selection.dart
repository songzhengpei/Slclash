import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

enum ProxyGroupTapKind { ignore, select, unfix }

class ProxyGroupTapDecision {
  const ProxyGroupTapDecision({
    required this.kind,
    this.proxyName = '',
  });

  final ProxyGroupTapKind kind;
  final String proxyName;
}

/// Pure Mihomo tap mapping. Unfix only when Core [fixed] equals the tap.
ProxyGroupTapDecision resolveProxyGroupTap({
  required GroupType type,
  required String? fixed,
  required String tappedName,
}) {
  if (!type.supportsManualSelection) {
    return const ProxyGroupTapDecision(kind: ProxyGroupTapKind.ignore);
  }
  if (type.supportsFixedSelection) {
    if (fixed != null && fixed.isNotEmpty && fixed == tappedName) {
      return const ProxyGroupTapDecision(kind: ProxyGroupTapKind.unfix);
    }
    return ProxyGroupTapDecision(
      kind: ProxyGroupTapKind.select,
      proxyName: tappedName,
    );
  }
  return ProxyGroupTapDecision(
    kind: ProxyGroupTapKind.select,
    proxyName: tappedName,
  );
}

bool isCoreSelectionSuccess(String result) => result.isEmpty;

bool shouldRollbackOptimisticIntent({
  required String? currentIntent,
  required String failedIntent,
}) {
  return currentIntent == failedIntent;
}

bool groupShowsFixedMark({
  required GroupType type,
  required String? fixed,
  required String proxyName,
}) {
  return type.supportsFixedSelection &&
      fixed != null &&
      fixed.isNotEmpty &&
      fixed == proxyName;
}

String? selectedNameForGroup(Group group, {required String? selectedMapValue, String? cachedComputedNow}) {
  if (group.type == GroupType.LoadBalance) {
    return group.realNow.isEmpty ? null : group.realNow;
  }
  return group.getCurrentSelectedName(
    selectedMapValue ?? '',
    cachedComputedNow: cachedComputedNow,
  );
}

/// Per-group optimistic selection baseline for one debounce burst.
///
/// First tap records the committed [selectedMap] value. Later taps in the
/// same burst keep that baseline so A→B→C failure restores A, not B.
class ProxySelectionSession {
  final Map<Object, String?> _baseline = {};

  void captureBaseline(Object selectionKey, String? committed) {
    _baseline.putIfAbsent(selectionKey, () => committed);
  }

  String? peek(Object selectionKey) => _baseline[selectionKey];

  void complete(Object selectionKey) {
    _baseline.remove(selectionKey);
  }

  /// After a successful Core write. If the UI already moved on, keep the
  /// session and advance the rollback target to [committedValue].
  void commitWithNewerIntent({
    required Object groupName,
    required String committedValue,
    required String? currentIntent,
  }) {
    if (currentIntent == committedValue) {
      complete(groupName);
      return;
    }
    _baseline[groupName] = committedValue;
  }

  /// Drop baseline only when this request still owns the optimistic intent.
  void completeUnlessNewerIntent({
    required Object groupName,
    required bool newerIntentPending,
  }) {
    if (!newerIntentPending) {
      complete(groupName);
    }
  }
}

bool groupsListsEqual(List<Group> a, List<Group> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final ga = a[i];
    final gb = b[i];
    if (ga.name != gb.name ||
        ga.type != gb.type ||
        ga.now != gb.now ||
        ga.fixed != gb.fixed ||
        ga.hidden != gb.hidden ||
        ga.testUrl != gb.testUrl ||
        ga.icon != gb.icon ||
        ga.all.length != gb.all.length) {
      return false;
    }
    for (var j = 0; j < ga.all.length; j++) {
      if (ga.all[j].name != gb.all[j].name ||
          ga.all[j].type != gb.all[j].type) {
        return false;
      }
    }
  }
  return true;
}

Object proxySelectionDebounceTag(String groupName, [Object? runtimeScope]) =>
    (FunctionTag.changeProxy, runtimeScope, groupName);
