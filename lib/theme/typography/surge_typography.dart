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
    required this.badgeLabel,
    required this.metricLarge,
    required this.metric,
    required this.technical,
    required this.chartLabel,
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
      badgeLabel: SlclashTypeScale.badgeLabel,
      metricLarge: textTheme.headlineLarge!,
      metric: SlclashTypeScale.metric,
      technical: SlclashTypeScale.technical,
      chartLabel: SlclashTypeScale.chartLabel,
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
  final TextStyle badgeLabel;
  final TextStyle metricLarge;
  final TextStyle metric;
  final TextStyle technical;
  final TextStyle chartLabel;

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
    TextStyle? badgeLabel,
    TextStyle? metricLarge,
    TextStyle? metric,
    TextStyle? technical,
    TextStyle? chartLabel,
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
      badgeLabel: badgeLabel ?? this.badgeLabel,
      metricLarge: metricLarge ?? this.metricLarge,
      metric: metric ?? this.metric,
      technical: technical ?? this.technical,
      chartLabel: chartLabel ?? this.chartLabel,
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
      badgeLabel: TextStyle.lerp(badgeLabel, other.badgeLabel, t)!,
      metricLarge: TextStyle.lerp(metricLarge, other.metricLarge, t)!,
      metric: TextStyle.lerp(metric, other.metric, t)!,
      technical: TextStyle.lerp(technical, other.technical, t)!,
      chartLabel: TextStyle.lerp(chartLabel, other.chartLabel, t)!,
    );
  }
}
