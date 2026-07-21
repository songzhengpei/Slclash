import 'package:fl_clash/theme/typography/font_families.dart';
import 'package:fl_clash/theme/typography/type_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the 18 semantic roles match the frozen type scale', () {
    final cases = <(TextStyle, double, double, FontWeight, String?)>[
      (SlclashTypeScale.screenTitle, 19, 1.4737, FontWeight.w500, null),
      (SlclashTypeScale.appBarTitle, 20, 1.3, FontWeight.w600, null),
      (SlclashTypeScale.dialogTitle, 18, 1.3333, FontWeight.w600, null),
      (SlclashTypeScale.sectionTitle, 15, 1.4667, FontWeight.w600, null),
      (SlclashTypeScale.cardTitle, 16, 1.125, FontWeight.w500, null),
      (SlclashTypeScale.rowTitle, 15, 1.4667, FontWeight.w500, null),
      (SlclashTypeScale.body, 15, 1.4667, FontWeight.w400, null),
      (SlclashTypeScale.supporting, 13, 1.2308, FontWeight.w400, null),
      (SlclashTypeScale.controlLabel, 14, 1.4286, FontWeight.w600, null),
      (SlclashTypeScale.navigationLabel, 11, 1.4545, FontWeight.w500, null),
      (SlclashTypeScale.badgeLabel, 11, 1, FontWeight.w600, null),
      (SlclashTypeScale.selectedRowTitle, 15, 1.4667, FontWeight.w600, null),
      (SlclashTypeScale.selectorLabel, 13, 1.2308, FontWeight.w600, null),
      (SlclashTypeScale.metricLarge, 24, 1.25, FontWeight.w600, null),
      (SlclashTypeScale.metric, 14, 1.2857, FontWeight.w600, null),
      (SlclashTypeScale.compactMetric, 13, 1.2308, FontWeight.w400, null),
      (
        SlclashTypeScale.technical,
        13,
        1.3846,
        FontWeight.w500,
        SlclashFontFamilies.jetBrainsMono,
      ),
      (
        SlclashTypeScale.chartLabel,
        10,
        1.4,
        FontWeight.w500,
        SlclashFontFamilies.jetBrainsMono,
      ),
    ];

    expect(cases, hasLength(18));
    for (final (style, size, height, weight, family) in cases) {
      expect(style.fontSize, size);
      expect(style.height, closeTo(height, 0.00001));
      expect(style.fontWeight, weight);
      expect(style.fontFamily, family);
      expect(style.letterSpacing, 0);
      expect(style.color, isNull);
      expect(style.backgroundColor, isNull);
    }
  });
}
