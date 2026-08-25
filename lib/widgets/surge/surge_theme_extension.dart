import 'package:flutter/material.dart';

import '../../theme/static_theme.dart';

import 'surge_tokens.dart';

export '../../theme/typography/typography_context.dart';

@immutable
class SurgeTheme extends ThemeExtension<SurgeTheme> {
  const SurgeTheme({
    required this.background,
    required this.card,
    required this.elevatedCard,
    required this.primary,
    required this.onPrimary,
    required this.green,
    required this.purple,
    required this.orange,
    required this.red,
    required this.textPrimary,
    required this.textSecondary,
    required this.separator,
    required this.fill,
    required this.selectedFill,
    required this.navBar,
    required this.navBorder,
    required this.shadow,
    required this.inactive,
    required this.inactiveVariant,
    required this.radii,
    required this.spacing,
    required this.semantic,
    required this.controls,
    required this.opacity,
  });

  factory SurgeTheme.light() {
    const spec = StaticThemeSpec.blueWhiteLight;
    return SurgeTheme.fromColors(spec.colors, stateColors: spec.stateColors);
  }

  factory SurgeTheme.dark() {
    const spec = StaticThemeSpec.blueWhiteDark;
    return SurgeTheme.fromColors(spec.colors, stateColors: spec.stateColors);
  }

  factory SurgeTheme.fromColorScheme(ColorScheme colorScheme) {
    return SurgeTheme.fromColors(SurgeColors.fromColorScheme(colorScheme));
  }

  factory SurgeTheme.fromColors(
    SurgeColors colors, {
    SurgeStateColors? stateColors,
  }) {
    return SurgeTheme(
      background: colors.background,
      card: colors.card,
      elevatedCard: colors.elevatedCard,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      green: colors.green,
      purple: colors.purple,
      orange: colors.orange,
      red: colors.red,
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      separator: colors.separator,
      fill: colors.fill,
      selectedFill: colors.selectedFill,
      navBar: colors.navBar,
      navBorder: colors.navBorder,
      shadow: colors.shadow,
      inactive: colors.inactive,
      inactiveVariant: colors.inactiveVariant,
      radii: SurgeRadii.regular(),
      spacing: SurgeSpacing.regular(),
      semantic: SurgeSemanticColors.regular(colors, state: stateColors),
      controls: SurgeControlSizes.regular(),
      opacity: SurgeOpacity.regular(),
    );
  }

  final Color background;
  final Color card;
  final Color elevatedCard;
  final Color primary;
  final Color onPrimary;
  final Color green;
  final Color purple;
  final Color orange;
  final Color red;
  final Color textPrimary;
  final Color textSecondary;
  final Color separator;
  final Color fill;
  final Color selectedFill;
  final Color navBar;
  final Color navBorder;
  final Color shadow;
  final Color inactive;
  final Color inactiveVariant;
  final SurgeRadii radii;
  final SurgeSpacing spacing;
  final SurgeSemanticColors semantic;
  final SurgeControlSizes controls;
  final SurgeOpacity opacity;

  static SurgeTheme of(BuildContext context) {
    return Theme.of(context).extension<SurgeTheme>() ?? SurgeTheme.light();
  }

  @override
  SurgeTheme copyWith({
    Color? background,
    Color? card,
    Color? elevatedCard,
    Color? primary,
    Color? onPrimary,
    Color? green,
    Color? purple,
    Color? orange,
    Color? red,
    Color? textPrimary,
    Color? textSecondary,
    Color? separator,
    Color? fill,
    Color? selectedFill,
    Color? navBar,
    Color? navBorder,
    Color? shadow,
    Color? inactive,
    Color? inactiveVariant,
    SurgeRadii? radii,
    SurgeSpacing? spacing,
    SurgeSemanticColors? semantic,
    SurgeControlSizes? controls,
    SurgeOpacity? opacity,
  }) {
    return SurgeTheme(
      background: background ?? this.background,
      card: card ?? this.card,
      elevatedCard: elevatedCard ?? this.elevatedCard,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      green: green ?? this.green,
      purple: purple ?? this.purple,
      orange: orange ?? this.orange,
      red: red ?? this.red,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      separator: separator ?? this.separator,
      fill: fill ?? this.fill,
      selectedFill: selectedFill ?? this.selectedFill,
      navBar: navBar ?? this.navBar,
      navBorder: navBorder ?? this.navBorder,
      shadow: shadow ?? this.shadow,
      inactive: inactive ?? this.inactive,
      inactiveVariant: inactiveVariant ?? this.inactiveVariant,
      radii: radii ?? this.radii,
      spacing: spacing ?? this.spacing,
      semantic: semantic ?? this.semantic,
      controls: controls ?? this.controls,
      opacity: opacity ?? this.opacity,
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
      elevatedCard: Color.lerp(elevatedCard, other.elevatedCard, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      green: Color.lerp(green, other.green, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      red: Color.lerp(red, other.red, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navBorder: Color.lerp(navBorder, other.navBorder, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      inactive: Color.lerp(inactive, other.inactive, t)!,
      inactiveVariant: Color.lerp(inactiveVariant, other.inactiveVariant, t)!,
      radii: SurgeRadii.lerp(radii, other.radii, t),
      spacing: SurgeSpacing.lerp(spacing, other.spacing, t),
      semantic: SurgeSemanticColors.lerp(semantic, other.semantic, t),
      controls: SurgeControlSizes.lerp(controls, other.controls, t),
      opacity: SurgeOpacity.lerp(opacity, other.opacity, t),
    );
  }
}
