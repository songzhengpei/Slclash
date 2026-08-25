import 'package:fl_clash/core/lib.dart';
import 'package:fl_clash/core/command_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'full stopListener runs listener stop before native service stop',
    () async {
      final calls = <String>[];

      final result = await stopListenerAndNativeService(
        stopCoreListenerOnly: () async {
          calls.add('listener');
          return true;
        },
        stopNativeService: () async {
          calls.add('service');
          return true;
        },
      );

      expect(result, isTrue);
      expect(calls, ['listener', 'service']);
    },
  );

  test('full stopListener reports native service failure', () async {
    final result = await stopListenerAndNativeService(
      stopCoreListenerOnly: () async => true,
      stopNativeService: () async => false,
    );

    expect(result, isFalse);
  });

  test('listener cleanup failure does not skip native service stop', () async {
    var nativeStopCalled = false;
    final result = await stopListenerAndNativeService(
      stopCoreListenerOnly: () async => throw StateError('listener failed'),
      stopNativeService: () async {
        nativeStopCalled = true;
        return true;
      },
    );

    expect(nativeStopCalled, isTrue);
    expect(result, isTrue);
  });

  test(
    'preload marks connected only after init and sync are confirmed',
    () async {
      var connected = 0;

      final result = await runCorePreloadHandshake(
        initTransport: () async => '',
        syncState: () async => '',
        markConnected: () => connected += 1,
      );

      expect(result, '');
      expect(connected, 1);
    },
  );

  test('preload init null stays unconfirmed and disconnected', () async {
    var connected = false;
    var syncCalled = false;

    final result = await runCorePreloadHandshake(
      initTransport: () async => null,
      syncState: () async {
        syncCalled = true;
        return '';
      },
      markConnected: () => connected = true,
    );

    expect(result, CoreCommandOutcome.unconfirmed);
    expect(syncCalled, isFalse);
    expect(connected, isFalse);
  });

  test('preload sync null stays unconfirmed and disconnected', () async {
    var connected = false;

    final result = await runCorePreloadHandshake(
      initTransport: () async => '',
      syncState: () async => null,
      markConnected: () => connected = true,
    );

    expect(result, CoreCommandOutcome.unconfirmed);
    expect(connected, isFalse);
  });
}
