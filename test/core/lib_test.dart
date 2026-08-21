import 'package:fl_clash/core/lib.dart';
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
}
