import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/connection/connections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldRefreshConnectionsView', () {
    test('refreshes when desktop connections page is active', () {
      expect(
        shouldRefreshConnectionsView(
          appForeground: true,
          isStart: true,
          isSuspended: false,
          currentPageLabel: PageLabel.connections,
          isMobileView: false,
        ),
        true,
      );
    });

    test(
      'refreshes when mobile tools secondary connections view is mounted',
      () {
        expect(
          shouldRefreshConnectionsView(
            appForeground: true,
            isStart: true,
            isSuspended: false,
            currentPageLabel: PageLabel.tools,
            isMobileView: true,
          ),
          true,
        );
      },
    );

    test('does not refresh inactive or stopped states', () {
      expect(
        shouldRefreshConnectionsView(
          appForeground: true,
          isStart: true,
          isSuspended: false,
          currentPageLabel: PageLabel.tools,
          isMobileView: false,
        ),
        false,
      );
      expect(
        shouldRefreshConnectionsView(
          appForeground: true,
          isStart: false,
          isSuspended: false,
          currentPageLabel: PageLabel.connections,
          isMobileView: true,
        ),
        false,
      );
      expect(
        shouldRefreshConnectionsView(
          appForeground: true,
          isStart: true,
          isSuspended: true,
          currentPageLabel: PageLabel.connections,
          isMobileView: true,
        ),
        false,
      );
    });
  });
}
