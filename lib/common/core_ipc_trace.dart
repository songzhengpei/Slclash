import 'package:fl_clash/common/perf_trace.dart';
import 'package:flutter/foundation.dart';

/// PHASE4_PERF / debug / profile Core IPC marks for Phase 4D.0.
///
/// Production release without `--dart-define=PHASE4_PERF=true` is a
/// compile-time no-op. Does not change invoke timeouts, fallbacks, or
/// poll cadence.
class CoreIpcTrace {
  CoreIpcTrace._();

  static bool get enabled => StartupTrace.enabled;

  static const int _ringMax = 64;
  static const int _samplesMaxPerMethod = 128;

  static int _seq = 0;
  static int _globalInflight = 0;
  static int globalPeak = 0;
  static final Map<String, int> _methodInflight = <String, int>{};
  static final Map<String, int> methodPeak = <String, int>{};
  static final Map<String, int> requestCounts = <String, int>{};
  static final Map<String, int> overlapCounts = <String, int>{};
  static final Map<String, int> resultCounts = <String, int>{};
  static final Map<String, List<int>> _durations = <String, List<int>>{};
  static final List<Map<String, Object?>> _ring = <Map<String, Object?>>[];
  static final Map<String, String> _classById = <String, String>{};
  static bool window = false;
  static String windowPage = '';

  static int get globalInflight => _globalInflight;

  static void beginWindow({String page = ''}) {
    if (!enabled) {
      return;
    }
    window = true;
    windowPage = page;
    _resetCounters();
    StartupTrace.mark('ipc_window_begin', extras: {'page': page});
  }

  static void endWindow() {
    if (!enabled) {
      return;
    }
    dump(reason: 'window_end');
    StartupTrace.mark(
      'ipc_window_end',
      extras: {
        'page': windowPage,
        'peak_inflight': globalPeak,
        'requests': _totalRequests(),
      },
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
      extras: {
        'reason': reason,
        'page': windowPage,
        'peak_inflight': globalPeak,
        'requests': _totalRequests(),
        'nulls': resultCounts['transport_null_or_timeout'] ?? 0,
        'errors': (resultCounts['core_error'] ?? 0) +
            (resultCounts['parse_error'] ?? 0) +
            (resultCounts['exception'] ?? 0),
        'methods': requestCounts.entries
            .map((e) => '${e.key}:${e.value}')
            .join(','),
      },
    );
    return summary;
  }

  static Map<String, Object?> snapshot() {
    return <String, Object?>{
      'page': windowPage,
      'global_inflight': _globalInflight,
      'global_peak_inflight': globalPeak,
      'requests': Map<String, int>.from(requestCounts),
      'overlap': Map<String, int>.from(overlapCounts),
      'method_peak': Map<String, int>.from(methodPeak),
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
    final createdMs = StartupTrace.elapsedMs;
    StartupTrace.mark(
      'core_ipc_created',
      extras: {'id': id, 'method': method, 'seq': _seq},
    );
    final sameBefore = _methodInflight[method] ?? 0;
    if (sameBefore > 0) {
      overlapCounts[method] = (overlapCounts[method] ?? 0) + 1;
    }
    requestCounts[method] = (requestCounts[method] ?? 0) + 1;
    _globalInflight += 1;
    if (_globalInflight > globalPeak) {
      globalPeak = _globalInflight;
    }
    final sameNow = sameBefore + 1;
    _methodInflight[method] = sameNow;
    final prevPeak = methodPeak[method] ?? 0;
    if (sameNow > prevPeak) {
      methodPeak[method] = sameNow;
    }
    StartupTrace.mark(
      'core_ipc_dispatch',
      extras: {
        'id': id,
        'method': method,
        'inflight': _globalInflight,
        'same_method_inflight': sameNow,
      },
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
      resultCounts[resultClass] = (resultCounts[resultClass] ?? 0) + 1;
      final samples = _durations.putIfAbsent(method, () => <int>[]);
      samples.add(duration);
      if (samples.length > _samplesMaxPerMethod) {
        samples.removeRange(0, samples.length - _samplesMaxPerMethod);
      }
      final row = <String, Object?>{
        'id': id,
        'method': method,
        'duration': duration,
        'inflight': _globalInflight + 1,
        'same_method_inflight': sameNow,
        'result_class': resultClass,
        'created_ms': createdMs,
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
      StartupTrace.mark(
        mark,
        extras: {
          'id': id,
          'method': method,
          'duration': duration,
          'inflight': _globalInflight,
          'same_method_inflight': sameNow,
          'result_class': resultClass,
        },
      );
      if (mark != 'core_ipc_complete') {
        StartupTrace.mark(
          'core_ipc_complete',
          extras: {
            'id': id,
            'method': method,
            'duration': duration,
            'inflight': _globalInflight,
            'same_method_inflight': sameNow,
            'result_class': resultClass,
          },
        );
      }
    }
  }

  /// Completer wait failed before [CoreLib.invoke]. Not a transport timeout.
  static void noteNotReady(String method) {
    if (!enabled) {
      return;
    }
    _seq += 1;
    final id = '$method#notready$_seq';
    requestCounts[method] = (requestCounts[method] ?? 0) + 1;
    resultCounts['core_not_ready'] = (resultCounts['core_not_ready'] ?? 0) + 1;
    StartupTrace.mark(
      'core_ipc_timeout',
      extras: {
        'id': id,
        'method': method,
        'duration': 0,
        'inflight': _globalInflight,
        'same_method_inflight': _methodInflight[method] ?? 0,
        'result_class': 'core_not_ready',
      },
    );
    StartupTrace.mark(
      'core_ipc_complete',
      extras: {
        'id': id,
        'method': method,
        'duration': 0,
        'inflight': _globalInflight,
        'same_method_inflight': _methodInflight[method] ?? 0,
        'result_class': 'core_not_ready',
      },
    );
  }

  static int _totalRequests() {
    var total = 0;
    for (final value in requestCounts.values) {
      total += value;
    }
    return total;
  }

  static void _resetCounters() {
    _globalInflight = 0;
    globalPeak = 0;
    _methodInflight.clear();
    methodPeak.clear();
    requestCounts.clear();
    overlapCounts.clear();
    resultCounts.clear();
    _durations.clear();
    _ring.clear();
    _classById.clear();
  }

  @visibleForTesting
  static void resetForTest() {
    _seq = 0;
    window = false;
    windowPage = '';
    _resetCounters();
  }
}
