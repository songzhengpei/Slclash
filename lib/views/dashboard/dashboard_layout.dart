import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The three density modes used by every dashboard surface.
enum DashboardDensity { compact, regular, wide }

/// Immutable, page-level responsive contract for the dashboard.
///
/// The reference viewport is the user's 450dp-wide phone.  Geometry and type
/// are deliberately scaled independently: compact phones keep readable type
/// while their visual chrome does not become disproportionately large.
@immutable
class DashboardResponsiveLayout {
  const DashboardResponsiveLayout._({
    required this.density,
    required this.geometryScale,
    required this.typographyScale,
    required this.textScale,
    required this.pageHorizontalPadding,
    required this.pageTopPadding,
    required this.cardGap,
    required this.contentMaxWidth,
    required this.cardInnerWidth,
    required this.requiresReflow,
  });

  static const double referenceViewportWidth = 450;
  static const double compactBreakpoint = 376;
  static const double wideBreakpoint = 600;
  static const double wideContentMaxWidth = 520;
  static const double reflowCardInnerWidth = 280;
  static const double referenceLegacyScale = 450 / 384;

  final DashboardDensity density;
  final double geometryScale;
  final double typographyScale;
  final double textScale;
  final double pageHorizontalPadding;
  final double pageTopPadding;
  final double cardGap;
  final double contentMaxWidth;
  final double cardInnerWidth;
  final bool requiresReflow;

  bool get isCompact => density == DashboardDensity.compact;
  bool get isWide => density == DashboardDensity.wide;

  /// Scales a visual token whose reference value is measured on the 450dp
  /// reference viewport.
  double geometry(double referenceValue) => referenceValue * geometryScale;

  /// Scales a typography token before Flutter applies the system TextScaler.
  double type(double referenceValue) => referenceValue * typographyScale;

  /// Preserves dimensions which previously used `value * layoutScale` at the
  /// reference viewport, while making that scaling shared by both cards.
  double legacy(double value) => value * referenceLegacyScale * geometryScale;

  /// Equivalent to [legacy], but uses the more conservative type scale.
  double legacyType(double value) =>
      value * referenceLegacyScale * typographyScale;

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
    final geometryScale = widthRatio.clamp(0.82, 1.07).toDouble();
    final typographyScale = widthRatio.clamp(0.90, 1.05).toDouble();
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
      geometryScale: geometryScale,
      typographyScale: typographyScale,
      textScale: textScale,
      pageHorizontalPadding: pageHorizontalPadding,
      pageTopPadding: 16 * geometryScale,
      cardGap: 16 * geometryScale,
      contentMaxWidth: isWide ? wideContentMaxWidth : double.infinity,
      cardInnerWidth: cardInnerWidth,
      requiresReflow: cardInnerWidth < reflowCardInnerWidth || textScale > 1.15,
    );
  }
}
