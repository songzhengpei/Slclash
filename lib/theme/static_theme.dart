import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

enum StaticThemePreset { blueWhite, grayBlack }

@immutable
class StaticThemeSpec {
  const StaticThemeSpec({
    required this.preset,
    required this.brightness,
    required this.colors,
    required this.stateColors,
  });

  final StaticThemePreset preset;
  final Brightness brightness;
  final SurgeColors colors;
  final SurgeStateColors stateColors;

  static const values = <StaticThemeSpec>[
    blueWhiteLight,
    blueWhiteDark,
    grayBlackLight,
    grayBlackDark,
  ];

  static StaticThemeSpec resolve(
    StaticThemePreset preset,
    Brightness brightness,
  ) {
    return values.singleWhere(
      (spec) => spec.preset == preset && spec.brightness == brightness,
    );
  }

  ColorScheme get colorScheme {
    final dark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.selectedFill,
      onPrimaryContainer: colors.textPrimary,
      primaryFixed: colors.primary,
      primaryFixedDim: colors.primary,
      onPrimaryFixed: colors.onPrimary,
      onPrimaryFixedVariant: colors.onPrimary,
      secondary: colors.textSecondary,
      onSecondary: colors.card,
      secondaryContainer: colors.fill,
      onSecondaryContainer: colors.textPrimary,
      secondaryFixed: colors.textSecondary,
      secondaryFixedDim: colors.inactive,
      onSecondaryFixed: colors.card,
      onSecondaryFixedVariant: colors.card,
      tertiary: colors.purple,
      onTertiary: dark ? colors.background : colors.onPrimary,
      tertiaryContainer: colors.fill,
      onTertiaryContainer: colors.purple,
      tertiaryFixed: colors.purple,
      tertiaryFixedDim: colors.purple,
      onTertiaryFixed: dark ? colors.background : colors.onPrimary,
      onTertiaryFixedVariant: dark ? colors.background : colors.onPrimary,
      error: colors.red,
      onError: dark ? colors.background : colors.onPrimary,
      errorContainer: colors.fill,
      onErrorContainer: colors.red,
      surface: colors.card,
      onSurface: colors.textPrimary,
      surfaceDim: colors.background,
      surfaceBright: colors.elevatedCard,
      surfaceContainerLowest: colors.card,
      surfaceContainerLow: colors.elevatedCard,
      surfaceContainer: colors.background,
      surfaceContainerHigh: colors.fill,
      surfaceContainerHighest: colors.selectedFill,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.separator,
      outlineVariant: colors.navBorder,
      shadow: colors.shadow,
      scrim: colors.shadow,
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.background,
      inversePrimary: colors.primary,
      surfaceTint: colors.primary,
    );
  }

  static const blueWhiteLight = StaticThemeSpec(
    preset: StaticThemePreset.blueWhite,
    brightness: Brightness.light,
    colors: SurgeColors(
      background: Color(0xFFF2F3F7),
      card: Color(0xFFFFFFFF),
      elevatedCard: Color(0xFFF8F9FC),
      primary: Color(0xFF0065CC),
      onPrimary: Color(0xFFFFFFFF),
      green: Color(0xFF237A3B),
      purple: Color(0xFF6551A3),
      orange: Color(0xFFA85B00),
      red: Color(0xFFC9362B),
      textPrimary: Color(0xFF1C1C1E),
      textSecondary: Color(0xFF5F6368),
      separator: Color(0xFFD8DBE0),
      fill: Color(0xFFEDEFF3),
      selectedFill: Color(0xFFE2EEFC),
      navBar: Color(0xFFFFFFFF),
      navBorder: Color(0xFFD3D7DD),
      shadow: Color(0x14000000),
      inactive: Color(0xFF6B7078),
      inactiveVariant: Color(0xFF8B9098),
    ),
    stateColors: SurgeStateColors(
      toggleActive: Color(0xFF0065CC),
      onToggleActive: Color(0xFFFFFFFF),
      heroStart: Color(0xFF34C759),
      heroPause: Color(0xFFFF9500),
      heroStop: Color(0xFFBA1A1A),
      onHeroAction: Color(0xFFFFFFFF),
    ),
  );

  static const blueWhiteDark = StaticThemeSpec(
    preset: StaticThemePreset.blueWhite,
    brightness: Brightness.dark,
    colors: SurgeColors(
      background: Color(0xFF08090B),
      card: Color(0xFF17191D),
      elevatedCard: Color(0xFF202328),
      primary: Color(0xFF67B0FF),
      onPrimary: Color(0xFF071521),
      green: Color(0xFF51B969),
      purple: Color(0xFFB9A0E8),
      orange: Color(0xFFE49A41),
      red: Color(0xFFFF6B61),
      textPrimary: Color(0xFFF5F5F7),
      textSecondary: Color(0xFFB7BDC4),
      separator: Color(0xFF34383E),
      fill: Color(0xFF292D32),
      selectedFill: Color(0xFF35414D),
      navBar: Color(0xFF17191D),
      navBorder: Color(0xFF363B42),
      shadow: Color(0x66000000),
      inactive: Color(0xFF7C8189),
      inactiveVariant: Color(0xFF9EA3AB),
    ),
    stateColors: SurgeStateColors(
      toggleActive: Color(0xFF67B0FF),
      onToggleActive: Color(0xFF071521),
      heroStart: Color(0xFF30D158),
      heroPause: Color(0xFFFF9F0A),
      heroStop: Color(0xFFFF453A),
      onHeroAction: Color(0xFFFFFFFF),
    ),
  );

  static const grayBlackLight = StaticThemeSpec(
    preset: StaticThemePreset.grayBlack,
    brightness: Brightness.light,
    colors: SurgeColors(
      background: Color(0xFFF9F9F7),
      card: Color(0xFFFFFFFF),
      elevatedCard: Color(0xFFFCFCFA),
      primary: Color(0xFF74665A),
      onPrimary: Color(0xFFFFFFFF),
      green: Color(0xFF237A3B),
      purple: Color(0xFF6551A3),
      orange: Color(0xFFA85B00),
      red: Color(0xFFC9362B),
      textPrimary: Color(0xFF1F1F1D),
      textSecondary: Color(0xFF656560),
      separator: Color(0xFFD6D5D0),
      fill: Color(0xFFF0EFEC),
      selectedFill: Color(0xFFE4E3DE),
      navBar: Color(0xFFFFFFFF),
      navBorder: Color(0xFFC8C7C1),
      shadow: Color(0x18000000),
      inactive: Color(0xFF6F6F6A),
      inactiveVariant: Color(0xFF92928C),
    ),
    stateColors: SurgeStateColors(
      toggleActive: Color(0xFF74665A),
      onToggleActive: Color(0xFFFFFFFF),
      heroStart: Color(0xFF34C759),
      heroPause: Color(0xFFFF9500),
      heroStop: Color(0xFFBA1A1A),
      onHeroAction: Color(0xFFFFFFFF),
    ),
  );

  static const grayBlackDark = StaticThemeSpec(
    preset: StaticThemePreset.grayBlack,
    brightness: Brightness.dark,
    colors: SurgeColors(
      background: Color(0xFF151515),
      card: Color(0xFF20201F),
      elevatedCard: Color(0xFF2B2B2A),
      primary: Color(0xFFB7A796),
      onPrimary: Color(0xFF151515),
      green: Color(0xFF51B969),
      purple: Color(0xFFB9A0E8),
      orange: Color(0xFFE49A41),
      red: Color(0xFFFF6B61),
      textPrimary: Color(0xFFF9F9F7),
      textSecondary: Color(0xFFB7B7B2),
      separator: Color(0xFF454543),
      fill: Color(0xFF313131),
      selectedFill: Color(0xFF3A3A39),
      navBar: Color(0xFF20201F),
      navBorder: Color(0xFF4B4B48),
      shadow: Color(0x8A000000),
      inactive: Color(0xFF91918C),
      inactiveVariant: Color(0xFFA6A6A0),
    ),
    stateColors: SurgeStateColors(
      toggleActive: Color(0xFFB7A796),
      onToggleActive: Color(0xFF151515),
      heroStart: Color(0xFF30D158),
      heroPause: Color(0xFFFF9F0A),
      heroStop: Color(0xFFFF453A),
      onHeroAction: Color(0xFFFFFFFF),
    ),
  );
}
