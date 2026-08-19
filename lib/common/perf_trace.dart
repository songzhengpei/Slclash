import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Compile-time switch for Release profile/perf APKs.
/// Debug and profile builds enable traces automatically.
const bool kPhase4PerfDefine = bool.fromEnvironment('PHASE4_PERF');

/// Low-overhead startup marks for Phase 4A.
///
/// Core outcome marks are mutually exclusive:
/// - `core_ready` — Core connected and initialized
/// - `core_skipped` — initStatus skipped full setup (idle, autoRun off)
/// - `core_connect_failed` — connectCore returned false
/// - `core_init_failed` — connected but init/ensureCoreReady did not leave Core ready
///
/// Release production builds (`kReleaseMode` without `--dart-define=PHASE4_PERF=true`)
/// take the disabled path: a bool check and return. No Timeline, no logcat.
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _watch = Stopwatch();
  static developer.TimelineTask? _task;
  static bool _started = false;

  static bool get enabled =>
      kPhase4PerfDefine || kDebugMode || kProfileMode;

  static int get elapsedMs => _watch.isRunning ? _watch.elapsedMilliseconds : 0;

  static void beginProcess() {
    if (!enabled || _started) {
      return;
    }
    _started = true;
    _watch.start();
    _task = developer.TimelineTask()..start('startup');
    mark('process_main_begin');
  }

  static void mark(String name) {
    if (!enabled) {
      return;
    }
    final ms = elapsedMs;
    developer.Timeline.instantSync(name, arguments: {'elapsed_ms': ms});
    _task?.instant(name, arguments: {'elapsed_ms': ms});
    // Prefer print for ADB logcat reliability; gated by [enabled] above.
    // ignore: avoid_print
    print('[PHASE4] mark=$name elapsed_ms=$ms');
  }

  static void finish(String name) {
    mark(name);
    _task?.finish();
    _task = null;
  }

  @visibleForTesting
  static void resetForTest() {
    _watch
      ..stop()
      ..reset();
    _task?.finish();
    _task = null;
    _started = false;
  }
}
