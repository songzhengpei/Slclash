import 'package:fl_clash/common/core_ipc_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CoreIpcTrace.resetForTest);

  test('disabled path is not required: enabled in tests', () {
    expect(CoreIpcTrace.enabled, isTrue);
  });

  test('same-method overlap increments when a second invoke starts', () async {
    CoreIpcTrace.beginWindow(page: 'dashboard');
    late Future<String?> second;
    final first = CoreIpcTrace.run<String>(
      id: 'getTrafficSnapshot#1',
      method: 'getTrafficSnapshot',
      body: () async {
        second = CoreIpcTrace.run<String>(
          id: 'getTrafficSnapshot#2',
          method: 'getTrafficSnapshot',
          body: () async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            CoreIpcTrace.classify('getTrafficSnapshot#2', 'success');
            return '{}';
          },
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        CoreIpcTrace.classify('getTrafficSnapshot#1', 'success');
        return '{}';
      },
    );
    await first;
    await second;
    expect(CoreIpcTrace.globalPeak, greaterThanOrEqualTo(2));
    expect(CoreIpcTrace.overlapCounts['getTrafficSnapshot'], 1);
    expect(CoreIpcTrace.methodPeak['getTrafficSnapshot'], 2);
    expect(CoreIpcTrace.requestCounts['getTrafficSnapshot'], 2);
  });

  test('transport null classification is explicit', () async {
    final out = await CoreIpcTrace.run<String>(
      id: 'changeProxy#1',
      method: 'changeProxy',
      body: () async {
        CoreIpcTrace.classify('changeProxy#1', 'transport_null_or_timeout');
        return null;
      },
    );
    expect(out, isNull);
    expect(CoreIpcTrace.resultCounts['transport_null_or_timeout'], 1);
  });

  test('ring buffer stays bounded', () async {
    for (var i = 0; i < 80; i++) {
      await CoreIpcTrace.run<String>(
        id: 'getMemory#$i',
        method: 'getMemory',
        body: () async {
          CoreIpcTrace.classify('getMemory#$i', 'success');
          return '1';
        },
      );
    }
    final snap = CoreIpcTrace.snapshot();
    expect(CoreIpcTrace.requestCounts['getMemory'], 80);
    expect((snap['durations'] as Map)['getMemory'], hasLength(80));
  });

  test('noteNotReady does not bump inflight', () {
    CoreIpcTrace.noteNotReady('getProxies');
    expect(CoreIpcTrace.globalInflight, 0);
    expect(CoreIpcTrace.resultCounts['core_not_ready'], 1);
  });
}
