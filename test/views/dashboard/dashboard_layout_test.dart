import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/views/dashboard/widgets/network_overview_card.dart';
import 'package:fl_clash/views/dashboard/widgets/surge_dashboard_hero.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardResponsiveLayout _layout(double width, {double textScale = 1}) {
  return DashboardResponsiveLayout.fromViewport(
    viewportWidth: width,
    textScaler: TextScaler.linear(textScale),
  );
}

void main() {
  test('dashboard surfaces consume the same responsive layout contract', () {
    final layout = _layout(384);
    final hero = SurgeDashboardHero(layout: layout);
    final network = SurgeNetworkOverviewCard(layout: layout);

    expect(hero.layout, same(layout));
    expect(network.layout, same(layout));
    expect(const DashboardView(), isA<DashboardView>());
  });

  group('DashboardResponsiveLayout', () {
    test('uses the measured 384dp phone as the visual baseline', () {
      final layout = _layout(384);

      expect(layout.density, DashboardDensity.regular);
      expect(layout.geometryScale, 1);
      expect(layout.typographyScale, 1);
      expect(layout.requiresReflow, isFalse);
    });

    test('keeps the 360dp phone on the single-line layout', () {
      final layout = _layout(360);

      expect(layout.density, DashboardDensity.regular);
      expect(layout.geometryScale, 0.9375);
      expect(layout.typographyScale, 0.9375);
      expect(layout.requiresReflow, isFalse);
    });

    test('uses compact density without reflowing a 320dp phone', () {
      final layout = _layout(320);

      expect(layout.density, DashboardDensity.compact);
      expect(layout.cardInnerWidth, greaterThan(230));
      expect(layout.requiresReflow, isFalse);
    });

    test('reflows only when the card cannot retain its primary rows', () {
      final layout = _layout(225);

      expect(layout.cardInnerWidth, lessThan(230));
      expect(layout.requiresReflow, isTrue);
    });

    test('uses a centered, bounded single column on wide screens', () {
      final layout = _layout(800);

      expect(layout.density, DashboardDensity.wide);
      expect(layout.contentMaxWidth, 520);
      expect(layout.geometryScale, 1.07);
      expect(layout.requiresReflow, isFalse);
    });

    test('reflows for enlarged system text at any supported phone width', () {
      final layout = _layout(384, textScale: 1.3);

      expect(layout.density, DashboardDensity.regular);
      expect(layout.requiresReflow, isTrue);
      expect(
        layout.heroNaturalHeight,
        greaterThan(_layout(384).heroNaturalHeight),
      );
      expect(
        NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(layout),
        greaterThan(
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            _layout(384),
          ),
        ),
      );
    });
  });

  group('NetworkOverviewCardLayoutCalculator', () {
    test('uses natural token sizes at its natural outer height', () {
      final responsiveLayout = _layout(384);
      final naturalOuterHeight =
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            responsiveLayout,
          );
      final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight,
        responsiveLayout: responsiveLayout,
      );

      expect(
        layout.chartHeight,
        NetworkOverviewCardLayoutCalculator.chartHeightFor(responsiveLayout),
      );
      expect(
        layout.detectionSlotHeight,
        NetworkOverviewCardLayoutCalculator.detectionSlotHeightFor(
          responsiveLayout,
        ),
      );
    });

    test('keeps normal-phone content at its original vertical positions', () {
      final responsiveLayout = _layout(384);
      final naturalOuterHeight =
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            responsiveLayout,
          );
      final base = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight,
        responsiveLayout: responsiveLayout,
      );
      final expanded = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight + 100,
        responsiveLayout: responsiveLayout,
      );

      expect(expanded.chartHeight, base.chartHeight);
      expect(expanded.headerToChartGap, base.headerToChartGap);
      expect(expanded.latencyRowGap, base.latencyRowGap);
      expect(
        expanded.detectionSlotHeight - base.detectionSlotHeight,
        closeTo(100, 0.001),
      );
    });

    test('distributes additional height across wide-screen content', () {
      final responsiveLayout = _layout(800);
      final naturalOuterHeight =
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            responsiveLayout,
          );
      final base = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight,
        responsiveLayout: responsiveLayout,
      );
      final expanded = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight + 100,
        responsiveLayout: responsiveLayout,
      );

      expect(expanded.chartHeight - base.chartHeight, closeTo(40, 0.001));
      expect(
        expanded.detectionSlotHeight - base.detectionSlotHeight,
        closeTo(15, 0.001),
      );
    });

    test('never shrinks below natural content height', () {
      final responsiveLayout = _layout(360);
      final naturalOuterHeight =
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            responsiveLayout,
          );
      final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight - 80,
        responsiveLayout: responsiveLayout,
      );

      expect(
        layout.chartHeight,
        NetworkOverviewCardLayoutCalculator.chartHeightFor(responsiveLayout),
      );
      expect(
        layout.detectionSlotHeight,
        NetworkOverviewCardLayoutCalculator.detectionSlotHeightFor(
          responsiveLayout,
        ),
      );
    });
  });
}
