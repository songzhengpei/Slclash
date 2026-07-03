import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/core_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldCollectCoreLogs', () {
    test('collects logs only on foreground logs page when enabled', () {
      expect(
        shouldCollectCoreLogs(
          openLogs: true,
          appForeground: true,
          currentPageLabel: PageLabel.logs,
        ),
        isTrue,
      );
    });

    test('does not collect logs when setting is disabled', () {
      expect(
        shouldCollectCoreLogs(
          openLogs: false,
          appForeground: true,
          currentPageLabel: PageLabel.logs,
        ),
        isFalse,
      );
    });

    test('does not collect logs outside logs page', () {
      expect(
        shouldCollectCoreLogs(
          openLogs: true,
          appForeground: true,
          currentPageLabel: PageLabel.dashboard,
        ),
        isFalse,
      );
    });

    test('does not collect logs in background', () {
      expect(
        shouldCollectCoreLogs(
          openLogs: true,
          appForeground: false,
          currentPageLabel: PageLabel.logs,
        ),
        isFalse,
      );
    });
  });

  group('shouldCollectCoreRequests', () {
    test('collects request events only on foreground requests page', () {
      expect(
        shouldCollectCoreRequests(
          appForeground: true,
          currentPageLabel: PageLabel.requests,
        ),
        isTrue,
      );
    });

    test('does not collect request events outside requests page', () {
      expect(
        shouldCollectCoreRequests(
          appForeground: true,
          currentPageLabel: PageLabel.dashboard,
        ),
        isFalse,
      );
    });

    test('does not collect request events in background', () {
      expect(
        shouldCollectCoreRequests(
          appForeground: false,
          currentPageLabel: PageLabel.requests,
        ),
        isFalse,
      );
    });
  });
}
