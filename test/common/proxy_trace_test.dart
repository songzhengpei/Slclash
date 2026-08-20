import 'package:fl_clash/common/iterable.dart';
import 'package:fl_clash/common/proxy_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ProxyTrace.resetForTest);

  test('eager list count is headers plus expanded proxies', () {
    expect(
      ProxyTrace.eagerWidgetCount(headers: 4, expandedProxies: 300),
      304,
    );
    expect(
      ProxyTrace.eagerWidgetCount(headers: 2, expandedProxies: 500),
      502,
    );
  });

  test('map-toList starts every delay future before batch await', () async {
    var started = 0;
    var inflight = 0;
    var peak = 0;

    Future<void> job() async {
      started += 1;
      inflight += 1;
      if (inflight > peak) {
        peak = inflight;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      inflight -= 1;
    }

    final delayProxies = List<Future<void>>.generate(20, (_) => job());
    expect(started, 20);
    final batches = delayProxies.batch(5);
    expect(batches.length, 4);
    for (final batch in batches) {
      await Future.wait(batch);
    }
    expect(peak, 20);
  });
}
