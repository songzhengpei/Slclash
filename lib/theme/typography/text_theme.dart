import 'package:flutter/material.dart';

import 'type_scale.dart';

TextTheme buildSlclashTextTheme() {
  return const TextTheme(
    displayLarge: SlclashTypeScale.materialDisplayLarge,
    displayMedium: SlclashTypeScale.materialDisplayMedium,
    displaySmall: SlclashTypeScale.metricLarge,
    headlineLarge: SlclashTypeScale.metricLarge,
    headlineMedium: SlclashTypeScale.rootAppBarTitle,
    headlineSmall: SlclashTypeScale.rootAppBarTitle,
    titleLarge: SlclashTypeScale.appBarTitle,
    titleMedium: SlclashTypeScale.cardTitle,
    titleSmall: SlclashTypeScale.rowTitle,
    bodyLarge: SlclashTypeScale.body,
    bodyMedium: SlclashTypeScale.supporting,
    bodySmall: SlclashTypeScale.materialBodySmall,
    labelLarge: SlclashTypeScale.controlLabel,
    labelMedium: SlclashTypeScale.navigationLabel,
    labelSmall: SlclashTypeScale.navigationLabel,
  );
}
