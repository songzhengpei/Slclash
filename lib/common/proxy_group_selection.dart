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
