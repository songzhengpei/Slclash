import 'package:fl_clash/common/navigation_trace.dart';
import 'package:fl_clash/common/perf_trace.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(NavigationTrace.resetForTest);
  tearDown(StartupTrace.resetForTest);

  test('frame budget follows refresh rate instead of a hardcoded 16.67ms', () {
    expect(NavigationTrace.frameBudgetMs(refreshHz: 60), closeTo(16.666, 0.01));
    expect(NavigationTrace.frameBudgetMs(refreshHz: 120), closeTo(8.333, 0.01));
    expect(NavigationTrace.frameBudgetMs(refreshHz: 90), closeTo(11.111, 0.01));
  });

  testWidgets('nav_complete records transition extras after two frames', (
    tester,
  ) async {
    StartupTrace.beginProcess();
    await tester.pumpWidget(const SizedBox());
    NavigationTrace.begin(source: 'dashboard', target: 'proxies', kind: 'tab');
    NavigationTrace.noteMount('proxies');
    NavigationTrace.noteBuild('proxies', keepAlive: true);
    NavigationTrace.markAnimateStart(mode: 'animate', durationMs: 280);
    NavigationTrace.markAnimationComplete();
    NavigationTrace.complete(reason: 'settled');

    final extras = NavigationTrace.lastCompleteExtras;
    expect(extras, isNotNull);
    expect(extras!['source'], 'dashboard');
    expect(extras['target'], 'proxies');
    expect(extras['kind'], 'tab');
    expect(extras['mode'], 'animate');
    expect(extras['visit'], 'first');
    expect(extras['seq'], 1);
    expect(extras['target_first_build_latency_ms'], isNotNull);
    expect(extras['first_build_ms'], extras['target_first_build_latency_ms']);
    expect(extras['budget_ms'], isNot(equals('16.67')));
  });

  testWidgets('hotspot counters only increment while a transition is active', (
    tester,
  ) async {
    StartupTrace.beginProcess();
    await tester.pumpWidget(const SizedBox());
    NavigationTrace.noteHotspotBuild('dashboard_view');
    NavigationTrace.begin(source: 'proxies', target: 'dashboard', kind: 'tab');
    NavigationTrace.noteHotspotBuild('dashboard_view');
    NavigationTrace.noteHotspotBuild('dashboard_hero');
    NavigationTrace.noteHotspotBuild('network_overview');
    NavigationTrace.noteHotspotEvent('traffic_history_update');
    NavigationTrace.noteHotspotEvent('latency_setState');
    NavigationTrace.complete(reason: 'settled');

    final extras = NavigationTrace.lastCompleteExtras!;
    expect(
      extras['hotspot_builds'],
      'dashboard_hero:1,dashboard_view:1,network_overview:1',
    );
    expect(
      extras['hotspot_events'],
      'latency_setState:1,traffic_history_update:1',
    );
  });
}
