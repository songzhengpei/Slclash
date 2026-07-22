import 'package:flutter/material.dart';

import 'type_scale.dart';

@immutable
class SurgeTypography extends ThemeExtension<SurgeTypography> {
  const SurgeTypography({
    required this.rootAppBarTitle,
    required this.screenTitle,
    required this.appBarTitle,
    required this.dialogTitle,
    required this.sectionTitle,
    required this.mediaCheckTitle,
    required this.mediaControlMetricLabel,
    required this.mediaFilterTitle,
    required this.mediaFilterSubtitle,
    required this.mediaObservationInterval,
    required this.mediaResultTitle,
    required this.mediaRunButtonLabel,
    required this.cardTitle,
    required this.rowTitle,
    required this.body,
    required this.supporting,
    required this.controlLabel,
    required this.navigationLabel,
    required this.selectedNavigationLabel,
    required this.detailLabel,
    required this.compactRowTitle,
    required this.proxyGroupTitle,
    required this.proxySelectorLabel,
    required this.proxyCardSubtitle,
    required this.featuredTitle,
    required this.pillLabel,
    required this.itemLabel,
    required this.previewLabel,
    required this.sheetRowTitle,
    required this.sheetLabel,
    required this.sheetTitle,
    required this.countLabel,
    required this.badgeLabel,
    required this.selectedRowTitle,
    required this.selectorLabel,
    required this.modeTabLabel,
    required this.selectedModeTabLabel,
    required this.dashboardMetric,
    required this.dashboardIpValue,
    required this.dashboardLatencyValue,
    required this.dashboardDetectionValue,
    required this.techLabel,
    required this.metricLarge,
    required this.metric,
    required this.compactMetric,
    required this.technical,
    required this.chartLabel,
    required this.toolTileSubtitle,
    required this.toolTileTitle,
    required this.compactDescription,
  });

  factory SurgeTypography.fromTextTheme(TextTheme textTheme) {
    return SurgeTypography(
      rootAppBarTitle: SlclashTypeScale.rootAppBarTitle,
      screenTitle: textTheme.headlineSmall!,
      appBarTitle: textTheme.titleLarge!,
      dialogTitle: SlclashTypeScale.dialogTitle,
      sectionTitle: SlclashTypeScale.sectionTitle,
      mediaCheckTitle: SlclashTypeScale.mediaCheckTitle,
      mediaControlMetricLabel: SlclashTypeScale.mediaControlMetricLabel,
      mediaFilterTitle: SlclashTypeScale.mediaFilterTitle,
      mediaFilterSubtitle: SlclashTypeScale.mediaFilterSubtitle,
      mediaObservationInterval: SlclashTypeScale.mediaObservationInterval,
      mediaResultTitle: SlclashTypeScale.mediaResultTitle,
      mediaRunButtonLabel: SlclashTypeScale.mediaRunButtonLabel,
      cardTitle: textTheme.titleMedium!,
      rowTitle: textTheme.titleSmall!,
      body: textTheme.bodyLarge!,
      supporting: textTheme.bodyMedium!,
      controlLabel: textTheme.labelLarge!,
      navigationLabel: textTheme.labelMedium!,
      selectedNavigationLabel: SlclashTypeScale.selectedNavigationLabel,
      detailLabel: SlclashTypeScale.detailLabel,
      compactRowTitle: SlclashTypeScale.compactRowTitle,
      proxyGroupTitle: SlclashTypeScale.proxyGroupTitle,
      proxySelectorLabel: SlclashTypeScale.proxySelectorLabel,
      proxyCardSubtitle: SlclashTypeScale.proxyCardSubtitle,
      featuredTitle: SlclashTypeScale.featuredTitle,
      pillLabel: SlclashTypeScale.pillLabel,
      itemLabel: SlclashTypeScale.itemLabel,
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
      compactMetric: SlclashTypeScale.compactMetric,
      technical: SlclashTypeScale.technical,
      chartLabel: SlclashTypeScale.chartLabel,
      toolTileSubtitle: SlclashTypeScale.toolTileSubtitle,
      toolTileTitle: SlclashTypeScale.toolTileTitle,
      compactDescription: SlclashTypeScale.compactDescription,
      modeTabLabel: SlclashTypeScale.modeTabLabel,
      selectedModeTabLabel: SlclashTypeScale.selectedModeTabLabel,
      dashboardMetric: SlclashTypeScale.dashboardMetric,
      dashboardIpValue: SlclashTypeScale.dashboardIpValue,
      dashboardLatencyValue: SlclashTypeScale.dashboardLatencyValue,
      dashboardDetectionValue: SlclashTypeScale.dashboardDetectionValue,
      techLabel: SlclashTypeScale.techLabel,
    );
  }

  final TextStyle rootAppBarTitle;
  final TextStyle screenTitle;
  final TextStyle appBarTitle;
  final TextStyle dialogTitle;
  final TextStyle sectionTitle;
  final TextStyle mediaCheckTitle;
  final TextStyle mediaControlMetricLabel;
  final TextStyle mediaFilterTitle;
  final TextStyle mediaFilterSubtitle;
  final TextStyle mediaObservationInterval;
  final TextStyle mediaResultTitle;
  final TextStyle mediaRunButtonLabel;
  final TextStyle cardTitle;
  final TextStyle rowTitle;
  final TextStyle body;
  final TextStyle supporting;
  final TextStyle controlLabel;
  final TextStyle navigationLabel;
  final TextStyle selectedNavigationLabel;
  final TextStyle detailLabel;
  final TextStyle compactRowTitle;
  final TextStyle proxyGroupTitle;
  final TextStyle proxySelectorLabel;
  final TextStyle proxyCardSubtitle;
  final TextStyle featuredTitle;
  final TextStyle pillLabel;
  final TextStyle itemLabel;
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
  final TextStyle compactMetric;
  final TextStyle technical;
  final TextStyle chartLabel;
  final TextStyle toolTileSubtitle;
  final TextStyle toolTileTitle;
  final TextStyle compactDescription;
  final TextStyle modeTabLabel;
  final TextStyle selectedModeTabLabel;
  final TextStyle dashboardMetric;
  final TextStyle dashboardIpValue;
  final TextStyle dashboardLatencyValue;
  final TextStyle dashboardDetectionValue;
  final TextStyle techLabel;

  @override
  SurgeTypography copyWith({
    TextStyle? rootAppBarTitle,
    TextStyle? screenTitle,
    TextStyle? appBarTitle,
    TextStyle? dialogTitle,
    TextStyle? sectionTitle,
    TextStyle? mediaCheckTitle,
    TextStyle? mediaControlMetricLabel,
    TextStyle? mediaFilterTitle,
    TextStyle? mediaFilterSubtitle,
    TextStyle? mediaObservationInterval,
    TextStyle? mediaResultTitle,
    TextStyle? mediaRunButtonLabel,
    TextStyle? cardTitle,
    TextStyle? rowTitle,
    TextStyle? body,
    TextStyle? supporting,
    TextStyle? controlLabel,
    TextStyle? navigationLabel,
    TextStyle? selectedNavigationLabel,
    TextStyle? detailLabel,
    TextStyle? compactRowTitle,
    TextStyle? proxyGroupTitle,
    TextStyle? proxySelectorLabel,
    TextStyle? proxyCardSubtitle,
    TextStyle? featuredTitle,
    TextStyle? pillLabel,
    TextStyle? itemLabel,
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
    TextStyle? compactMetric,
    TextStyle? technical,
    TextStyle? chartLabel,
    TextStyle? toolTileSubtitle,
    TextStyle? toolTileTitle,
    TextStyle? compactDescription,
    TextStyle? modeTabLabel,
    TextStyle? selectedModeTabLabel,
    TextStyle? dashboardMetric,
    TextStyle? dashboardIpValue,
    TextStyle? dashboardLatencyValue,
    TextStyle? dashboardDetectionValue,
    TextStyle? techLabel,
  }) {
    return SurgeTypography(
      rootAppBarTitle: rootAppBarTitle ?? this.rootAppBarTitle,
      screenTitle: screenTitle ?? this.screenTitle,
      appBarTitle: appBarTitle ?? this.appBarTitle,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      mediaCheckTitle: mediaCheckTitle ?? this.mediaCheckTitle,
      mediaControlMetricLabel:
          mediaControlMetricLabel ?? this.mediaControlMetricLabel,
      mediaFilterTitle: mediaFilterTitle ?? this.mediaFilterTitle,
      mediaFilterSubtitle: mediaFilterSubtitle ?? this.mediaFilterSubtitle,
      mediaObservationInterval:
          mediaObservationInterval ?? this.mediaObservationInterval,
      mediaResultTitle: mediaResultTitle ?? this.mediaResultTitle,
      mediaRunButtonLabel: mediaRunButtonLabel ?? this.mediaRunButtonLabel,
      cardTitle: cardTitle ?? this.cardTitle,
      rowTitle: rowTitle ?? this.rowTitle,
      body: body ?? this.body,
      supporting: supporting ?? this.supporting,
      controlLabel: controlLabel ?? this.controlLabel,
      navigationLabel: navigationLabel ?? this.navigationLabel,
      selectedNavigationLabel:
          selectedNavigationLabel ?? this.selectedNavigationLabel,
      detailLabel: detailLabel ?? this.detailLabel,
      compactRowTitle: compactRowTitle ?? this.compactRowTitle,
      proxyGroupTitle: proxyGroupTitle ?? this.proxyGroupTitle,
      proxySelectorLabel: proxySelectorLabel ?? this.proxySelectorLabel,
      proxyCardSubtitle: proxyCardSubtitle ?? this.proxyCardSubtitle,
      featuredTitle: featuredTitle ?? this.featuredTitle,
      pillLabel: pillLabel ?? this.pillLabel,
      itemLabel: itemLabel ?? this.itemLabel,
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
      compactMetric: compactMetric ?? this.compactMetric,
      technical: technical ?? this.technical,
      chartLabel: chartLabel ?? this.chartLabel,
      toolTileSubtitle: toolTileSubtitle ?? this.toolTileSubtitle,
      toolTileTitle: toolTileTitle ?? this.toolTileTitle,
      compactDescription: compactDescription ?? this.compactDescription,
      modeTabLabel: modeTabLabel ?? this.modeTabLabel,
      selectedModeTabLabel: selectedModeTabLabel ?? this.selectedModeTabLabel,
      dashboardMetric: dashboardMetric ?? this.dashboardMetric,
      dashboardIpValue: dashboardIpValue ?? this.dashboardIpValue,
      dashboardLatencyValue:
          dashboardLatencyValue ?? this.dashboardLatencyValue,
      dashboardDetectionValue:
          dashboardDetectionValue ?? this.dashboardDetectionValue,
      techLabel: techLabel ?? this.techLabel,
    );
  }

  @override
  SurgeTypography lerp(ThemeExtension<SurgeTypography>? other, double t) {
    if (other is! SurgeTypography) return this;
    return SurgeTypography(
      rootAppBarTitle: TextStyle.lerp(
        rootAppBarTitle,
        other.rootAppBarTitle,
        t,
      )!,
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      appBarTitle: TextStyle.lerp(appBarTitle, other.appBarTitle, t)!,
      dialogTitle: TextStyle.lerp(dialogTitle, other.dialogTitle, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      mediaCheckTitle: TextStyle.lerp(
        mediaCheckTitle,
        other.mediaCheckTitle,
        t,
      )!,
      mediaControlMetricLabel: TextStyle.lerp(
        mediaControlMetricLabel,
        other.mediaControlMetricLabel,
        t,
      )!,
      mediaFilterTitle: TextStyle.lerp(
        mediaFilterTitle,
        other.mediaFilterTitle,
        t,
      )!,
      mediaFilterSubtitle: TextStyle.lerp(
        mediaFilterSubtitle,
        other.mediaFilterSubtitle,
        t,
      )!,
      mediaObservationInterval: TextStyle.lerp(
        mediaObservationInterval,
        other.mediaObservationInterval,
        t,
      )!,
      mediaResultTitle: TextStyle.lerp(
        mediaResultTitle,
        other.mediaResultTitle,
        t,
      )!,
      mediaRunButtonLabel: TextStyle.lerp(
        mediaRunButtonLabel,
        other.mediaRunButtonLabel,
        t,
      )!,
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
      selectedNavigationLabel: TextStyle.lerp(
        selectedNavigationLabel,
        other.selectedNavigationLabel,
        t,
      )!,
      detailLabel: TextStyle.lerp(detailLabel, other.detailLabel, t)!,
      compactRowTitle: TextStyle.lerp(
        compactRowTitle,
        other.compactRowTitle,
        t,
      )!,
      proxyGroupTitle: TextStyle.lerp(
        proxyGroupTitle,
        other.proxyGroupTitle,
        t,
      )!,
      proxySelectorLabel: TextStyle.lerp(
        proxySelectorLabel,
        other.proxySelectorLabel,
        t,
      )!,
      proxyCardSubtitle: TextStyle.lerp(
        proxyCardSubtitle,
        other.proxyCardSubtitle,
        t,
      )!,
      featuredTitle: TextStyle.lerp(featuredTitle, other.featuredTitle, t)!,
      pillLabel: TextStyle.lerp(pillLabel, other.pillLabel, t)!,
      itemLabel: TextStyle.lerp(itemLabel, other.itemLabel, t)!,
      previewLabel: TextStyle.lerp(previewLabel, other.previewLabel, t)!,
      sheetRowTitle: TextStyle.lerp(sheetRowTitle, other.sheetRowTitle, t)!,
      sheetLabel: TextStyle.lerp(sheetLabel, other.sheetLabel, t)!,
      sheetTitle: TextStyle.lerp(sheetTitle, other.sheetTitle, t)!,
      countLabel: TextStyle.lerp(countLabel, other.countLabel, t)!,
      badgeLabel: TextStyle.lerp(badgeLabel, other.badgeLabel, t)!,
      selectedRowTitle: TextStyle.lerp(
        selectedRowTitle,
        other.selectedRowTitle,
        t,
      )!,
      selectorLabel: TextStyle.lerp(selectorLabel, other.selectorLabel, t)!,
      metricLarge: TextStyle.lerp(metricLarge, other.metricLarge, t)!,
      metric: TextStyle.lerp(metric, other.metric, t)!,
      compactMetric: TextStyle.lerp(compactMetric, other.compactMetric, t)!,
      technical: TextStyle.lerp(technical, other.technical, t)!,
      chartLabel: TextStyle.lerp(chartLabel, other.chartLabel, t)!,
      toolTileSubtitle: TextStyle.lerp(
        toolTileSubtitle,
        other.toolTileSubtitle,
        t,
      )!,
      toolTileTitle: TextStyle.lerp(toolTileTitle, other.toolTileTitle, t)!,
      compactDescription: TextStyle.lerp(
        compactDescription,
        other.compactDescription,
        t,
      )!,
      modeTabLabel: TextStyle.lerp(modeTabLabel, other.modeTabLabel, t)!,
      selectedModeTabLabel: TextStyle.lerp(
        selectedModeTabLabel,
        other.selectedModeTabLabel,
        t,
      )!,
      dashboardMetric: TextStyle.lerp(
        dashboardMetric,
        other.dashboardMetric,
        t,
      )!,
      dashboardIpValue: TextStyle.lerp(
        dashboardIpValue,
        other.dashboardIpValue,
        t,
      )!,
      dashboardLatencyValue: TextStyle.lerp(
        dashboardLatencyValue,
        other.dashboardLatencyValue,
        t,
      )!,
      dashboardDetectionValue: TextStyle.lerp(
        dashboardDetectionValue,
        other.dashboardDetectionValue,
        t,
      )!,
      techLabel: TextStyle.lerp(techLabel, other.techLabel, t)!,
    );
  }
}
