import 'package:flutter/material.dart';

import 'type_scale.dart';

@immutable
class SurgeTypography extends ThemeExtension<SurgeTypography> {
  const SurgeTypography({
    required this.screenTitle,
    required this.appBarTitle,
    required this.dialogTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.rowTitle,
    required this.body,
    required this.supporting,
    required this.controlLabel,
    required this.navigationLabel,
    required this.detailLabel,
    required this.compactRowTitle,
    required this.featuredTitle,
    required this.pillLabel,
    required this.previewLabel,
    required this.sheetRowTitle,
    required this.sheetLabel,
    required this.sheetTitle,
    required this.countLabel,
    required this.badgeLabel,
    required this.selectedRowTitle,
    required this.selectorLabel,
    required this.metricLarge,
    required this.metric,
    required this.technical,
    required this.chartLabel,
    required this.toolTileTitle,
    required this.compactDescription,
    required this.dashboardMetric,
    required this.techLabel,
  });

  factory SurgeTypography.fromTextTheme(TextTheme textTheme) {
    return SurgeTypography(
      screenTitle: textTheme.headlineSmall!,
      appBarTitle: textTheme.titleLarge!,
      dialogTitle: SlclashTypeScale.dialogTitle,
      sectionTitle: SlclashTypeScale.sectionTitle,
      cardTitle: textTheme.titleMedium!,
      rowTitle: textTheme.titleSmall!,
      body: textTheme.bodyLarge!,
      supporting: textTheme.bodyMedium!,
      controlLabel: textTheme.labelLarge!,
      navigationLabel: textTheme.labelMedium!,
      detailLabel: SlclashTypeScale.detailLabel,
      compactRowTitle: SlclashTypeScale.compactRowTitle,
      featuredTitle: SlclashTypeScale.featuredTitle,
      pillLabel: SlclashTypeScale.pillLabel,
      previewLabel: SlclashTypeScale.previewLabel,
      sheetRowTitle: SlclashTypeScale.sheetRowTitle,
      sheetLabel: SlclashTypeScale.sheetLabel,
      sheetTitle: SlclashTypeScale.sheetTitle,
      countLabel: SlclashTypeScale.countLabel,
      badgeLabel: SlclashTypeScale.badgeLabel,
      selectedRowTitle: SlclashTypeScale.selectedRowTitle,
      selectorLabel: SlclashTypeScale.selectorLabel,
      metricLarge: textTheme.headlineLarge!,
      metric: SlclashTypeScale.metric,
      technical: SlclashTypeScale.technical,
      chartLabel: SlclashTypeScale.chartLabel,
      toolTileTitle: SlclashTypeScale.toolTileTitle,
      compactDescription: SlclashTypeScale.compactDescription,
      dashboardMetric: SlclashTypeScale.dashboardMetric,
      techLabel: SlclashTypeScale.techLabel,
    );
  }

  final TextStyle screenTitle;
  final TextStyle appBarTitle;
  final TextStyle dialogTitle;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle rowTitle;
  final TextStyle body;
  final TextStyle supporting;
  final TextStyle controlLabel;
  final TextStyle navigationLabel;
  final TextStyle detailLabel;
  final TextStyle compactRowTitle;
  final TextStyle featuredTitle;
  final TextStyle pillLabel;
  final TextStyle previewLabel;
  final TextStyle sheetRowTitle;
  final TextStyle sheetLabel;
  final TextStyle sheetTitle;
  final TextStyle countLabel;
  final TextStyle badgeLabel;
  final TextStyle selectedRowTitle;
  final TextStyle selectorLabel;
  final TextStyle metricLarge;
  final TextStyle metric;
  final TextStyle technical;
  final TextStyle chartLabel;
  final TextStyle toolTileTitle;
  final TextStyle compactDescription;
  final TextStyle dashboardMetric;
  final TextStyle techLabel;

  @override
  SurgeTypography copyWith({
    TextStyle? screenTitle,
    TextStyle? appBarTitle,
    TextStyle? dialogTitle,
    TextStyle? sectionTitle,
    TextStyle? cardTitle,
    TextStyle? rowTitle,
    TextStyle? body,
    TextStyle? supporting,
    TextStyle? controlLabel,
    TextStyle? navigationLabel,
    TextStyle? detailLabel,
    TextStyle? compactRowTitle,
    TextStyle? featuredTitle,
    TextStyle? pillLabel,
    TextStyle? previewLabel,
    TextStyle? sheetRowTitle,
    TextStyle? sheetLabel,
    TextStyle? sheetTitle,
    TextStyle? countLabel,
    TextStyle? badgeLabel,
    TextStyle? selectedRowTitle,
    TextStyle? selectorLabel,
    TextStyle? metricLarge,
    TextStyle? metric,
    TextStyle? technical,
    TextStyle? chartLabel,
    TextStyle? toolTileTitle,
    TextStyle? compactDescription,
    TextStyle? dashboardMetric,
    TextStyle? techLabel,
  }) {
    return SurgeTypography(
      screenTitle: screenTitle ?? this.screenTitle,
      appBarTitle: appBarTitle ?? this.appBarTitle,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      cardTitle: cardTitle ?? this.cardTitle,
      rowTitle: rowTitle ?? this.rowTitle,
      body: body ?? this.body,
      supporting: supporting ?? this.supporting,
      controlLabel: controlLabel ?? this.controlLabel,
      navigationLabel: navigationLabel ?? this.navigationLabel,
      detailLabel: detailLabel ?? this.detailLabel,
      compactRowTitle: compactRowTitle ?? this.compactRowTitle,
      featuredTitle: featuredTitle ?? this.featuredTitle,
      pillLabel: pillLabel ?? this.pillLabel,
      previewLabel: previewLabel ?? this.previewLabel,
      sheetRowTitle: sheetRowTitle ?? this.sheetRowTitle,
      sheetLabel: sheetLabel ?? this.sheetLabel,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      countLabel: countLabel ?? this.countLabel,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      selectedRowTitle: selectedRowTitle ?? this.selectedRowTitle,
      selectorLabel: selectorLabel ?? this.selectorLabel,
      metricLarge: metricLarge ?? this.metricLarge,
      metric: metric ?? this.metric,
      technical: technical ?? this.technical,
      chartLabel: chartLabel ?? this.chartLabel,
      toolTileTitle: toolTileTitle ?? this.toolTileTitle,
      compactDescription: compactDescription ?? this.compactDescription,
      dashboardMetric: dashboardMetric ?? this.dashboardMetric,
      techLabel: techLabel ?? this.techLabel,
    );
  }

  @override
  SurgeTypography lerp(ThemeExtension<SurgeTypography>? other, double t) {
    if (other is! SurgeTypography) return this;
    return SurgeTypography(
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      appBarTitle: TextStyle.lerp(appBarTitle, other.appBarTitle, t)!,
      dialogTitle: TextStyle.lerp(dialogTitle, other.dialogTitle, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      rowTitle: TextStyle.lerp(rowTitle, other.rowTitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      supporting: TextStyle.lerp(supporting, other.supporting, t)!,
      controlLabel: TextStyle.lerp(controlLabel, other.controlLabel, t)!,
      navigationLabel: TextStyle.lerp(
        navigationLabel,
        other.navigationLabel,
        t,
      )!,
      detailLabel: TextStyle.lerp(
        detailLabel,
        other.detailLabel,
        t,
      )!,
      compactRowTitle: TextStyle.lerp(
        compactRowTitle,
        other.compactRowTitle,
        t,
      )!,
      featuredTitle: TextStyle.lerp(
        featuredTitle,
        other.featuredTitle,
        t,
      )!,
      pillLabel: TextStyle.lerp(
        pillLabel,
        other.pillLabel,
        t,
      )!,
      previewLabel: TextStyle.lerp(
        previewLabel,
        other.previewLabel,
        t,
      )!,
      sheetRowTitle: TextStyle.lerp(
        sheetRowTitle,
        other.sheetRowTitle,
        t,
      )!,
      sheetLabel: TextStyle.lerp(
        sheetLabel,
        other.sheetLabel,
        t,
      )!,
      sheetTitle: TextStyle.lerp(
        sheetTitle,
        other.sheetTitle,
        t,
      )!,
      countLabel: TextStyle.lerp(
        countLabel,
        other.countLabel,
        t,
      )!,
      badgeLabel: TextStyle.lerp(badgeLabel, other.badgeLabel, t)!,
      selectedRowTitle: TextStyle.lerp(
        selectedRowTitle,
        other.selectedRowTitle,
        t,
      )!,
      selectorLabel: TextStyle.lerp(selectorLabel, other.selectorLabel, t)!,
      metricLarge: TextStyle.lerp(metricLarge, other.metricLarge, t)!,
      metric: TextStyle.lerp(metric, other.metric, t)!,
      technical: TextStyle.lerp(technical, other.technical, t)!,
      chartLabel: TextStyle.lerp(chartLabel, other.chartLabel, t)!,
      toolTileTitle: TextStyle.lerp(
        toolTileTitle,
        other.toolTileTitle,
        t,
      )!,
      compactDescription: TextStyle.lerp(
        compactDescription,
        other.compactDescription,
        t,
      )!,
      dashboardMetric: TextStyle.lerp(
        dashboardMetric,
        other.dashboardMetric,
        t,
      )!,
      techLabel: TextStyle.lerp(techLabel, other.techLabel, t)!,
    );
  }
}
