import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/views/dashboard/widgets/network_overview_card.dart';
import 'package:fl_clash/views/dashboard/widgets/surge_dashboard_hero.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardResponsiveLayout _layout(
  double width, {
  double height = DashboardResponsiveLayout.referenceViewportHeight,
  double textScale = 1,
}) {
  return DashboardResponsiveLayout.fromViewport(
    viewportWidth: width,
    viewportHeight: height,
    textScaler: TextScaler.linear(textScale),
  );
}

DashboardResponsiveLayout _layoutForViewportHeight(double viewportHeight) {
  return _layout(384, height: viewportHeight);
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
      expect(layout.viewportExpansionFraction, 0);
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
      expect(layout.viewportExpansionFraction, 0);
    });

    test('shares an FHD and WQHD baseline logical viewport', () {
      final fhd = _layout(384, height: 853.3333333333334);
      final wqhd = _layout(384, height: 853.3333333333334);

      expect(fhd.geometryScale, wqhd.geometryScale);
      expect(fhd.heroNaturalHeight, wqhd.heroNaturalHeight);
      expect(fhd.viewportExpansionFraction, 0);
      expect(wqhd.viewportExpansionFraction, 0);
    });

    test(
      'begins bounded expansion only above the reference viewport height',
      () {
        expect(
          _layoutForViewportHeight(
            DashboardResponsiveLayout.referenceViewportHeight,
          ).viewportExpansionFraction,
          0,
        );
        expect(
          _layoutForViewportHeight(
            DashboardResponsiveLayout.referenceViewportHeight + 24,
          ).viewportExpansionFraction,
          0.5,
        );
        expect(
          _layoutForViewportHeight(
            DashboardResponsiveLayout.referenceViewportHeight + 48,
          ).viewportExpansionFraction,
          1,
        );
        expect(
          _layoutForViewportHeight(
            DashboardResponsiveLayout.referenceViewportHeight + 96,
          ).viewportExpansionFraction,
          1,
        );
      },
    );

    test('keeps the reference device on the legacy vertical allocation', () {
      final layout = _layout(384);
      const networkNaturalHeight = 372.0;
      final naturalContentHeight =
          layout.heroNaturalHeight + layout.cardGap + networkNaturalHeight;
      final allocation = layout.resolvePageHeightAllocation(
        availableContentHeight: naturalContentHeight + 100,
        networkNaturalHeight: networkNaturalHeight,
      );

      expect(allocation.heroHeight, layout.heroNaturalHeight);
      expect(allocation.networkHeight, networkNaturalHeight + 100);
      expect(allocation.networkContentExpansionFraction, 0);
    });

    test('gradually shares bounded surplus above the reference viewport', () {
      final layout = _layoutForViewportHeight(
        DashboardResponsiveLayout.referenceViewportHeight + 24,
      );
      const networkNaturalHeight = 372.0;
      final naturalContentHeight =
          layout.heroNaturalHeight + layout.cardGap + networkNaturalHeight;
      final allocation = layout.resolvePageHeightAllocation(
        availableContentHeight: naturalContentHeight + 60,
        networkNaturalHeight: networkNaturalHeight,
      );

      expect(
        allocation.heroHeight - layout.heroNaturalHeight,
        closeTo(10.2, 0.001),
      );
      expect(
        allocation.networkHeight - networkNaturalHeight,
        closeTo(49.8, 0.001),
      );
      expect(allocation.networkContentExpansionFraction, 0.5);
    });

    test('returns to two natural cards when expansion would be too loose', () {
      final layout = _layoutForViewportHeight(
        DashboardResponsiveLayout.referenceViewportHeight + 96,
      );
      const networkNaturalHeight = 372.0;
      final naturalContentHeight =
          layout.heroNaturalHeight + layout.cardGap + networkNaturalHeight;
      final allocation = layout.resolvePageHeightAllocation(
        availableContentHeight:
            naturalContentHeight + layout.maxDashboardExpansion + 1,
        networkNaturalHeight: networkNaturalHeight,
      );

      expect(allocation.heroHeight, layout.heroNaturalHeight);
      expect(allocation.networkHeight, networkNaturalHeight);
      expect(allocation.networkContentExpansionFraction, 0);
    });

    test('spreads an allocated hero height through its visual sections', () {
      final layout = _layoutForViewportHeight(
        DashboardResponsiveLayout.referenceViewportHeight + 48,
      );
      final hero = DashboardHeroLayoutCalculator.layoutFor(
        responsiveLayout: layout,
        availableOuterHeight: layout.heroNaturalHeight + 100,
      );

      expect(hero.topRowToModeGap - layout.legacy(16), closeTo(32, 0.001));
      expect(hero.modeCardHeight - layout.legacy(80), closeTo(38, 0.001));
      expect(hero.modeToSwitchGap - layout.legacy(12), closeTo(16, 0.001));
      expect(hero.switchToSelectorGap - layout.legacy(10), closeTo(14, 0.001));
    });

    test('caps enlarged dashboard text without changing the primary rows', () {
      final layout = _layout(384, textScale: 1.3);

      expect(layout.density, DashboardDensity.regular);
      expect(layout.requiresReflow, isFalse);
      expect(
        DashboardResponsiveLayout.textScalerForDashboard(
          const TextScaler.linear(2),
        ).scale(12),
        closeTo(13.8, 0.001),
      );
      expect(DashboardResponsiveLayout.scrollEndBottomGap, 30);
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
        contentExpansionFraction: 0,
      );

      expect(
        layout.chartHeight,
        NetworkOverviewCardLayoutCalculator.chartHeightFor(responsiveLayout),
      );
      expect(layout.detectionTopGap, 16);
      expect(layout.detectionBottomGap, 16);
    });

    test('keeps the detection bar vertically balanced on compact phones', () {
      final responsiveLayout = _layout(360, height: 800);
      final naturalOuterHeight =
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            responsiveLayout,
          );
      final base = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight,
        responsiveLayout: responsiveLayout,
        contentExpansionFraction: 0,
      );
      final expanded = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight + 100,
        responsiveLayout: responsiveLayout,
        contentExpansionFraction: 0,
      );

      expect(expanded.chartHeight, base.chartHeight);
      expect(expanded.headerToChartGap, base.headerToChartGap);
      expect(expanded.latencyRowGap, base.latencyRowGap);
      expect(expanded.detectionTopGap, 16);
      expect(expanded.detectionBottomGap, 16);
      expect(
        expanded.afterTrafficGap - base.afterTrafficGap,
        closeTo(100, 0.001),
      );
    });

    test('keeps detection padding fixed during partial expansion', () {
      final responsiveLayout = _layoutForViewportHeight(
        DashboardResponsiveLayout.referenceViewportHeight + 24,
      );
      final naturalOuterHeight =
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            responsiveLayout,
          );
      final base = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight,
        responsiveLayout: responsiveLayout,
        contentExpansionFraction: 0.5,
      );
      final expanded = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight + 100,
        responsiveLayout: responsiveLayout,
        contentExpansionFraction: 0.5,
      );

      expect(expanded.chartHeight - base.chartHeight, closeTo(20, 0.001));
      expect(expanded.detectionTopGap, 16);
      expect(expanded.detectionBottomGap, 16);
      expect(
        expanded.afterTrafficGap - base.afterTrafficGap,
        closeTo(58.5, 0.001),
      );
    });

    test(
      'uses the full internal distribution once the viewport ramp completes',
      () {
        final responsiveLayout = _layoutForViewportHeight(
          DashboardResponsiveLayout.referenceViewportHeight + 48,
        );
        final naturalOuterHeight =
            NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
              responsiveLayout,
            );
        final base = NetworkOverviewCardLayoutCalculator.layoutFor(
          availableOuterHeight: naturalOuterHeight,
          responsiveLayout: responsiveLayout,
          contentExpansionFraction: 1,
        );
        final expanded = NetworkOverviewCardLayoutCalculator.layoutFor(
          availableOuterHeight: naturalOuterHeight + 100,
          responsiveLayout: responsiveLayout,
          contentExpansionFraction: 1,
        );

        expect(expanded.chartHeight - base.chartHeight, closeTo(40, 0.001));
        expect(
          expanded.afterTrafficGap - base.afterTrafficGap,
          closeTo(17, 0.001),
        );
        expect(expanded.detectionTopGap, 16);
        expect(expanded.detectionBottomGap, 16);
      },
    );

    test('never shrinks below natural content height', () {
      final responsiveLayout = _layout(360);
      final naturalOuterHeight =
          NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
            responsiveLayout,
          );
      final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
        availableOuterHeight: naturalOuterHeight - 80,
        responsiveLayout: responsiveLayout,
        contentExpansionFraction: 0,
      );

      expect(
        layout.chartHeight,
        NetworkOverviewCardLayoutCalculator.chartHeightFor(responsiveLayout),
      );
      expect(layout.detectionTopGap, 16);
      expect(layout.detectionBottomGap, 16);
    });
  });
}
