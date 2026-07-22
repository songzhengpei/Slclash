import 'package:fl_clash/theme/typography/font_families.dart';
import 'package:fl_clash/theme/typography/type_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all semantic roles match the frozen type scale', () {
    final cases = <(TextStyle, double, double?, FontWeight, String?)>[
      (SlclashTypeScale.rootAppBarTitle, 20, 1.3, FontWeight.w600, null),
      (SlclashTypeScale.screenTitle, 19, 1.4737, FontWeight.w500, null),
      (SlclashTypeScale.appBarTitle, 19, 1.3, FontWeight.w500, null),
      (SlclashTypeScale.dialogTitle, 18, 1.3333, FontWeight.w600, null),
      (SlclashTypeScale.sectionTitle, 14, 1.4667, FontWeight.w500, null),
      (SlclashTypeScale.mediaCheckTitle, 16, 1.25, FontWeight.w500, null),
      (SlclashTypeScale.mediaControlMetricLabel, 12, 1, FontWeight.w600, null),
      (SlclashTypeScale.mediaFilterTitle, 14, 1.4286, FontWeight.w600, null),
      (
        SlclashTypeScale.mediaFilterSubtitle,
        12,
        1.3333,
        FontWeight.w500,
        SlclashFontFamilies.jetBrainsMono,
      ),
      (
        SlclashTypeScale.mediaObservationInterval,
        13,
        1.2308,
        FontWeight.w600,
        null,
      ),
      (SlclashTypeScale.mediaResultTitle, 12, 1.3333, FontWeight.w600, null),
      (SlclashTypeScale.mediaRunButtonLabel, 12, 1.3333, FontWeight.w600, null),
      (SlclashTypeScale.cardTitle, 16, 1.125, FontWeight.w500, null),
      (SlclashTypeScale.rowTitle, 15, 1.4667, FontWeight.w500, null),
      (SlclashTypeScale.toolTileSubtitle, 13, 1.2308, FontWeight.w400, null),
      (SlclashTypeScale.toolTileTitle, 16, 1.4667, FontWeight.w400, null),
      (SlclashTypeScale.compactDescription, 12, 1.4667, FontWeight.w400, null),
      (SlclashTypeScale.body, 15, 1.4667, FontWeight.w400, null),
      (SlclashTypeScale.supporting, 13, 1.2308, FontWeight.w400, null),
      (SlclashTypeScale.controlLabel, 14, 1.4286, FontWeight.w600, null),
      (SlclashTypeScale.navigationLabel, 11, 1, FontWeight.w500, null),
      (SlclashTypeScale.selectedNavigationLabel, 11, 1, FontWeight.w600, null),
      (SlclashTypeScale.badgeLabel, 11, 1, FontWeight.w600, null),
      (SlclashTypeScale.selectedRowTitle, 15, 1.4667, FontWeight.w600, null),
      (SlclashTypeScale.modeTabLabel, 14, 1.4667, FontWeight.w500, null),
      (
        SlclashTypeScale.selectedModeTabLabel,
        14,
        1.4667,
        FontWeight.w600,
        null,
      ),
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
      (SlclashTypeScale.detailLabel, 12, null, FontWeight.w400, null),
      (SlclashTypeScale.compactRowTitle, 13, 1.4667, FontWeight.w400, null),
      (SlclashTypeScale.proxyGroupTitle, 16, 1.2941, FontWeight.w500, null),
      (SlclashTypeScale.proxySelectorLabel, 12, 1.3846, FontWeight.w400, null),
      (SlclashTypeScale.proxyCardSubtitle, 12, 1.3846, FontWeight.w400, null),
      (SlclashTypeScale.featuredTitle, 17, 1.4667, FontWeight.w500, null),
      (SlclashTypeScale.pillLabel, 12, 1, FontWeight.w600, null),
      (SlclashTypeScale.itemLabel, 14, 1.4667, FontWeight.w500, null),
      (SlclashTypeScale.previewLabel, 13, 1.4286, FontWeight.w500, null),
      (SlclashTypeScale.sheetRowTitle, 14, 1.4667, FontWeight.w600, null),
      (SlclashTypeScale.sheetLabel, 12, 1, FontWeight.w400, null),
      (SlclashTypeScale.sheetTitle, 18, 1.3, FontWeight.w500, null),
      (SlclashTypeScale.countLabel, 12, 1.2308, FontWeight.w400, null),
      (
        SlclashTypeScale.chartLabel,
        10,
        1.4,
        FontWeight.w500,
        SlclashFontFamilies.jetBrainsMono,
      ),
      (SlclashTypeScale.techLabel, 13, 1.3846, FontWeight.w500, null),
      (SlclashTypeScale.dashboardMetric, 14, 1.2857, FontWeight.w700, null),
      (SlclashTypeScale.dashboardIpValue, 13, 1.2857, FontWeight.w600, null),
      (
        SlclashTypeScale.dashboardLatencyValue,
        12,
        1.3333,
        FontWeight.w500,
        null,
      ),
      (
        SlclashTypeScale.dashboardDetectionValue,
        16,
        1.2857,
        FontWeight.w700,
        null,
      ),
    ];

    expect(cases, hasLength(50));
    for (final (style, size, height, weight, family) in cases) {
      expect(style.fontSize, size);
      if (height == null) {
        expect(style.height, isNull);
      } else {
        expect(style.height, closeTo(height, 0.00001));
      }
      expect(style.fontWeight, weight);
      expect(style.fontFamily, family);
      expect(style.letterSpacing, 0);
      expect(style.color, isNull);
      expect(style.backgroundColor, isNull);
    }
  });
}
