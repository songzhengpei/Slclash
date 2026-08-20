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
  container.read(proxiesActionProvider.notifier).captureSelectionBaseline(
    group.name,
  );
  if (decision.kind == ProxyGroupTapKind.unfix) {
    final gen = ProxyTrace.noteSelectIntent(
      group: group.name,
      proxy: '',
      action: 'unfix',
    );
    container.read(profilesActionProvider.notifier).updateCurrentSelectedMap(
      group.name,
      '',
    );
    ProxyTrace.noteSelectVisual(gen: gen, group: group.name, proxy: '');
    container.read(proxiesActionProvider.notifier).unfixProxyDebounce(
      group.name,
      gen: gen,
    );
    return true;
  }
  final gen = ProxyTrace.noteSelectIntent(
    group: group.name,
    proxy: decision.proxyName,
    action: 'select',
  );
  container.read(profilesActionProvider.notifier).updateCurrentSelectedMap(
    group.name,
    decision.proxyName,
  );
  ProxyTrace.noteSelectVisual(
    gen: gen,
    group: group.name,
    proxy: decision.proxyName,
  );
  container.read(proxiesActionProvider.notifier).changeProxyDebounce(
    group.name,
    decision.proxyName,
    gen: gen,
  );
  return true;
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final ref = globalState.container;
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
  ref
      .read(proxiesActionProvider.notifier)
      .setDelay(Delay(url: currentTestUrl, name: state.proxyName, value: 0));
  try {
    ref
        .read(proxiesActionProvider.notifier)
        .setDelay(
          await coreController.getDelay(currentTestUrl, state.proxyName),
        );
    ProxyTrace.delayFinish(name: state.proxyName, ok: true);
  } catch (e) {
    commonPrint.log('proxyDelayTest failed for ${state.proxyName}: $e');
    ref
        .read(proxiesActionProvider.notifier)
        .setDelay(Delay(url: currentTestUrl, name: state.proxyName, value: -1));
    ProxyTrace.delayFinish(name: state.proxyName, ok: false);
  }
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  StartupTrace.mark(
    'delay_test_begin',
    extras: {'count': proxies.length},
  );
  final delayProxies = proxies.map<Future>((proxy) async {
    await proxyDelayTest(proxy, testUrl);
  }).toList();

  StartupTrace.mark(
    'delay_test_after_map',
    extras: {
      'count': proxies.length,
      'peak_inflight': ProxyTrace.peakInflight,
      'started': ProxyTrace.delayStarted,
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
