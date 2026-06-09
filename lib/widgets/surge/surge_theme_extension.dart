import 'package:flutter/material.dart';

import 'surge_tokens.dart';

@immutable
class SurgeTheme extends ThemeExtension<SurgeTheme> {
  const SurgeTheme({
    required this.background,
    required this.card,
    required this.primary,
    required this.green,
    required this.purple,
    required this.orange,
    required this.red,
    required this.textPrimary,
    required this.textSecondary,
    required this.separator,
    required this.radii,
    required this.spacing,
  });

  factory SurgeTheme.light() {
    final colors = SurgeColors.light();
    return SurgeTheme(
      background: colors.background,
      card: colors.card,
      primary: colors.primary,
      green: colors.green,
      purple: colors.purple,
      orange: colors.orange,
      red: colors.red,
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      separator: colors.separator,
      radii: SurgeRadii.regular(),
      spacing: SurgeSpacing.regular(),
    );
  }

  final Color background;
  final Color card;
  final Color primary;
  final Color green;
  final Color purple;
  final Color orange;
  final Color red;
  final Color textPrimary;
  final Color textSecondary;
  final Color separator;
  final SurgeRadii radii;
  final SurgeSpacing spacing;

  static SurgeTheme of(BuildContext context) {
    return Theme.of(context).extension<SurgeTheme>() ?? SurgeTheme.light();
  }

  @override
  SurgeTheme copyWith({
    Color? background,
    Color? card,
    Color? primary,
    Color? green,
    Color? purple,
    Color? orange,
    Color? red,
    Color? textPrimary,
    Color? textSecondary,
    Color? separator,
    SurgeRadii? radii,
    SurgeSpacing? spacing,
  }) {
    return SurgeTheme(
      background: background ?? this.background,
      card: card ?? this.card,
      primary: primary ?? this.primary,
      green: green ?? this.green,
      purple: purple ?? this.purple,
      orange: orange ?? this.orange,
      red: red ?? this.red,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      separator: separator ?? this.separator,
      radii: radii ?? this.radii,
      spacing: spacing ?? this.spacing,
    );
  }

  @override
  SurgeTheme lerp(ThemeExtension<SurgeTheme>? other, double t) {
    if (other is! SurgeTheme) {
      return this;
    }
    return SurgeTheme(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      green: Color.lerp(green, other.green, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      red: Color.lerp(red, other.red, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      radii: SurgeRadii.lerp(radii, other.radii, t),
      spacing: SurgeSpacing.lerp(spacing, other.spacing, t),
    );
  }
}
