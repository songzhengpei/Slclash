import 'package:fl_clash/theme/typography/surge_typography.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/theme/typography/type_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);

  test('direct roles map to Material TextTheme slots', () {
    expect(typography.screenTitle, textTheme.headlineSmall);
    expect(typography.appBarTitle, textTheme.titleLarge);
    expect(typography.cardTitle, textTheme.titleMedium);
    expect(typography.rowTitle, textTheme.titleSmall);
    expect(typography.body, textTheme.bodyLarge);
    expect(typography.supporting, textTheme.bodyMedium);
    expect(typography.controlLabel, textTheme.labelLarge);
    expect(typography.navigationLabel, textTheme.labelMedium);
    expect(typography.metricLarge, textTheme.headlineLarge);
  });

  test('controlled roles come from the same type scale', () {
    expect(typography.dialogTitle, SlclashTypeScale.dialogTitle);
    expect(typography.sectionTitle, SlclashTypeScale.sectionTitle);
    expect(typography.badgeLabel, SlclashTypeScale.badgeLabel);
    expect(typography.selectedRowTitle, SlclashTypeScale.selectedRowTitle);
    expect(typography.selectorLabel, SlclashTypeScale.selectorLabel);
    expect(typography.metric, SlclashTypeScale.metric);
    expect(typography.supporting, SlclashTypeScale.supporting);
    expect(typography.technical, SlclashTypeScale.technical);
    expect(typography.chartLabel, SlclashTypeScale.chartLabel);
  });

  test('copyWith replaces only the requested role', () {
    const replacement = TextStyle(fontSize: 99);
    final copy = typography.copyWith(metric: replacement);
    expect(copy.metric, replacement);
    expect(copy.screenTitle, typography.screenTitle);
    expect(copy.chartLabel, typography.chartLabel);
  });

  test('lerp includes every role and preserves endpoints', () {
    final other = typography.copyWith(
      screenTitle: typography.screenTitle.copyWith(fontSize: 30),
      chartLabel: typography.chartLabel.copyWith(fontSize: 12),
    );
    expect(typography.lerp(other, 0).screenTitle, typography.screenTitle);
    expect(typography.lerp(other, 0).chartLabel, typography.chartLabel);
    expect(typography.lerp(other, 1).screenTitle, other.screenTitle);
    expect(typography.lerp(other, 1).chartLabel, other.chartLabel);
  });
}
