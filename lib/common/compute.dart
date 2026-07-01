import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

List<Group> computeSort({
  required List<Group> groups,
  required ProxiesSortType sortType,
  required DelayMap delayMap,
  required Map<String, String> selectedMap,
  required String defaultTestUrl,
}) {
  List<Proxy> sortOfDelay({
    required List<Group> groups,
    required List<Proxy> proxies,
    required DelayMap delayMap,
    required Map<String, String> selectedMap,
    required String testUrl,
  }) {
    return List.from(proxies)..sort((a, b) {
      final aDelayState = computeProxyDelayState(
        proxyName: a.name,
        testUrl: testUrl,
        groups: groups,
        selectedMap: selectedMap,
        delayMap: delayMap,
      );
      final bDelayState = computeProxyDelayState(
        proxyName: b.name,
        testUrl: testUrl,
        groups: groups,
        selectedMap: selectedMap,
        delayMap: delayMap,
      );
      return aDelayState.compareTo(bDelayState);
    });
  }

  List<Proxy> sortOfName(List<Proxy> proxies) {
    return List.of(proxies)..sort((a, b) => a.name.compareTo(b.name));
  }

  return groups.map((group) {
    final proxies = group.all;
    final newProxies = switch (sortType) {
      ProxiesSortType.none => proxies,
      ProxiesSortType.delay => sortOfDelay(
        groups: groups,
        proxies: proxies,
        delayMap: delayMap,
        selectedMap: selectedMap,
        testUrl: group.testUrl.takeFirstValid([defaultTestUrl]),
      ),
      ProxiesSortType.name => sortOfName(proxies),
    };
    return group.copyWith(all: newProxies);
  }).toList();
}

List<Group> stripRuntimeNowFromGroups(List<Group> groups) {
  var hasChanges = false;
  final nextGroups = <Group>[];
  for (final group in groups) {
    final proxies = group.all;
    final nextProxies = _stripRuntimeNowFromProxies(proxies);
    final shouldClearGroupNow = group.now?.isNotEmpty == true;
    final shouldCopyGroup =
        shouldClearGroupNow || !identical(nextProxies, proxies);
    if (!shouldCopyGroup) {
      nextGroups.add(group);
      continue;
    }
    hasChanges = true;
    nextGroups.add(group.copyWith(now: '', all: nextProxies));
  }
  return hasChanges ? nextGroups : groups;
}

List<Proxy> _stripRuntimeNowFromProxies(List<Proxy> proxies) {
  List<Proxy>? nextProxies;
  for (var i = 0; i < proxies.length; i++) {
    final proxy = proxies[i];
    if (proxy.now?.isNotEmpty != true) {
      continue;
    }
    nextProxies ??= List<Proxy>.of(proxies);
    nextProxies[i] = proxy.copyWith(now: '');
  }
  return nextProxies ?? proxies;
}

List<Group> filterGroupsByProxyName(List<Group> groups, String query) {
  final lowQuery = query.toLowerCase();
  final nextGroups = <Group>[];
  for (final group in groups) {
    final matchedProxies = _filterProxiesByLowerName(group.all, lowQuery);
    if (matchedProxies == null) {
      continue;
    }
    nextGroups.add(group.copyWith(all: matchedProxies));
  }
  return nextGroups;
}

List<Proxy> filterProxiesByName(List<Proxy> proxies, String query) {
  return _filterProxiesByLowerName(proxies, query.toLowerCase()) ?? [];
}

List<Proxy>? _filterProxiesByLowerName(List<Proxy> proxies, String lowQuery) {
  List<Proxy>? matchedProxies;
  for (final proxy in proxies) {
    if (!proxy.name.toLowerCase().contains(lowQuery)) {
      continue;
    }
    matchedProxies ??= <Proxy>[];
    matchedProxies.add(proxy);
  }
  return matchedProxies;
}

SelectedProxyState getRealSelectedProxyState(
  SelectedProxyState state, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
  Map<String, String>? computedSelectedMap,
}) {
  if (state.proxyName.isEmpty) return state;
  final index = groups.indexWhere((element) => element.name == state.proxyName);
  final newState = state.copyWith(group: true);
  if (index == -1) return newState;
  final group = groups[index];
  final currentSelectedName = group.getCurrentSelectedName(
    selectedMap[newState.proxyName] ?? '',
    cachedComputedNow: computedSelectedMap?[newState.proxyName],
  );
  if (currentSelectedName.isEmpty) {
    return newState;
  }
  return getRealSelectedProxyState(
    newState.copyWith(proxyName: currentSelectedName, testUrl: group.testUrl),
    groups: groups,
    selectedMap: selectedMap,
    computedSelectedMap: computedSelectedMap,
  );
}

SelectedProxyState computeRealSelectedProxyState(
  String proxyName, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
  Map<String, String>? computedSelectedMap,
}) {
  return getRealSelectedProxyState(
    SelectedProxyState(proxyName: proxyName),
    groups: groups,
    selectedMap: selectedMap,
    computedSelectedMap: computedSelectedMap,
  );
}

DelayState computeProxyDelayState({
  required String proxyName,
  required String testUrl,
  required List<Group> groups,
  required Map<String, String> selectedMap,
  required DelayMap delayMap,
  Map<String, String>? computedSelectedMap,
}) {
  final state = computeRealSelectedProxyState(
    proxyName,
    groups: groups,
    selectedMap: selectedMap,
    computedSelectedMap: computedSelectedMap,
  );
  final currentDelayMap =
      delayMap[state.testUrl.takeFirstValid([testUrl])] ?? {};
  final delay = currentDelayMap[state.proxyName];
  return DelayState(delay: delay ?? 0, group: state.group);
}
