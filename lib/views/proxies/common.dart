import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProxyListRowPosition { single, first, middle, last }

double getProxyTileHeight() {
  final measure = globalState.measure;
  return 26 + measure.bodyMediumHeight + measure.bodySmallHeight + 3;
}

double get listHeaderHeight {
  final measure = globalState.measure;
  return 34 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight + 2;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      20 + measure.bodyMediumHeight + measure.bodySmallHeight + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + measure.labelSmallHeight + 8,
    ProxyCardType.shrink => baseHeight + 4,
    ProxyCardType.min => baseHeight,
  };
}

List<Group> getCurrentGroups() {
  return globalState.container.read(currentGroupsStateProvider).value;
}

List<Group> getGroups() {
  return globalState.container.read(groupsProvider);
}

String? getCurrentGroupName() {
  return globalState.container.read(
    currentProfileProvider.select((state) => state?.currentGroupName),
  );
}

void updateCurrentGroupName(String groupName) {
  globalState.container
      .read(proxiesActionProvider.notifier)
      .updateCurrentGroupName(groupName);
}

void updateCurrentUnfoldSet(Set<String> value) {
  globalState.container
      .read(proxiesActionProvider.notifier)
      .updateCurrentUnfoldSet(value);
}

/// Shared Proxy + Dashboard tap path. Returns false when the group is not selectable.
bool applyProxyGroupMemberTap({
  required Group group,
  required String tappedName,
}) {
  final decision = resolveProxyGroupTap(
    type: group.type,
    fixed: group.fixed,
    tappedName: tappedName,
  );
  if (decision.kind == ProxyGroupTapKind.ignore) {
    globalState.showNotifier(currentAppLocalizations.notSelectedTip);
    return false;
  }
  final container = globalState.container;
  final proxiesAction = container.read(proxiesActionProvider.notifier);
  final identity = proxiesAction.captureRuntimeProfileIdentity();
  if (identity == null) return false;
  proxiesAction.captureSelectionBaseline(identity, group.name);
  if (decision.kind == ProxyGroupTapKind.unfix) {
    final gen = ProxyTrace.noteSelectIntent(
      group: group.name,
      proxy: '',
      action: 'unfix',
    );
    container
        .read(profilesActionProvider.notifier)
        .updateSelectedMapEntryForProfile(identity.profileId, group.name, '');
    ProxyTrace.noteSelectVisual(gen: gen, group: group.name, proxy: '');
    proxiesAction.unfixProxyDebounce(identity, group.name, gen: gen);
    return true;
  }
  final gen = ProxyTrace.noteSelectIntent(
    group: group.name,
    proxy: decision.proxyName,
    action: 'select',
  );
  container
      .read(profilesActionProvider.notifier)
      .updateSelectedMapEntryForProfile(
        identity.profileId,
        group.name,
        decision.proxyName,
      );
  ProxyTrace.noteSelectVisual(
    gen: gen,
    group: group.name,
    proxy: decision.proxyName,
  );
  proxiesAction.changeProxyDebounce(
    identity,
    group.name,
    decision.proxyName,
    gen: gen,
  );
  return true;
}

Future<void> proxyDelayTest(
  Proxy proxy, [
  String? testUrl,
  RuntimeProfileIdentity? runtimeIdentity,
]) async {
  final ref = globalState.container;
  final proxiesAction = ref.read(proxiesActionProvider.notifier);
  final identity =
      runtimeIdentity ?? proxiesAction.captureRuntimeProfileIdentity();
  if (identity == null || !proxiesAction.isRuntimeIdentityActive(identity)) {
    return;
  }
  final groups = getGroups();
  final selectedMap = ref.read(
    currentProfileProvider.select((state) => state?.selectedMap ?? {}),
  );
  final computedSelectedMap = ref.read(
    currentProfileProvider.select((state) => state?.computedSelectedMap ?? {}),
  );
  final state = computeRealSelectedProxyState(
    proxy.name,
    groups: groups,
    selectedMap: selectedMap,
    computedSelectedMap: computedSelectedMap,
  );
  final currentTestUrl = state.testUrl.takeFirstValid([
    ref.read(realTestUrlProvider(testUrl)),
  ]);
  if (state.proxyName.isEmpty) {
    return;
  }
  ProxyTrace.delayStart(name: state.proxyName);
  proxiesAction.setDelayForRuntimeIdentity(
    identity,
    Delay(url: currentTestUrl, name: state.proxyName, value: 0),
  );
  try {
    final delay = await coreController.getDelay(
      currentTestUrl,
      state.proxyName,
    );
    if (!proxiesAction.setDelayForRuntimeIdentity(identity, delay)) return;
    ProxyTrace.delayFinish(name: state.proxyName, ok: true);
  } catch (e) {
    commonPrint.log('proxyDelayTest failed for ${state.proxyName}: $e');
    if (!proxiesAction.setDelayForRuntimeIdentity(
      identity,
      Delay(url: currentTestUrl, name: state.proxyName, value: -1),
    )) {
      return;
    }
    ProxyTrace.delayFinish(name: state.proxyName, ok: false);
  }
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final proxiesAction = globalState.container.read(
    proxiesActionProvider.notifier,
  );
  final identity = proxiesAction.captureRuntimeProfileIdentity();
  if (identity == null) return;
  StartupTrace.mark(
    'delay_test_begin',
    extras: {'count': proxies.length, ...CoreIpcTrace.identityExtras()},
  );
  final delayProxies = proxies.map<Future>((proxy) async {
    await proxyDelayTest(proxy, testUrl, identity);
  }).toList();

  StartupTrace.mark(
    'delay_test_after_map',
    extras: {
      'count': proxies.length,
      'peak_inflight': ProxyTrace.peakInflight,
      'started': ProxyTrace.delayStarted,
      ...CoreIpcTrace.identityExtras(),
    },
  );

  final batchesDelayProxies = delayProxies.batch(100);
  for (final batchDelayProxies in batchesDelayProxies) {
    await Future.wait(batchDelayProxies);
  }
  StartupTrace.mark(
    'delay_test_end',
    extras: {
      'peak_inflight': ProxyTrace.peakInflight,
      'started': ProxyTrace.delayStarted,
      'finished': ProxyTrace.delayFinished,
      'failed': ProxyTrace.delayFailed,
      ...CoreIpcTrace.identityExtras(),
    },
  );
  globalState.container.read(sortNumProvider.notifier).add();
}

double getScrollToSelectedOffset({
  required String groupName,
  required List<Proxy> proxies,
}) {
  final ref = globalState.container;
  final selectedProxyName = ref.read(selectedProxyNameProvider(groupName));
  final findSelectedIndex = proxies.indexWhere(
    (proxy) => proxy.name == selectedProxyName,
  );
  final selectedIndex = findSelectedIndex != -1 ? findSelectedIndex : 0;
  return (selectedIndex * getProxyTileHeight()) - 40;
}
