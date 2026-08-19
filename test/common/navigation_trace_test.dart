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
    expect(extras['budget_ms'], isNot(equals('16.67')));
  });
}
