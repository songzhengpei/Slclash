import 'package:flutter/material.dart';

@immutable
class SurgeColors {
  const SurgeColors({
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
  });

  factory SurgeColors.light() {
    return const SurgeColors(
      background: Color(0xFFF2F3F7),
      card: Color(0xFFFFFFFF),
      elevatedCard: Color(0xFFFFFFFF),
      primary: Color(0xFF0A84FF),
      onPrimary: Color(0xFFFFFFFF),
      green: Color(0xFF34C759),
      purple: Color(0xFFAF52DE),
      orange: Color(0xFFFF9500),
      red: Color(0xFFFF3B30),
      textPrimary: Color(0xFF1C1C1E),
      textSecondary: Color(0xFF8E8E93),
      separator: Color(0xFFE5E5EA),
      fill: Color(0xFFF1F2F5),
      selectedFill: Color(0xFFE9EAEE),
      navBar: Color(0xF0FFFFFF),
      navBorder: Color(0x0D000000),
      shadow: Color(0x14000000),
      inactive: Color(0xFF858681),
      inactiveVariant: Color(0xFFA5A6A1),
    );
  }

  factory SurgeColors.dark() {
    return const SurgeColors(
      background: Color(0xFF08090B),
      card: Color(0xFF17191D),
      elevatedCard: Color(0xFF202328),
      primary: Color(0xFF4DA3FF),
      onPrimary: Color(0xFFFFFFFF),
      green: Color(0xFF30D158),
      purple: Color(0xFFBF5AF2),
      orange: Color(0xFFFF9F0A),
      red: Color(0xFFFF453A),
      textPrimary: Color(0xFFF5F5F7),
      textSecondary: Color(0xFF9A9AA0),
      separator: Color(0xFF30343A),
      fill: Color(0xFF22252A),
      selectedFill: Color(0xFF2B2F35),
      navBar: Color(0xF01B1D21),
      navBorder: Color(0x26FFFFFF),
      shadow: Color(0x66000000),
      inactive: Color(0xFF777A7F),
      inactiveVariant: Color(0xFF9B9EA3),
    );
  }

  factory SurgeColors.fromColorScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return SurgeColors(
      background: dark ? scheme.surface : scheme.surfaceContainer,
      card: dark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
      elevatedCard: dark
          ? scheme.surfaceContainer
          : scheme.surfaceContainerLowest,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      green: dark ? const Color(0xFF30D158) : const Color(0xFF34C759),
      purple: dark ? const Color(0xFFBF5AF2) : const Color(0xFFAF52DE),
      orange: dark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500),
      red: scheme.error,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      separator: scheme.outlineVariant,
      fill: scheme.surfaceContainerHighest,
      selectedFill: dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainer,
      navBar: dark
          ? scheme.surfaceContainer.withValues(alpha: 0.92)
          : scheme.surfaceContainerLowest.withValues(alpha: 0.94),
      navBorder: scheme.outlineVariant.withValues(alpha: dark ? 0.36 : 0.55),
      shadow: Colors.black.withValues(alpha: dark ? 0.42 : 0.08),
      inactive: dark ? const Color(0xFF777A7F) : const Color(0xFF858681),
      inactiveVariant: dark ? const Color(0xFF9B9EA3) : const Color(0xFFA5A6A1),
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

  SurgeColors copyWith({
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
  }) {
    return SurgeColors(
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
    );
  }

  static SurgeColors lerp(SurgeColors a, SurgeColors b, double t) {
    return SurgeColors(
      background: Color.lerp(a.background, b.background, t)!,
      card: Color.lerp(a.card, b.card, t)!,
      elevatedCard: Color.lerp(a.elevatedCard, b.elevatedCard, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      onPrimary: Color.lerp(a.onPrimary, b.onPrimary, t)!,
      green: Color.lerp(a.green, b.green, t)!,
      purple: Color.lerp(a.purple, b.purple, t)!,
      orange: Color.lerp(a.orange, b.orange, t)!,
      red: Color.lerp(a.red, b.red, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
      separator: Color.lerp(a.separator, b.separator, t)!,
      fill: Color.lerp(a.fill, b.fill, t)!,
      selectedFill: Color.lerp(a.selectedFill, b.selectedFill, t)!,
      navBar: Color.lerp(a.navBar, b.navBar, t)!,
      navBorder: Color.lerp(a.navBorder, b.navBorder, t)!,
      shadow: Color.lerp(a.shadow, b.shadow, t)!,
      inactive: Color.lerp(a.inactive, b.inactive, t)!,
      inactiveVariant: Color.lerp(a.inactiveVariant, b.inactiveVariant, t)!,
    );
  }
}

@immutable
class SurgeRadii {
  const SurgeRadii({
    required this.card,
    required this.smallCard,
    required this.list,
    required this.button,
  });

  factory SurgeRadii.regular() {
    return const SurgeRadii(card: 18, smallCard: 14, list: 16, button: 999);
  }

  final double card;
  final double smallCard;
  final double list;
  final double button;

  SurgeRadii copyWith({
    double? card,
    double? smallCard,
    double? list,
    double? button,
  }) {
    return SurgeRadii(
      card: card ?? this.card,
      smallCard: smallCard ?? this.smallCard,
      list: list ?? this.list,
      button: button ?? this.button,
    );
  }

  static SurgeRadii lerp(SurgeRadii a, SurgeRadii b, double t) {
    return SurgeRadii(
      card: lerpDouble(a.card, b.card, t),
      smallCard: lerpDouble(a.smallCard, b.smallCard, t),
      list: lerpDouble(a.list, b.list, t),
      button: lerpDouble(a.button, b.button, t),
    );
  }
}

@immutable
class SurgeSpacing {
  const SurgeSpacing({
    required this.pagePadding,
    required this.sectionSpacing,
    required this.cardPadding,
    required this.compactPadding,
    required this.hairline,
  });

  factory SurgeSpacing.regular() {
    return const SurgeSpacing(
      pagePadding: 16,
      sectionSpacing: 20,
      cardPadding: 16,
      compactPadding: 12,
      hairline: 0.5,
    );
  }

  final double pagePadding;
  final double sectionSpacing;
  final double cardPadding;
  final double compactPadding;
  final double hairline;

  SurgeSpacing copyWith({
    double? pagePadding,
    double? sectionSpacing,
    double? cardPadding,
    double? compactPadding,
    double? hairline,
  }) {
    return SurgeSpacing(
      pagePadding: pagePadding ?? this.pagePadding,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      cardPadding: cardPadding ?? this.cardPadding,
      compactPadding: compactPadding ?? this.compactPadding,
      hairline: hairline ?? this.hairline,
    );
  }

  static SurgeSpacing lerp(SurgeSpacing a, SurgeSpacing b, double t) {
    return SurgeSpacing(
      pagePadding: lerpDouble(a.pagePadding, b.pagePadding, t),
      sectionSpacing: lerpDouble(a.sectionSpacing, b.sectionSpacing, t),
      cardPadding: lerpDouble(a.cardPadding, b.cardPadding, t),
      compactPadding: lerpDouble(a.compactPadding, b.compactPadding, t),
      hairline: lerpDouble(a.hairline, b.hairline, t),
    );
  }
}

class SurgeShadows {
  const SurgeShadows._();

  static const card = [
    BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const subtle = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

class SurgeTextStyles {
  const SurgeTextStyles._();

  static TextStyle title(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          color: SurgeColors.light().textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ) ??
        TextStyle(
          color: SurgeColors.light().textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        );
  }

  static TextStyle body(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: SurgeColors.light().textPrimary,
          fontSize: 15,
          letterSpacing: 0,
        ) ??
        TextStyle(color: SurgeColors.light().textPrimary, fontSize: 15);
  }

  static TextStyle caption(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          color: SurgeColors.light().textSecondary,
          fontSize: 13,
          letterSpacing: 0,
        ) ??
        TextStyle(color: SurgeColors.light().textSecondary, fontSize: 13);
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium?.copyWith(
          color: SurgeColors.light().textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ) ??
        TextStyle(
          color: SurgeColors.light().textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        );
  }
}

double lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
