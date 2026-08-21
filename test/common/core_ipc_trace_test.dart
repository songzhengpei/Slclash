import 'package:fl_clash/common/core_ipc_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CoreIpcTrace.resetForTest);

  test('disabled path is not required: enabled in tests', () {
    expect(CoreIpcTrace.enabled, isTrue);
  });

  test('beginWindow does not clear live inflight or classification', () async {
    CoreIpcTrace.beginRun(id: 'r1');
    final hanging = CoreIpcTrace.run<String>(
      id: 'getTrafficSnapshot#live',
      method: 'getTrafficSnapshot',
      body: () async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        CoreIpcTrace.classify('getTrafficSnapshot#live', 'success');
        return '{}';
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(CoreIpcTrace.globalInflight, 1);
    CoreIpcTrace.beginWindow(page: 'dashboard');
    expect(CoreIpcTrace.globalInflight, 1);
    expect(CoreIpcTrace.inflightAtWindowStart, 1);
    expect(CoreIpcTrace.requestCounts['getTrafficSnapshot'], isNull);
    await hanging;
    expect(CoreIpcTrace.globalInflight, 0);
  });

  test('same-method overlap increments when a second invoke starts', () async {
    CoreIpcTrace.beginRun(id: 'r1');
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
    expect(CoreIpcTrace.windowId, 'r1-w1');
  });

  test('transport null classification is explicit', () async {
    CoreIpcTrace.beginWindow(page: 't');
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
    CoreIpcTrace.beginWindow(page: 't');
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

  test('noteNotReady records preinvoke wait and does not bump inflight', () {
    CoreIpcTrace.beginWindow(page: 't');
    CoreIpcTrace.noteNotReady('getProxies', preinvokeWaitMs: 10000);
    expect(CoreIpcTrace.globalInflight, 0);
    expect(CoreIpcTrace.resultCounts['core_not_ready'], 1);
    expect(CoreIpcTrace.requestCounts['getProxies'], isNull);
  });
}
