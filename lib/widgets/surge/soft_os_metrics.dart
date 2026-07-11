import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Responsive sizing for the Soft OS control family.
///
/// 384dp at text scale 1.0 is the visual baseline. This matches the reference
/// Android device (1080px at 450dpi). Display-size/minimum-width changes are
/// reflected by [MediaQuery.sizeOf], while accessibility text scaling receives
/// a moderated contribution so labels keep breathing room without becoming
/// disproportionately tall.
class SoftOsMetrics {
  const SoftOsMetrics._({required this.scale});

  static const double baselineShortestSide = 384;
  static const double minimumTapExtent = 44;

  final double scale;

  factory SoftOsMetrics.of(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final viewportScale = (shortestSide / baselineShortestSide).clamp(
      0.88,
      1.18,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final typographyScale = (1 + (textScale - 1) * 0.5).clamp(0.92, 1.22);
    return SoftOsMetrics._(
      scale: (viewportScale * typographyScale).clamp(0.86, 1.28),
    );
  }

  double value(double baseline) => baseline * scale;

  double tap(double baseline) => math.max(minimumTapExtent, value(baseline));
}
