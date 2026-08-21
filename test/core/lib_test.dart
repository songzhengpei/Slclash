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
}
