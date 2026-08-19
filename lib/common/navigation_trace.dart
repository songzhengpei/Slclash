import 'dart:math' as math;

import 'package:fl_clash/common/page_scroll_visit.dart';
import 'package:fl_clash/common/perf_trace.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Low-overhead navigation / page-mount instrumentation for Phase 4B.
///
/// Same enablement as [StartupTrace]: debug + profile always on; production
/// release is a compile-time no-op unless `--dart-define=PHASE4_PERF=true`.
/// FrameTiming callbacks are registered only while a transition is active.
///
/// [target_first_build_latency_ms] / [first_build_ms] is elapsed time from
/// [begin] until the target page-root [build] is *invoked*. It is **not**
/// the CPU duration of that build.
class NavigationTrace {
  NavigationTrace._();

  static bool get enabled => StartupTrace.enabled;

  static int _seq = 0;
  static _ActiveNav? _active;
  static final Map<String, int> _mountCounts = <String, int>{};
  static final Map<String, int> _buildCounts = <String, int>{};
  static final Set<String> _seenPages = <String>{};
  static TimingsCallback? _timingsCallback;

  @visibleForTesting
  static Map<String, Object?>? lastCompleteExtras;

  static double displayRefreshHz() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return 60;
    }
    final hz = views.first.display.refreshRate;
    return hz > 0 ? hz : 60;
  }

  static double frameBudgetMs({double? refreshHz}) {
    final hz = refreshHz ?? displayRefreshHz();
    if (hz <= 0) {
      return 16.67;
    }
    return 1000.0 / hz;
  }

  static void mark(String name, {Map<String, Object?> extras = const {}}) {
    if (!enabled) {
      return;
    }
    StartupTrace.mark(name, extras: extras);
  }

  static int? get activeSeq => _active?.seq;

  static String? get activeKind => _active?.kind;

  static bool dashboardHeroMounted = false;
  static bool dashboardSheenRepeating = false;
  static bool dashboardPulseRepeating = false;
  static bool networkLatencyTimerActive = false;
  static bool networkLatencyBarRepeating = false;

  static void begin({
    required String source,
    required String target,
    required String kind,
  }) {
    if (!enabled) {
      return;
    }
    final leftover = _active;
    if (leftover != null && !leftover.completed) {
      complete(reason: 'superseded');
    }
    _seq += 1;
    final refreshHz = displayRefreshHz();
    _active = _ActiveNav(
      seq: _seq,
      source: source,
      target: target,
      kind: kind,
      refreshHz: refreshHz,
      budgetMs: frameBudgetMs(refreshHz: refreshHz),
    );
    _bindTimings();
    mark(
      'nav_begin',
      extras: {
        'seq': _seq,
        'source': source,
        'target': target,
        'kind': kind,
        'refresh_hz': refreshHz.toStringAsFixed(2),
        'budget_ms': _active!.budgetMs.toStringAsFixed(3),
      },
    );
  }

  static void markAnimateStart({
    required String mode,
    required int durationMs,
  }) {
    final active = _active;
    if (!enabled || active == null) {
      return;
    }
    active.animateMode = mode;
    active.animateDurationMs = durationMs;
    active.animateStartMs = active.watch.elapsedMilliseconds;
    mark(
      'nav_animate_start',
      extras: {
        'seq': active.seq,
        'mode': mode,
        'duration_ms': durationMs,
      },
    );
  }

  static void markAnimationComplete() {
    final active = _active;
    if (!enabled || active == null || active.animationCompleteMs != null) {
      return;
    }
    active.animationCompleteMs = active.watch.elapsedMilliseconds;
    mark(
      'nav_animation_complete',
      extras: {
        'seq': active.seq,
        'total_ms': active.animationCompleteMs,
      },
    );
  }

  static void noteMount(String page) {
    if (!enabled) {
      return;
    }
    _mountCounts[page] = (_mountCounts[page] ?? 0) + 1;
  }

  static void noteBuild(String page, {required bool keepAlive}) {
    if (!enabled) {
      return;
    }
    _buildCounts[page] = (_buildCounts[page] ?? 0) + 1;
    final active = _active;
    if (active == null ||
        active.target != page ||
        active.targetFirstBuildLatencyMs != null) {
      return;
    }
    active.targetFirstBuildLatencyMs = active.watch.elapsedMilliseconds;
    active.keepAlive = keepAlive;
    active.mountCount = _mountCounts[page] ?? 0;
    active.buildCount = _buildCounts[page] ?? 0;
    active.visitKind = _seenPages.contains(page) ? 'revisit' : 'first';
    mark(
      'nav_target_first_build',
      extras: {
        'seq': active.seq,
        'page': page,
        'visit': active.visitKind,
        'keep_alive': keepAlive,
        'mount_count': active.mountCount,
        'build_count': active.buildCount,
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      noteFirstPostFrame(page);
    });
  }

  static void noteFirstPostFrame(String page) {
    final active = _active;
    if (!enabled || active == null || active.target != page) {
      return;
    }
    if (active.firstPostFrameMs != null) {
      return;
    }
    active.firstPostFrameMs = active.watch.elapsedMilliseconds;
    mark(
      'nav_target_first_frame',
      extras: {
        'seq': active.seq,
        'page': page,
        'total_ms': active.firstPostFrameMs,
      },
    );
  }

  static void markScrollToTop({
    required String page,
    required bool animate,
    required VerticalScrollVisit visit,
  }) {
    final active = _active;
    if (!enabled) {
      return;
    }
    final extras = <String, Object?>{
      'seq': active?.seq ?? 0,
      'page': page,
      'animate': animate,
      'elements': visit.elementsVisited,
      'positions': visit.positionCount,
      'duration_us': visit.elapsedMicros,
      'animation_running': active != null && active.animationCompleteMs == null,
    };
    if (active != null) {
      active.scrollVisits.add(extras);
      active.scrollCommandMs ??= active.watch.elapsedMilliseconds;
    }
    mark('nav_scroll_to_top', extras: extras);
    mark(
      'nav_scroll_command',
      extras: {
        ...extras,
        'command_ms': active?.scrollCommandMs,
      },
    );
  }

  static void markScrollAnimationComplete({bool skipped = false}) {
    final active = _active;
    if (!enabled) {
      return;
    }
    final ms = active?.watch.elapsedMilliseconds;
    if (active != null && active.scrollAnimationCompleteMs == null) {
      active.scrollAnimationCompleteMs = ms;
    }
    mark(
      'nav_scroll_animation_complete',
      extras: {
        'seq': active?.seq ?? 0,
        'skipped': skipped,
        'scroll_animation_complete_ms': ms,
      },
    );
  }

  static void markScrollBy({
    required String page,
    required double dy,
    required VerticalScrollVisit visit,
  }) {
    if (!enabled) {
      return;
    }
    mark(
      'nav_scroll_by',
      extras: {
        'page': page,
        'dy': dy.round(),
        'elements': visit.elementsVisited,
        'positions': visit.positionCount,
        'duration_us': visit.elapsedMicros,
      },
    );
  }

  static void scheduleComplete({String reason = 'settled'}) {
    if (!enabled || _active == null || _active!.completeScheduled) {
      return;
    }
    _active!.completeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        complete(reason: reason);
      });
    });
  }

  static void complete({String reason = 'settled'}) {
    final active = _active;
    if (!enabled || active == null || active.completed) {
      return;
    }
    active.completed = true;
    _unbindTimings();
    final totalMs = active.watch.elapsedMilliseconds;
    _seenPages.add(active.target);
    final frames = active.frames;
    final build = frames.map((f) => f.buildMs).toList();
    final raster = frames.map((f) => f.rasterMs).toList();
    final span = frames.map((f) => f.totalMs).toList();
    final overBudget = span.where((ms) => ms > active.budgetMs).length;
    final extras = <String, Object?>{
      'seq': active.seq,
      'source': active.source,
      'target': active.target,
      'kind': active.kind,
      'reason': reason,
      'mode': active.animateMode ?? 'none',
      'visit': active.visitKind ?? 'unknown',
      'keep_alive': active.keepAlive,
      'mount_count': active.mountCount,
      'build_count': active.buildCount,
      'total_ms': totalMs,
      'animate_start_ms': active.animateStartMs,
      'target_first_build_latency_ms': active.targetFirstBuildLatencyMs,
      'first_build_ms': active.targetFirstBuildLatencyMs,
      'first_frame_ms': active.firstPostFrameMs,
      'scroll_command_ms': active.scrollCommandMs,
      'scroll_animation_complete_ms': active.scrollAnimationCompleteMs,
      'animation_complete_ms': active.animationCompleteMs,
      'frame_count': frames.length,
      'build_p50_ms': _pct(build, 50),
      'build_p90_ms': _pct(build, 90),
      'build_p99_ms': _pct(build, 99),
      'raster_p50_ms': _pct(raster, 50),
      'raster_p90_ms': _pct(raster, 90),
      'raster_p99_ms': _pct(raster, 99),
      'total_p50_ms': _pct(span, 50),
      'total_p90_ms': _pct(span, 90),
      'total_p99_ms': _pct(span, 99),
      'worst_frame_ms': span.isEmpty ? 0 : span.reduce(math.max),
      'over_budget': overBudget,
      'budget_ms': active.budgetMs.toStringAsFixed(3),
      'refresh_hz': active.refreshHz.toStringAsFixed(2),
      'scroll_visits': active.scrollVisits.length,
      'scroll_elements': _maxInt(
        active.scrollVisits.map((e) => e['elements']),
      ),
      'scroll_positions': _maxInt(
        active.scrollVisits.map((e) => e['positions']),
      ),
      'scroll_us': _sumInt(active.scrollVisits.map((e) => e['duration_us'])),
    };
    lastCompleteExtras = extras;
    mark('nav_complete', extras: extras);
    _active = null;
  }

  static Map<String, int> mountCounts() => Map<String, int>.from(_mountCounts);

  static Map<String, int> buildCounts() => Map<String, int>.from(_buildCounts);

  static void dumpCounts({bool? dashboardKeepOverride}) {
    if (!enabled) {
      return;
    }
    mark(
      'nav_page_counts',
      extras: {
        'mounts': _formatCounts(_mountCounts),
        'builds': _formatCounts(_buildCounts),
        'dashboard_keep_override': dashboardKeepOverride,
        'dashboard_hero_mounted': dashboardHeroMounted,
        'dashboard_sheen_repeating': dashboardSheenRepeating,
        'dashboard_pulse_repeating': dashboardPulseRepeating,
        'network_latency_timer': networkLatencyTimerActive,
        'network_latency_bar': networkLatencyBarRepeating,
      },
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _unbindTimings();
    _seq = 0;
    _active = null;
    _mountCounts.clear();
    _buildCounts.clear();
    _seenPages.clear();
    lastCompleteExtras = null;
    dashboardHeroMounted = false;
    dashboardSheenRepeating = false;
    dashboardPulseRepeating = false;
    networkLatencyTimerActive = false;
    networkLatencyBarRepeating = false;
  }

  static void _bindTimings() {
    if (_timingsCallback != null) {
      return;
    }
    void callback(List<FrameTiming> timings) {
      final active = _active;
      if (active == null) {
        return;
      }
      for (final timing in timings) {
        active.frames.add(
          (
            buildMs: timing.buildDuration.inMicroseconds / 1000.0,
            rasterMs: timing.rasterDuration.inMicroseconds / 1000.0,
            totalMs: timing.totalSpan.inMicroseconds / 1000.0,
          ),
        );
      }
    }

    _timingsCallback = callback;
    WidgetsBinding.instance.addTimingsCallback(callback);
  }

  static void _unbindTimings() {
    final callback = _timingsCallback;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.removeTimingsCallback(callback);
    _timingsCallback = null;
  }

  static String _formatCounts(Map<String, int> counts) {
    if (counts.isEmpty) {
      return '-';
    }
    final keys = counts.keys.toList()..sort();
    return keys.map((key) => '$key:${counts[key]}').join(',');
  }

  static int _maxInt(Iterable<Object?> values) {
    var max = 0;
    for (final value in values) {
      final n = value is int ? value : int.tryParse('$value') ?? 0;
      if (n > max) {
        max = n;
      }
    }
    return max;
  }

  static int _sumInt(Iterable<Object?> values) {
    var sum = 0;
    for (final value in values) {
      sum += value is int ? value : int.tryParse('$value') ?? 0;
    }
    return sum;
  }

  static String _pct(List<double> values, double p) {
    if (values.isEmpty) {
      return '0';
    }
    final ordered = [...values]..sort();
    if (ordered.length == 1) {
      return ordered.first.toStringAsFixed(3);
    }
    final k = (ordered.length - 1) * (p / 100.0);
    final lo = k.floor();
    final hi = math.min(lo + 1, ordered.length - 1);
    final frac = k - lo;
    return (ordered[lo] * (1 - frac) + ordered[hi] * frac).toStringAsFixed(3);
  }
}

class _ActiveNav {
  _ActiveNav({
    required this.seq,
    required this.source,
    required this.target,
    required this.kind,
    required this.refreshHz,
    required this.budgetMs,
  });

  final int seq;
  final String source;
  final String target;
  final String kind;
  final double refreshHz;
  final double budgetMs;
  final Stopwatch watch = Stopwatch()..start();
  final List<({double buildMs, double rasterMs, double totalMs})> frames = [];
  final List<Map<String, Object?>> scrollVisits = [];
  String? animateMode;
  int animateDurationMs = 0;
  int? animateStartMs;
  int? targetFirstBuildLatencyMs;
  int? scrollCommandMs;
  int? scrollAnimationCompleteMs;
  int? firstPostFrameMs;
  int? animationCompleteMs;
  String? visitKind;
  bool keepAlive = false;
  int mountCount = 0;
  int buildCount = 0;
  bool completeScheduled = false;
  bool completed = false;
}

/// Page-root probe used only while [NavigationTrace.enabled] is true.
class NavigationMountProbe extends StatefulWidget {
  const NavigationMountProbe({
    super.key,
    required this.page,
    required this.keepAlive,
    required this.child,
  });

  final String page;
  final bool keepAlive;
  final Widget child;

  @override
  State<NavigationMountProbe> createState() => _NavigationMountProbeState();
}

class _NavigationMountProbeState extends State<NavigationMountProbe> {
  @override
  void initState() {
    super.initState();
    NavigationTrace.noteMount(widget.page);
  }

  @override
  Widget build(BuildContext context) {
    NavigationTrace.noteBuild(widget.page, keepAlive: widget.keepAlive);
    return widget.child;
  }
}
