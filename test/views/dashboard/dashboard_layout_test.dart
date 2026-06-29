import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/widgets/network_overview_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardAdaptiveLayout', () {
    test('keeps the overview card at baseline scale for 384dp', () {
      final layout = DashboardAdaptiveLayout.overviewLayoutFor(384);

      expect(layout.scale, 1);
    });

    test('increases only the overview card scale above 384dp', () {
      final layout = DashboardAdaptiveLayout.overviewLayoutFor(410);

      expect(layout.scale, greaterThan(1));
      expect(layout.scale, lessThanOrEqualTo(DashboardAdaptiveLayout.maxScale));
    });

    test('shrinks only the overview card scale below 384dp', () {
      final layout = DashboardAdaptiveLayout.overviewLayoutFor(360);

      expect(layout.scale, lessThan(1));
      expect(
        layout.scale,
        greaterThanOrEqualTo(DashboardAdaptiveLayout.minScale),
      );
    });
  });

  group('NetworkOverviewCardLayoutCalculator', () {
    test('uses natural sizes when the card has no extra height', () {
      const scale = 1.0;
      final naturalHeight =
          NetworkOverviewCardLayoutCalculator.naturalInnerHeightFor(scale);
      final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableInnerHeight: naturalHeight,
        scale: scale,
      );

      expect(
        layout.chartHeight,
        NetworkOverviewCardLayoutCalculator.chartBaseHeight,
      );
      expect(
        layout.afterTrafficGap,
        NetworkOverviewCardLayoutCalculator.trafficToDividerBaseGap,
      );
    });

    test('distributes 410dp extra height into chart and middle content', () {
      final scale = DashboardAdaptiveLayout.scaleForShortestSide(410);
      final naturalHeight =
          NetworkOverviewCardLayoutCalculator.naturalInnerHeightFor(scale);
      final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableInnerHeight: naturalHeight + 80,
        scale: scale,
      );

      expect(
        layout.chartHeight,
        greaterThan(
          NetworkOverviewCardLayoutCalculator.chartBaseHeight * scale,
        ),
      );
      expect(
        layout.trafficTitleToChartGap,
        greaterThan(
          NetworkOverviewCardLayoutCalculator.trafficTitleToChartBaseGap *
              scale,
        ),
      );
      expect(
        layout.latencyHeaderToRowsGap,
        greaterThan(
          NetworkOverviewCardLayoutCalculator.latencyHeaderToRowsBaseGap *
              scale,
        ),
      );
      expect(
        layout.afterTrafficGap,
        greaterThan(
          NetworkOverviewCardLayoutCalculator.trafficToDividerBaseGap * scale,
        ),
      );
    });

    test(
      'does not shrink below natural sizes when available height is tight',
      () {
        const scale = 0.92;
        final naturalHeight =
            NetworkOverviewCardLayoutCalculator.naturalInnerHeightFor(scale);
        final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
          availableInnerHeight: naturalHeight - 40,
          scale: scale,
        );

        expect(
          layout.chartHeight,
          NetworkOverviewCardLayoutCalculator.chartBaseHeight * scale,
        );
        expect(
          layout.trafficTitleToChartGap,
          NetworkOverviewCardLayoutCalculator.trafficTitleToChartBaseGap *
              scale,
        );
      },
    );
  });
}
