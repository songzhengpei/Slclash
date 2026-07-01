import 'package:fl_clash/core/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('core event batch parsing', () {
    test('parses a single log event payload', () {
      final logs = parseCoreEventLogs({
        'LogLevel': 'info',
        'Payload': 'single',
      });

      expect(logs.map((log) => log.payload), ['single']);
    });

    test('parses a list log event payload', () {
      final logs = parseCoreEventLogs([
        {'LogLevel': 'info', 'Payload': 'first'},
        {'LogLevel': 'warning', 'Payload': 'second'},
      ]);

      expect(logs.map((log) => log.payload), ['first', 'second']);
    });

    test('parses an items log event payload', () {
      final logs = parseCoreEventLogs({
        'items': [
          {'LogLevel': 'info', 'Payload': 'first'},
          {'LogLevel': 'error', 'Payload': 'second'},
        ],
      });

      expect(logs.map((log) => log.payload), ['first', 'second']);
    });
  });
}
