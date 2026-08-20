import 'package:fl_clash/common/perf_trace.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

/// Profile/debug Proxy / Group UX marks for Phase 4C.
///
/// Same enablement as [StartupTrace]. Production release without
/// `--dart-define=PHASE4_PERF=true` is a compile-time no-op.
///
/// Does not change selection, delay, or Core semantics.
class ProxyTrace {
  ProxyTrace._();

  static bool get enabled => StartupTrace.enabled;

  static bool _session = false;
  static bool _firstGroupVisible = false;
  static int _inflight = 0;
  static int peakInflight = 0;
  static int delayStarted = 0;
  static int delayFinished = 0;
  static int delayFailed = 0;
  static int _nextGen = 0;
  static int lastEagerItems = 0;
  static int lastEagerProxyCards = 0;
  static int supersededCount = 0;
  static int dispatchCount = 0;
  static int ackCount = 0;
  static int lastAckGen = 0;
  static final Map<String, int> hotspotBuilds = <String, int>{};
  static final Map<int, _SelectClock> _clocks = <int, _SelectClock>{};
  static final Map<String, int> _queuedGen = <String, int>{};
  static final Map<String, int> _awaitingGroups = <String, int>{};

  static bool get sessionActive => _session;

  /// Last issued intent generation. Not an ACK generation.
  static int get selectionGen => _nextGen;

  static void beginSession({String kind = 'proxy_ux'}) {
    if (!enabled) {
      return;
    }
    _session = true;
    _firstGroupVisible = false;
    hotspotBuilds.clear();
    resetDelayCounters();
    lastEagerItems = 0;
    lastEagerProxyCards = 0;
    supersededCount = 0;
    dispatchCount = 0;
    ackCount = 0;
    lastAckGen = 0;
    StartupTrace.mark('proxy_session_begin', extras: {'kind': kind});
  }

  static void endSession() {
    if (!enabled) {
      return;
    }
    StartupTrace.mark(
      'proxy_session_end',
      extras: {
        'peak_inflight': peakInflight,
        'delay_started': delayStarted,
        'delay_finished': delayFinished,
        'delay_failed': delayFailed,
        'selection_gen': _nextGen,
        'superseded': supersededCount,
        'dispatch': dispatchCount,
        'ack': ackCount,
        'eager_items': lastEagerItems,
        'eager_proxy_cards': lastEagerProxyCards,
        'hotspot_builds': hotspotBuilds.entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
      },
    );
    _session = false;
  }

  static void resetDelayCounters() {
    _inflight = 0;
    peakInflight = 0;
    delayStarted = 0;
    delayFinished = 0;
    delayFailed = 0;
  }

  static void resetEventScope({String event = ''}) {
    if (!enabled) {
      return;
    }
    hotspotBuilds.clear();
    lastEagerItems = 0;
    lastEagerProxyCards = 0;
    StartupTrace.mark('proxy_event_reset', extras: {'event': event});
  }

  static Map<String, Object?> dumpEventScope({String event = ''}) {
    final dump = <String, Object?>{
      'event': event,
      'eager_items': lastEagerItems,
      'eager_proxy_cards': lastEagerProxyCards,
      'proxies_view': hotspotBuilds['proxies_view'] ?? 0,
      'proxies_list': hotspotBuilds['proxies_list'] ?? 0,
      'list_header': hotspotBuilds['list_header'] ?? 0,
      'proxy_card': hotspotBuilds['proxy_card'] ?? 0,
    };
    if (!enabled) {
      return dump;
    }
    StartupTrace.mark(
      'proxy_event_dump',
      extras: {
        'event': event,
        'eager_items': lastEagerItems,
        'eager_proxy_cards': lastEagerProxyCards,
        'hotspot_builds': hotspotBuilds.entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
      },
    );
    return dump;
  }

  static void noteHotspotBuild(String name) {
    if (!enabled || !_session) {
      return;
    }
    hotspotBuilds[name] = (hotspotBuilds[name] ?? 0) + 1;
  }

  static void noteFirstGroupVisible() {
    if (!enabled || !_session || _firstGroupVisible) {
      return;
    }
    _firstGroupVisible = true;
    StartupTrace.mark('proxy_first_group_visible');
  }

  static void noteEagerList({required int items, required int proxyCards}) {
    if (!enabled || !_session) {
      return;
    }
    lastEagerItems = items;
    lastEagerProxyCards = proxyCards;
    StartupTrace.mark(
      'proxy_eager_list',
      extras: {
        'items': items,
        'proxy_cards': proxyCards,
        'proxy_item_materialized': items,
      },
    );
  }

  static int noteSelectIntent({
    required String group,
    required String proxy,
    String action = 'select',
  }) {
    if (!enabled) {
      return 0;
    }
    final prevQueued = _queuedGen[group];
    _nextGen += 1;
    final gen = _nextGen;
    if (prevQueued != null && prevQueued != gen) {
      supersededCount += 1;
      StartupTrace.mark(
        'proxy_select_superseded',
        extras: {
          'gen': prevQueued,
          'group': group,
          'by_gen': gen,
        },
      );
    }
    _queuedGen[group] = gen;
    _clocks[gen] = _SelectClock(
      gen: gen,
      group: group,
      proxy: proxy,
      action: action,
      intentElapsedMs: StartupTrace.elapsedMs,
    );
    StartupTrace.mark(
      'proxy_select_intent',
      extras: {
        'gen': gen,
        'group': group,
        'proxy': proxy,
        'action': action,
      },
    );
    return gen;
  }

  static void noteSelectVisual({
    required int gen,
    required String group,
    required String proxy,
  }) {
    if (!enabled || gen <= 0) {
      return;
    }
    final clock = _clocks[gen];
    final now = StartupTrace.elapsedMs;
    StartupTrace.mark(
      'proxy_select_visual',
      extras: {
        'gen': gen,
        'group': group,
        'proxy': proxy,
        'elapsed_from_intent_ms': clock == null
            ? 0
            : now - clock.intentElapsedMs,
      },
    );
  }

  static void noteSelectDispatch({
    required int gen,
    required String group,
    required String proxy,
  }) {
    if (!enabled || gen <= 0) {
      return;
    }
    if (_queuedGen[group] == gen) {
      _queuedGen.remove(group);
    }
    final clock = _clocks[gen];
    final now = StartupTrace.elapsedMs;
    clock?.dispatchElapsedMs = now;
    dispatchCount += 1;
    StartupTrace.mark(
      'proxy_select_dispatch',
      extras: {
        'gen': gen,
        'group': group,
        'proxy': proxy,
      },
    );
  }

  static void noteSelectCoreAck({
    required int gen,
    required String result,
    String? group,
  }) {
    if (!enabled) {
      return;
    }
    final clock = _clocks[gen];
    final now = StartupTrace.elapsedMs;
    clock?.ackElapsedMs = now;
    ackCount += 1;
    lastAckGen = gen;
    final resolvedGroup = group ?? clock?.group ?? '';
    if (gen > 0 && resolvedGroup.isNotEmpty) {
      _awaitingGroups[resolvedGroup] = gen;
    }
    StartupTrace.mark(
      'proxy_select_core_ack',
      extras: {
        'gen': gen,
        'group': resolvedGroup,
        'result': result.isEmpty ? 'ok' : result,
        'elapsed_from_intent_ms': clock == null
            ? 0
            : now - clock.intentElapsedMs,
        'elapsed_from_dispatch_ms':
            clock == null || clock.dispatchElapsedMs == null
            ? 0
            : now - clock.dispatchElapsedMs!,
      },
    );
  }

  static void noteGroupsConsistent(List<Group> groups) {
    if (!enabled || _awaitingGroups.isEmpty) {
      return;
    }
    final pending = Map<String, int>.from(_awaitingGroups);
    for (final entry in pending.entries) {
      final group = groups.getGroup(entry.key);
      if (group == null) {
        continue;
      }
      final clock = _clocks[entry.value];
      final now = StartupTrace.elapsedMs;
      StartupTrace.mark(
        'proxy_select_groups_consistent',
        extras: {
          'gen': entry.value,
          'group': group.name,
          'now': group.realNow,
          'fixed': group.fixed ?? 'null',
          'elapsed_from_intent_ms': clock == null
              ? 0
              : now - clock.intentElapsedMs,
        },
      );
      _awaitingGroups.remove(entry.key);
    }
  }

  static void delayStart({required String name}) {
    if (!enabled) {
      return;
    }
    delayStarted += 1;
    _inflight += 1;
    if (_inflight > peakInflight) {
      peakInflight = _inflight;
    }
    StartupTrace.mark(
      'delay_request_started',
      extras: {
        'name': name,
        'inflight': _inflight,
        'peak_inflight': peakInflight,
      },
    );
  }

  static void delayFinish({required String name, required bool ok}) {
    if (!enabled) {
      return;
    }
    if (_inflight > 0) {
      _inflight -= 1;
    }
    if (ok) {
      delayFinished += 1;
    } else {
      delayFailed += 1;
    }
    StartupTrace.mark(
      ok ? 'delay_request_finished' : 'delay_request_failed',
      extras: {
        'name': name,
        'inflight': _inflight,
        'peak_inflight': peakInflight,
      },
    );
  }

  /// Matches [ProxiesListView] `_buildItems`: one header per group plus
  /// one child widget per expanded proxy.
  @visibleForTesting
  static int eagerWidgetCount({
    required int headers,
    required int expandedProxies,
  }) {
    return headers + expandedProxies;
  }

  @visibleForTesting
  static void resetForTest() {
    _session = false;
    _firstGroupVisible = false;
    resetDelayCounters();
    _nextGen = 0;
    lastEagerItems = 0;
    lastEagerProxyCards = 0;
    supersededCount = 0;
    dispatchCount = 0;
    ackCount = 0;
    lastAckGen = 0;
    hotspotBuilds.clear();
    _clocks.clear();
    _queuedGen.clear();
    _awaitingGroups.clear();
  }
}

class _SelectClock {
  _SelectClock({
    required this.gen,
    required this.group,
    required this.proxy,
    required this.action,
    required this.intentElapsedMs,
  });

  final int gen;
  final String group;
  final String proxy;
  final String action;
  final int intentElapsedMs;
  int? dispatchElapsedMs;
  int? ackElapsedMs;
}
