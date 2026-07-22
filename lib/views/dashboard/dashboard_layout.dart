import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The three density modes used by every dashboard surface.
enum DashboardDensity { compact, regular, wide }

@immutable
class DashboardPageHeightAllocation {
  const DashboardPageHeightAllocation({
    required this.heroHeight,
    required this.networkHeight,
    required this.networkContentExpansionFraction,
  });

  final double heroHeight;
  final double networkHeight;
  final double networkContentExpansionFraction;

  bool get hasHeroExpansion => networkContentExpansionFraction > 0;
}

@immutable
class DashboardHeroContentLayout {
  const DashboardHeroContentLayout({
    required this.topRowToModeGap,
    required this.modeCardHeight,
    required this.modeToSwitchGap,
    required this.switchToSelectorGap,
  });

  final double topRowToModeGap;
  final double modeCardHeight;
  final double modeToSwitchGap;
  final double switchToSelectorGap;
}

class DashboardHeroLayoutCalculator {
  const DashboardHeroLayoutCalculator._();

  static DashboardHeroContentLayout layoutFor({
    required DashboardResponsiveLayout responsiveLayout,
    required double availableOuterHeight,
  }) {
    final naturalOuterHeight = responsiveLayout.heroNaturalHeight;
    final extraHeight = math.max(0, availableOuterHeight - naturalOuterHeight);

    return DashboardHeroContentLayout(
      topRowToModeGap: responsiveLayout.legacy(16) + extraHeight * 0.32,
      modeCardHeight: responsiveLayout.legacy(80) + extraHeight * 0.38,
      modeToSwitchGap: responsiveLayout.legacy(12) + extraHeight * 0.16,
      switchToSelectorGap: responsiveLayout.legacy(12) + extraHeight * 0.14,
    );
  }
}

/// Immutable, page-level responsive contract for the dashboard.
///
/// The reference viewport is the user's 384dp-wide phone. Geometry remains
/// responsive here; typography is owned by the app's semantic text system.
@immutable
class DashboardResponsiveLayout {
  const DashboardResponsiveLayout._({
    required this.density,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.geometryScale,
    required this.textScale,
    required this.pageHorizontalPadding,
    required this.pageTopPadding,
    required this.cardGap,
    required this.contentMaxWidth,
    required this.cardInnerWidth,
    required this.requiresReflow,
  });

  static const double referenceViewportWidth = 384;
  static const double referenceViewportHeight = 853.3333333333334;
  static const double compactBreakpoint = 360;
  static const double wideBreakpoint = 600;
  static const double wideContentMaxWidth = 520;
  static const double reflowCardInnerWidth = 230;
  static const double scrollEndBottomGap = 30;
  static const double viewportExpansionRampHeight = 48;
  static const double maxHeroExpansion = 24;
  static const double maxNetworkExpansion = 60;
  static const double heroExtraHeightFraction = 0.34;

  final DashboardDensity density;
  final double viewportWidth;
  final double viewportHeight;
  final double geometryScale;
  final double textScale;
  final double pageHorizontalPadding;
  final double pageTopPadding;
  final double cardGap;
  final double contentMaxWidth;
  final double cardInnerWidth;
  final bool requiresReflow;

  bool get isCompact => density == DashboardDensity.compact;
  bool get isWide => density == DashboardDensity.wide;

  double get maxDashboardExpansion =>
      geometry(maxHeroExpansion + maxNetworkExpansion);

  /// FHD and WQHD use different physical pixel densities on the same phone,
  /// but their default logical viewport is identical.  Expansion therefore
  /// follows available logical height rather than physical density.
  double get viewportExpansionFraction {
    if (isWide || requiresReflow) return 0;
    return ((viewportHeight - referenceViewportHeight) /
            viewportExpansionRampHeight)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  DashboardPageHeightAllocation resolvePageHeightAllocation({
    required double availableContentHeight,
    required double networkNaturalHeight,
  }) {
    final naturalContentHeight =
        heroNaturalHeight + cardGap + networkNaturalHeight;
    final resolvedContentHeight = math.max(
      availableContentHeight,
      naturalContentHeight,
    );
    final surplusHeight = resolvedContentHeight - naturalContentHeight;
    final expansionFraction = viewportExpansionFraction;

    if (expansionFraction <= 0) {
      return DashboardPageHeightAllocation(
        heroHeight: heroNaturalHeight,
        networkHeight: math.max(
          networkNaturalHeight,
          resolvedContentHeight - heroNaturalHeight - cardGap,
        ),
        networkContentExpansionFraction: 0,
      );
    }

    if (surplusHeight <= maxDashboardExpansion) {
      final heroExtraHeight =
          surplusHeight * heroExtraHeightFraction * expansionFraction;
      return DashboardPageHeightAllocation(
        heroHeight: heroNaturalHeight + heroExtraHeight,
        networkHeight: networkNaturalHeight + surplusHeight - heroExtraHeight,
        networkContentExpansionFraction: expansionFraction,
      );
    }

    return DashboardPageHeightAllocation(
      heroHeight: heroNaturalHeight,
      networkHeight: networkNaturalHeight,
      networkContentExpansionFraction: 0,
    );
  }

  /// Scales a visual token whose reference value is measured on the 384dp
  /// reference viewport.
  double geometry(double referenceValue) => referenceValue * geometryScale;

  /// Keeps icon geometry in step with the semantic text beside it.
  double textIcon(double referenceValue) =>
      referenceValue * geometryScale * textScale;

  /// Preserves dimensions which previously used `value * layoutScale` at the
  /// reference viewport, while making that scaling shared by both cards.
  double legacy(double value) => value * geometryScale;

  double get cardRadius => geometry(26);
  double get cardHorizontalPadding => geometry(18);

  double get heroNaturalHeight {
    final topRow = legacy(28);
    final reflowExtra = requiresReflow ? legacy(36) : 0.0;
    final textExtra = requiresReflow
        ? legacy(48) * math.max(0, textScale - 1)
        : 0.0;
    return legacy(18) +
        topRow +
        reflowExtra +
        textExtra +
        legacy(16) +
        legacy(80) +
        legacy(12) +
        legacy(34) +
        legacy(10) +
        legacy(34) +
        legacy(16);
  }

  factory DashboardResponsiveLayout.fromViewport({
    required double viewportWidth,
    required double viewportHeight,
    required TextScaler textScaler,
  }) {
    final isWide = viewportWidth > wideBreakpoint;
    final isCompact = viewportWidth < compactBreakpoint;
    final density = isWide
        ? DashboardDensity.wide
        : isCompact
        ? DashboardDensity.compact
        : DashboardDensity.regular;
    final widthRatio = viewportWidth / referenceViewportWidth;
    final geometryScale = widthRatio.clamp(0.86, 1.07).toDouble();
    final pageHorizontalPadding = isWide ? 32.0 : 18 * geometryScale;
    final contentWidth = math
        .min(
          math.max(0, viewportWidth - pageHorizontalPadding * 2),
          isWide ? wideContentMaxWidth : double.infinity,
        )
        .toDouble();
    final cardInnerWidth = math
        .max(0, contentWidth - (18 * geometryScale * 2))
        .toDouble();
    final textScale = textScaler.scale(1.0);

    return DashboardResponsiveLayout._(
      density: density,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      geometryScale: geometryScale,
      textScale: textScale,
      pageHorizontalPadding: pageHorizontalPadding,
      pageTopPadding: 16 * geometryScale,
      cardGap: 16 * geometryScale,
      contentMaxWidth: isWide ? wideContentMaxWidth : double.infinity,
      cardInnerWidth: cardInnerWidth,
      // Only a genuinely narrow card switches to the structural reflow
      // fallback. Text scaling is never capped here.
      requiresReflow: cardInnerWidth < reflowCardInnerWidth,
    );
  }
}
