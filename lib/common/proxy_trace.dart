import 'package:fl_clash/common/perf_trace.dart';
import 'package:flutter/foundation.dart';

/// Profile/debug Proxy / Group UX marks for Phase 4C.0.
///
/// Same enablement as [StartupTrace]. Production release without
/// `--dart-define=PHASE4_PERF=true` is a compile-time no-op.
///
/// Does not change selection, delay, or Core semantics.
class ProxyTrace {
  ProxyTrace._();

  static bool get enabled => StartupTrace.enabled;

  static bool _session = false;
  static int _inflight = 0;
  static int peakInflight = 0;
  static int delayStarted = 0;
  static int delayFinished = 0;
  static int delayFailed = 0;
  static int selectionGen = 0;
  static int lastEagerItems = 0;
  static int lastEagerProxyCards = 0;
  static final Map<String, int> hotspotBuilds = <String, int>{};

  static bool get sessionActive => _session;

  static void beginSession({String kind = 'proxy_ux'}) {
    if (!enabled) {
      return;
    }
    _session = true;
    hotspotBuilds.clear();
    resetDelayCounters();
    lastEagerItems = 0;
    lastEagerProxyCards = 0;
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
        'selection_gen': selectionGen,
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

  static void noteHotspotBuild(String name) {
    if (!enabled || !_session) {
      return;
    }
    hotspotBuilds[name] = (hotspotBuilds[name] ?? 0) + 1;
  }

  static void noteEagerList({required int items, required int proxyCards}) {
    if (!enabled || !_session) {
      return;
    }
    lastEagerItems = items;
    lastEagerProxyCards = proxyCards;
    StartupTrace.mark(
      'proxy_eager_list',
      extras: {'items': items, 'proxy_cards': proxyCards},
    );
  }

  static int noteSelectIntent({
    required String group,
    required String proxy,
  }) {
    if (!enabled) {
      return 0;
    }
    selectionGen += 1;
    StartupTrace.mark(
      'proxy_select_intent',
      extras: {
        'gen': selectionGen,
        'group': group,
        'proxy': proxy,
      },
    );
    return selectionGen;
  }

  static void noteSelectCoreAck({
    required int gen,
    required String result,
  }) {
    if (!enabled) {
      return;
    }
    StartupTrace.mark(
      'proxy_select_core_ack',
      extras: {'gen': gen, 'result': result.isEmpty ? 'ok' : result},
    );
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
    resetDelayCounters();
    selectionGen = 0;
    lastEagerItems = 0;
    lastEagerProxyCards = 0;
    hotspotBuilds.clear();
  }
}
