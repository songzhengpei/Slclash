import 'package:flutter/material.dart';

@immutable
class SurgeColors {
  const SurgeColors({
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
  });

  factory SurgeColors.light() {
    return const SurgeColors(
      background: Color(0xFFF2F3F7),
      card: Color(0xFFFFFFFF),
      primary: Color(0xFF0A84FF),
      green: Color(0xFF34C759),
      purple: Color(0xFFAF52DE),
      orange: Color(0xFFFF9500),
      red: Color(0xFFFF3B30),
      textPrimary: Color(0xFF1C1C1E),
      textSecondary: Color(0xFF8E8E93),
      separator: Color(0xFFE5E5EA),
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

  SurgeColors copyWith({
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
  }) {
    return SurgeColors(
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
    );
  }

  static SurgeColors lerp(SurgeColors a, SurgeColors b, double t) {
    return SurgeColors(
      background: Color.lerp(a.background, b.background, t)!,
      card: Color.lerp(a.card, b.card, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      green: Color.lerp(a.green, b.green, t)!,
      purple: Color.lerp(a.purple, b.purple, t)!,
      orange: Color.lerp(a.orange, b.orange, t)!,
      red: Color.lerp(a.red, b.red, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
      separator: Color.lerp(a.separator, b.separator, t)!,
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
