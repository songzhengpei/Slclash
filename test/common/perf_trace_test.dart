import 'package:fl_clash/common/perf_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(StartupTrace.resetForTest);

  test('startup marks are enabled in tests and do not throw', () {
    expect(StartupTrace.enabled, isTrue);
    StartupTrace.beginProcess();
    StartupTrace.mark('system.version');
    StartupTrace.mark('first_frame');
    StartupTrace.finish('main_ready');
    expect(StartupTrace.elapsedMs, greaterThanOrEqualTo(0));
  });

  test('beginProcess is idempotent', () {
    StartupTrace.beginProcess();
    final first = StartupTrace.elapsedMs;
    StartupTrace.beginProcess();
    expect(StartupTrace.elapsedMs, greaterThanOrEqualTo(first));
  });
}
