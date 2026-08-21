import 'dart:async';

import 'package:fl_clash/common/perf_trace.dart';
import 'package:flutter/foundation.dart';

/// PHASE4_PERF / debug / profile Core IPC marks for Phase 4D.
///
/// Production release without `--dart-define=PHASE4_PERF=true` is a
/// compile-time no-op. Does not change invoke timeouts, fallbacks, or
/// poll cadence.
///
/// Live transport state (`_globalInflight`, `_methodInflight`, `_classById`)
/// is independent of measurement-window aggregates. Only [resetForTest]
/// clears live state.
class CoreIpcTrace {
  CoreIpcTrace._();

  static bool get enabled => StartupTrace.enabled;

  static const int _ringMax = 64;
  static const int _samplesMaxPerMethod = 128;

  static int _seq = 0;
  static int _windowSeq = 0;
  static String runId = '';
  static String windowId = '';
  static bool window = false;
  static String windowPage = '';
  static Timer? _autoEnd;

  static int _globalInflight = 0;
  static final Map<String, int> _methodInflight = <String, int>{};
  static final Map<String, String> _classById = <String, String>{};

  static int inflightAtWindowStart = 0;
  static Map<String, int> sameMethodInflightAtWindowStart = <String, int>{};
  static int windowPeak = 0;
  static final Map<String, int> windowMethodPeak = <String, int>{};
  static final Map<String, int> requestCounts = <String, int>{};
  static final Map<String, int> overlapCounts = <String, int>{};
  static final Map<String, int> resultCounts = <String, int>{};
  static final Map<String, List<int>> _durations = <String, List<int>>{};
  static final List<Map<String, Object?>> _ring = <Map<String, Object?>>[];

  static int get globalInflight => _globalInflight;

  static int get globalPeak => windowPeak;

  static Map<String, int> get methodPeak => windowMethodPeak;

  static Map<String, Object?> identityExtras([Map<String, Object?> extra = const {}]) {
    return <String, Object?>{
      'run_id': runId,
      'window_id': windowId,
      ...extra,
    };
  }

  static void beginRun({required String id}) {
    if (!enabled) {
      return;
    }
    runId = id;
    windowId = '';
    window = false;
    windowPage = '';
    _windowSeq = 0;
    StartupTrace.mark('ipc_run_begin', extras: identityExtras());
  }

  static void beginWindow({
    String page = '',
    int? autoEndMs,
  }) {
    if (!enabled) {
      return;
    }
    _autoEnd?.cancel();
    _autoEnd = null;
    _windowSeq += 1;
    window = true;
    windowPage = page;
    windowId = runId.isEmpty ? 'w$_windowSeq' : '$runId-w$_windowSeq';
    inflightAtWindowStart = _globalInflight;
    sameMethodInflightAtWindowStart = Map<String, int>.from(_methodInflight);
    _resetWindowAggregates();
    windowPeak = _globalInflight;
    for (final entry in _methodInflight.entries) {
      windowMethodPeak[entry.key] = entry.value;
    }
    StartupTrace.mark(
      'ipc_window_begin',
      extras: identityExtras({
        'page': page,
        'inflight_at_window_start': inflightAtWindowStart,
        'same_method_inflight_at_window_start': sameMethodInflightAtWindowStart
            .entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
      }),
    );
    if (autoEndMs != null && autoEndMs > 0) {
      _autoEnd = Timer(Duration(milliseconds: autoEndMs), endWindow);
    }
  }

  static void endWindow() {
    if (!enabled) {
      return;
    }
    _autoEnd?.cancel();
    _autoEnd = null;
    if (!window) {
      return;
    }
    dump(reason: 'window_end');
    StartupTrace.mark(
      'ipc_window_end',
      extras: identityExtras({
        'page': windowPage,
        'peak_inflight': windowPeak,
        'requests': _totalRequests(),
        'inflight_at_end': _globalInflight,
      }),
    );
    window = false;
    windowPage = '';
  }

  static Map<String, Object?> dump({String reason = 'dump'}) {
    final summary = snapshot();
    if (!enabled) {
      return summary;
    }
    StartupTrace.mark(
      'ipc_dump',
      extras: identityExtras({
        'reason': reason,
        'page': windowPage,
        'peak_inflight': windowPeak,
        'requests': _totalRequests(),
        'nulls': resultCounts['transport_null_or_timeout'] ?? 0,
        'errors': (resultCounts['core_error'] ?? 0) +
            (resultCounts['parse_error'] ?? 0) +
            (resultCounts['exception'] ?? 0),
        'methods': requestCounts.entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
      }),
    );
    return summary;
  }

  static Map<String, Object?> snapshot() {
    return <String, Object?>{
      'run_id': runId,
      'window_id': windowId,
      'page': windowPage,
      'global_inflight': _globalInflight,
      'inflight_at_window_start': inflightAtWindowStart,
      'same_method_inflight_at_window_start': Map<String, int>.from(
        sameMethodInflightAtWindowStart,
      ),
      'global_peak_inflight': windowPeak,
      'requests': Map<String, int>.from(requestCounts),
      'overlap': Map<String, int>.from(overlapCounts),
      'method_peak': Map<String, int>.from(windowMethodPeak),
      'result_class': Map<String, int>.from(resultCounts),
      'durations': {
        for (final entry in _durations.entries)
          entry.key: List<int>.from(entry.value),
      },
    };
  }

  static void classify(String id, String resultClass) {
    if (!enabled) {
      return;
    }
    _classById[id] = resultClass;
  }

  static Future<T?> run<T>({
    required String id,
    required String method,
    required Future<T?> Function() body,
  }) async {
    if (!enabled) {
      return body();
    }
    _seq += 1;
    final caller = _callerHint();
    final createdMs = StartupTrace.elapsedMs;
    StartupTrace.mark(
      'core_ipc_created',
      extras: identityExtras({
        'id': id,
        'method': method,
        'seq': _seq,
        'caller': caller,
      }),
    );
    final sameBefore = _methodInflight[method] ?? 0;
    if (window && sameBefore > 0) {
      overlapCounts[method] = (overlapCounts[method] ?? 0) + 1;
    }
    if (window) {
      requestCounts[method] = (requestCounts[method] ?? 0) + 1;
    }
    _globalInflight += 1;
    if (window && _globalInflight > windowPeak) {
      windowPeak = _globalInflight;
    }
    final sameNow = sameBefore + 1;
    _methodInflight[method] = sameNow;
    if (window) {
      final prevPeak = windowMethodPeak[method] ?? 0;
      if (sameNow > prevPeak) {
        windowMethodPeak[method] = sameNow;
      }
    }
    StartupTrace.mark(
      'core_ipc_dispatch',
      extras: identityExtras({
        'id': id,
        'method': method,
        'inflight': _globalInflight,
        'same_method_inflight': sameNow,
        'caller': caller,
      }),
    );
    final watch = Stopwatch()..start();
    var resultClass = 'success';
    try {
      final out = await body();
      resultClass =
          _classById.remove(id) ??
          (out == null ? 'transport_null_or_timeout' : 'success');
      return out;
    } catch (_) {
      resultClass = _classById.remove(id) ?? 'exception';
      rethrow;
    } finally {
      watch.stop();
      final duration = watch.elapsedMilliseconds;
      _globalInflight = _globalInflight > 0 ? _globalInflight - 1 : 0;
      final left = (_methodInflight[method] ?? 1) - 1;
      if (left <= 0) {
        _methodInflight.remove(method);
      } else {
        _methodInflight[method] = left;
      }
      if (window) {
        resultCounts[resultClass] = (resultCounts[resultClass] ?? 0) + 1;
        final samples = _durations.putIfAbsent(method, () => <int>[]);
        samples.add(duration);
        if (samples.length > _samplesMaxPerMethod) {
          samples.removeRange(0, samples.length - _samplesMaxPerMethod);
        }
      }
      final row = <String, Object?>{
        'id': id,
        'method': method,
        'duration': duration,
        'inflight': _globalInflight + 1,
        'same_method_inflight': sameNow,
        'result_class': resultClass,
        'created_ms': createdMs,
        'caller': caller,
      };
      _ring.add(row);
      if (_ring.length > _ringMax) {
        _ring.removeRange(0, _ring.length - _ringMax);
      }
      final mark = switch (resultClass) {
        'transport_null_or_timeout' => 'core_ipc_null',
        'core_error' || 'parse_error' || 'exception' => 'core_ipc_error',
        'core_not_ready' => 'core_ipc_timeout',
        _ => 'core_ipc_complete',
      };
      final extras = identityExtras({
        'id': id,
        'method': method,
        'duration': duration,
        'inflight': _globalInflight,
        'same_method_inflight': sameNow,
        'result_class': resultClass,
        'caller': caller,
        'latency_kind': 'transport',
      });
      StartupTrace.mark(mark, extras: extras);
      if (mark != 'core_ipc_complete') {
        StartupTrace.mark('core_ipc_complete', extras: extras);
      }
    }
  }

  /// Completer wait failed before [CoreLib.invoke]. Not transport latency.
  static void noteNotReady(String method, {int preinvokeWaitMs = 0}) {
    if (!enabled) {
      return;
    }
    _seq += 1;
    final id = '$method#notready$_seq';
    if (window) {
      resultCounts['core_not_ready'] = (resultCounts['core_not_ready'] ?? 0) + 1;
    }
    final extras = identityExtras({
      'id': id,
      'method': method,
      'duration': 0,
      'preinvoke_wait_ms': preinvokeWaitMs,
      'inflight': _globalInflight,
      'same_method_inflight': _methodInflight[method] ?? 0,
      'result_class': 'core_not_ready',
      'latency_kind': 'preinvoke',
    });
    StartupTrace.mark('core_ipc_timeout', extras: extras);
    StartupTrace.mark('core_ipc_complete', extras: extras);
  }

  static int _totalRequests() {
    var total = 0;
    for (final value in requestCounts.values) {
      total += value;
    }
    return total;
  }

  static void _resetWindowAggregates() {
    windowPeak = 0;
    windowMethodPeak.clear();
    requestCounts.clear();
    overlapCounts.clear();
    resultCounts.clear();
    _durations.clear();
    _ring.clear();
  }

  static String _callerHint() {
    final lines = StackTrace.current.toString().split('\n');
    const skipFiles = <String>[
      'core_ipc_trace.dart',
      'lib.dart',
      'interface.dart',
      'utils.dart',
    ];
    for (final line in lines) {
      var compact = line.trim().replaceAll(RegExp(r'\s+'), '_');
      if (compact.isEmpty) {
        continue;
      }
      if (compact.contains('<asynchronous_suspension>') ||
          compact.contains('asynchronous_suspension')) {
        continue;
      }
      if (skipFiles.any(compact.contains)) {
        continue;
      }
      if (compact.contains('package:flutter/') ||
          compact.contains('dart:async') ||
          compact.contains('dart:ui')) {
        continue;
      }
      compact = compact.replaceAll('package:fl_clash/', '');
      if (compact.length > 96) {
        compact = compact.substring(0, 96);
      }
      return compact;
    }
    return 'unknown';
  }

  @visibleForTesting
  static void resetForTest() {
    _autoEnd?.cancel();
    _autoEnd = null;
    _seq = 0;
    _windowSeq = 0;
    runId = '';
    windowId = '';
    window = false;
    windowPage = '';
    _globalInflight = 0;
    _methodInflight.clear();
    _classById.clear();
    inflightAtWindowStart = 0;
    sameMethodInflightAtWindowStart = <String, int>{};
    _resetWindowAggregates();
  }
}
