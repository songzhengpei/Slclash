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
    final layout = _layout(450);
    final hero = SurgeDashboardHero(layout: layout);
    final network = SurgeNetworkOverviewCard(layout: layout);

    expect(hero.layout, same(layout));
    expect(network.layout, same(layout));
    expect(const DashboardView(), isA<DashboardView>());
  });

  group('DashboardResponsiveLayout', () {
    test('uses the 450dp reference phone as the visual baseline', () {
      final layout = _layout(450);

      expect(layout.density, DashboardDensity.regular);
      expect(layout.geometryScale, 1);
      expect(layout.typographyScale, 1);
      expect(layout.requiresReflow, isFalse);
    });

    test('uses compact visual density without reflowing a 360dp phone', () {
      final layout = _layout(360);

      expect(layout.density, DashboardDensity.compact);
      expect(layout.geometryScale, 0.82);
      expect(layout.typographyScale, 0.9);
      expect(layout.requiresReflow, isFalse);
    });

    test('reflows the card when a narrow phone cannot keep both columns', () {
      final layout = _layout(320);

      expect(layout.density, DashboardDensity.compact);
      expect(layout.cardInnerWidth, lessThan(280));
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
      final layout = _layout(450, textScale: 1.3);

      expect(layout.density, DashboardDensity.regular);
      expect(layout.requiresReflow, isTrue);
      expect(
        layout.heroNaturalHeight,
        greaterThan(_layout(450).heroNaturalHeight),
      );
      expect(
        NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(layout),
        greaterThan(
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            _layout(450),
          ),
        ),
      );
    });
  });

  group('NetworkOverviewCardLayoutCalculator', () {
    test('uses natural token sizes at its natural outer height', () {
      final responsiveLayout = _layout(450);
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

    test('distributes additional height across the whole card', () {
      final responsiveLayout = _layout(450);
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
        expanded.headerToChartGap - base.headerToChartGap,
        closeTo(10, 0.001),
      );
      expect(expanded.latencyRowGap - base.latencyRowGap, closeTo(2, 0.001));
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
