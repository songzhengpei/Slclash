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
      red: dark ? const Color(0xFFFF453A) : scheme.error,
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
    required this.menuRow,
    required this.input,
    required this.metric,
    required this.chart,
    required this.compact,
    required this.segmentedIndicator,
    required this.button,
  });

  factory SurgeRadii.regular() {
    return const SurgeRadii(
      card: 18,
      smallCard: 14,
      list: 16,
      menuRow: 12,
      input: 10,
      metric: 10,
      chart: 4,
      compact: 8,
      segmentedIndicator: 13,
      button: 999,
    );
  }

  final double card;
  final double smallCard;
  final double list;
  final double menuRow;
  final double input;
  final double metric;
  final double chart;
  final double compact;
  final double segmentedIndicator;
  final double button;

  SurgeRadii copyWith({
    double? card,
    double? smallCard,
    double? list,
    double? menuRow,
    double? input,
    double? metric,
    double? chart,
    double? compact,
    double? segmentedIndicator,
    double? button,
  }) {
    return SurgeRadii(
      card: card ?? this.card,
      smallCard: smallCard ?? this.smallCard,
      list: list ?? this.list,
      menuRow: menuRow ?? this.menuRow,
      input: input ?? this.input,
      metric: metric ?? this.metric,
      chart: chart ?? this.chart,
      compact: compact ?? this.compact,
      segmentedIndicator: segmentedIndicator ?? this.segmentedIndicator,
      button: button ?? this.button,
    );
  }

  static SurgeRadii lerp(SurgeRadii a, SurgeRadii b, double t) {
    return SurgeRadii(
      card: lerpDouble(a.card, b.card, t),
      smallCard: lerpDouble(a.smallCard, b.smallCard, t),
      list: lerpDouble(a.list, b.list, t),
      menuRow: lerpDouble(a.menuRow, b.menuRow, t),
      input: lerpDouble(a.input, b.input, t),
      metric: lerpDouble(a.metric, b.metric, t),
      chart: lerpDouble(a.chart, b.chart, t),
      compact: lerpDouble(a.compact, b.compact, t),
      segmentedIndicator: lerpDouble(
        a.segmentedIndicator,
        b.segmentedIndicator,
        t,
      ),
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

/// Typography roles for the existing Soft OS visual language.
///
/// These values intentionally mirror the current application at a 1.0 text
/// scale.  Roles make the hierarchy reusable without redesigning existing
/// screens.
@immutable
class SurgeTypography {
  const SurgeTypography({
    required this.title,
    required this.body,
    required this.caption,
    required this.sectionTitle,
    required this.appBarTitle,
    required this.heroTitle,
    required this.cardTitle,
    required this.rowTitle,
    required this.rowSubtitle,
    required this.fieldInput,
    required this.fieldHint,
    required this.emptyState,
    required this.metric,
    required this.badge,
    required this.micro,
    required this.dashboardMicro,
    required this.dashboardTiny,
    required this.dashboardValue,
    required this.dashboardLabel,
    required this.dashboardLoading,
  });

  factory SurgeTypography.regular(SurgeColors colors) {
    return SurgeTypography(
      title: TextStyle(
        color: colors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      body: TextStyle(
        color: colors.textPrimary,
        fontSize: 15,
        letterSpacing: 0,
      ),
      caption: TextStyle(
        color: colors.textSecondary,
        fontSize: 13,
        letterSpacing: 0,
      ),
      sectionTitle: TextStyle(
        color: colors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      appBarTitle: TextStyle(
        color: colors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      heroTitle: TextStyle(
        color: colors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w500,
        height: 1,
        letterSpacing: 0,
      ),
      cardTitle: TextStyle(
        color: colors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      rowTitle: TextStyle(
        color: colors.textPrimary,
        fontSize: 16,
        letterSpacing: 0,
      ),
      rowSubtitle: TextStyle(
        color: colors.textSecondary,
        fontSize: 13,
        letterSpacing: 0,
      ),
      fieldInput: TextStyle(color: colors.textPrimary, fontSize: 14),
      fieldHint: TextStyle(color: colors.textSecondary, fontSize: 14),
      emptyState: TextStyle(color: colors.textSecondary),
      metric: TextStyle(
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      badge: TextStyle(
        color: colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1,
        letterSpacing: 0,
      ),
      micro: TextStyle(
        color: colors.textSecondary,
        fontSize: 11,
        letterSpacing: 0,
      ),
      dashboardMicro: TextStyle(
        color: colors.textSecondary,
        fontSize: 8,
        letterSpacing: 0,
      ),
      dashboardTiny: TextStyle(
        color: colors.textSecondary,
        fontSize: 10,
        letterSpacing: 0,
      ),
      dashboardValue: TextStyle(
        color: colors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1,
        letterSpacing: 0,
      ),
      dashboardLabel: TextStyle(
        color: colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1,
        letterSpacing: 0,
      ),
      dashboardLoading: TextStyle(
        color: colors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 1,
      ),
    );
  }

  final TextStyle title;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle sectionTitle;
  final TextStyle appBarTitle;
  final TextStyle heroTitle;
  final TextStyle cardTitle;
  final TextStyle rowTitle;
  final TextStyle rowSubtitle;
  final TextStyle fieldInput;
  final TextStyle fieldHint;
  final TextStyle emptyState;
  final TextStyle metric;
  final TextStyle badge;
  final TextStyle micro;
  final TextStyle dashboardMicro;
  final TextStyle dashboardTiny;
  final TextStyle dashboardValue;
  final TextStyle dashboardLabel;
  final TextStyle dashboardLoading;

  static SurgeTypography lerp(SurgeTypography a, SurgeTypography b, double t) {
    return SurgeTypography(
      title: TextStyle.lerp(a.title, b.title, t)!,
      body: TextStyle.lerp(a.body, b.body, t)!,
      caption: TextStyle.lerp(a.caption, b.caption, t)!,
      sectionTitle: TextStyle.lerp(a.sectionTitle, b.sectionTitle, t)!,
      appBarTitle: TextStyle.lerp(a.appBarTitle, b.appBarTitle, t)!,
      heroTitle: TextStyle.lerp(a.heroTitle, b.heroTitle, t)!,
      cardTitle: TextStyle.lerp(a.cardTitle, b.cardTitle, t)!,
      rowTitle: TextStyle.lerp(a.rowTitle, b.rowTitle, t)!,
      rowSubtitle: TextStyle.lerp(a.rowSubtitle, b.rowSubtitle, t)!,
      fieldInput: TextStyle.lerp(a.fieldInput, b.fieldInput, t)!,
      fieldHint: TextStyle.lerp(a.fieldHint, b.fieldHint, t)!,
      emptyState: TextStyle.lerp(a.emptyState, b.emptyState, t)!,
      metric: TextStyle.lerp(a.metric, b.metric, t)!,
      badge: TextStyle.lerp(a.badge, b.badge, t)!,
      micro: TextStyle.lerp(a.micro, b.micro, t)!,
      dashboardMicro: TextStyle.lerp(a.dashboardMicro, b.dashboardMicro, t)!,
      dashboardTiny: TextStyle.lerp(a.dashboardTiny, b.dashboardTiny, t)!,
      dashboardValue: TextStyle.lerp(a.dashboardValue, b.dashboardValue, t)!,
      dashboardLabel: TextStyle.lerp(a.dashboardLabel, b.dashboardLabel, t)!,
      dashboardLoading: TextStyle.lerp(
        a.dashboardLoading,
        b.dashboardLoading,
        t,
      )!,
    );
  }
}

/// Named state, traffic, and dashboard colors which previously lived in page
/// constants.  Keeping the original values makes this a rendering-equivalent
/// refactor for fixed and dynamic themes.
@immutable
class SurgeSemanticColors {
  const SurgeSemanticColors({
    required this.connected,
    required this.connecting,
    required this.disconnected,
    required this.paused,
    required this.error,
    required this.dashboardDynamicActive,
    required this.dashboardActiveGreen,
    required this.dashboardInactive,
    required this.dashboardInactiveVariant,
    required this.latencyGood,
    required this.latencyMedium,
    required this.latencyBad,
    required this.statusLightActive,
    required this.statusLightError,
    required this.profileSelectionBorderFixed,
  });

  factory SurgeSemanticColors.regular(SurgeColors colors) {
    return SurgeSemanticColors(
      connected: const Color(0xFF2FAA67),
      connecting: const Color(0xFF2FAA67),
      disconnected: colors.textSecondary,
      paused: const Color(0xFFDC851B),
      error: colors.red,
      dashboardDynamicActive: const Color(0xFFA06B3B),
      dashboardActiveGreen: const Color(0xFF5BA66A),
      dashboardInactive: const Color(0xFF858681),
      dashboardInactiveVariant: const Color(0xFFA5A6A1),
      latencyGood: const Color(0xFFADDFAD),
      latencyMedium: const Color(0xFFF1C892),
      latencyBad: const Color(0xFFFFBBBD),
      statusLightActive: const Color(0xFF7BFFB2),
      statusLightError: const Color(0xFFFF8A80),
      profileSelectionBorderFixed: const Color(0xFFD8DAE0),
    );
  }

  final Color connected;
  final Color connecting;
  final Color disconnected;
  final Color paused;
  final Color error;
  final Color dashboardDynamicActive;
  final Color dashboardActiveGreen;
  final Color dashboardInactive;
  final Color dashboardInactiveVariant;
  final Color latencyGood;
  final Color latencyMedium;
  final Color latencyBad;
  final Color statusLightActive;
  final Color statusLightError;
  final Color profileSelectionBorderFixed;

  static SurgeSemanticColors lerp(
    SurgeSemanticColors a,
    SurgeSemanticColors b,
    double t,
  ) {
    return SurgeSemanticColors(
      connected: Color.lerp(a.connected, b.connected, t)!,
      connecting: Color.lerp(a.connecting, b.connecting, t)!,
      disconnected: Color.lerp(a.disconnected, b.disconnected, t)!,
      paused: Color.lerp(a.paused, b.paused, t)!,
      error: Color.lerp(a.error, b.error, t)!,
      dashboardDynamicActive: Color.lerp(
        a.dashboardDynamicActive,
        b.dashboardDynamicActive,
        t,
      )!,
      dashboardActiveGreen: Color.lerp(
        a.dashboardActiveGreen,
        b.dashboardActiveGreen,
        t,
      )!,
      dashboardInactive: Color.lerp(
        a.dashboardInactive,
        b.dashboardInactive,
        t,
      )!,
      dashboardInactiveVariant: Color.lerp(
        a.dashboardInactiveVariant,
        b.dashboardInactiveVariant,
        t,
      )!,
      latencyGood: Color.lerp(a.latencyGood, b.latencyGood, t)!,
      latencyMedium: Color.lerp(a.latencyMedium, b.latencyMedium, t)!,
      latencyBad: Color.lerp(a.latencyBad, b.latencyBad, t)!,
      statusLightActive: Color.lerp(
        a.statusLightActive,
        b.statusLightActive,
        t,
      )!,
      statusLightError: Color.lerp(a.statusLightError, b.statusLightError, t)!,
      profileSelectionBorderFixed: Color.lerp(
        a.profileSelectionBorderFixed,
        b.profileSelectionBorderFixed,
        t,
      )!,
    );
  }
}

@immutable
class SurgeControlSizes {
  const SurgeControlSizes({
    required this.minimumTapExtent,
    required this.actionTapExtent,
    required this.actionVisualHeight,
    required this.compactActionVisualHeight,
    required this.statusPillHeight,
    required this.selectPillHeight,
    required this.segmentedHeight,
    required this.dockButtonWidth,
  });

  factory SurgeControlSizes.regular() {
    return const SurgeControlSizes(
      minimumTapExtent: 44,
      actionTapExtent: 48,
      actionVisualHeight: 34,
      compactActionVisualHeight: 32,
      statusPillHeight: 30,
      selectPillHeight: 38,
      segmentedHeight: 34,
      dockButtonWidth: 36,
    );
  }

  final double minimumTapExtent;
  final double actionTapExtent;
  final double actionVisualHeight;
  final double compactActionVisualHeight;
  final double statusPillHeight;
  final double selectPillHeight;
  final double segmentedHeight;
  final double dockButtonWidth;

  static SurgeControlSizes lerp(
    SurgeControlSizes a,
    SurgeControlSizes b,
    double t,
  ) {
    return SurgeControlSizes(
      minimumTapExtent: lerpDouble(a.minimumTapExtent, b.minimumTapExtent, t),
      actionTapExtent: lerpDouble(a.actionTapExtent, b.actionTapExtent, t),
      actionVisualHeight: lerpDouble(
        a.actionVisualHeight,
        b.actionVisualHeight,
        t,
      ),
      compactActionVisualHeight: lerpDouble(
        a.compactActionVisualHeight,
        b.compactActionVisualHeight,
        t,
      ),
      statusPillHeight: lerpDouble(a.statusPillHeight, b.statusPillHeight, t),
      selectPillHeight: lerpDouble(a.selectPillHeight, b.selectPillHeight, t),
      segmentedHeight: lerpDouble(a.segmentedHeight, b.segmentedHeight, t),
      dockButtonWidth: lerpDouble(a.dockButtonWidth, b.dockButtonWidth, t),
    );
  }
}

@immutable
class SurgeOpacity {
  const SurgeOpacity({
    required this.selectedSurface,
    required this.actionSurfaceLight,
    required this.actionSurfaceDark,
    required this.actionBorderLight,
    required this.actionBorderDark,
    required this.statusSurface,
    required this.statusBorder,
  });

  factory SurgeOpacity.regular() {
    return const SurgeOpacity(
      selectedSurface: 0.045,
      actionSurfaceLight: 0.12,
      actionSurfaceDark: 0.22,
      actionBorderLight: 0.22,
      actionBorderDark: 0.34,
      statusSurface: 0.10,
      statusBorder: 0.22,
    );
  }

  final double selectedSurface;
  final double actionSurfaceLight;
  final double actionSurfaceDark;
  final double actionBorderLight;
  final double actionBorderDark;
  final double statusSurface;
  final double statusBorder;

  static SurgeOpacity lerp(SurgeOpacity a, SurgeOpacity b, double t) {
    return SurgeOpacity(
      selectedSurface: lerpDouble(a.selectedSurface, b.selectedSurface, t),
      actionSurfaceLight: lerpDouble(
        a.actionSurfaceLight,
        b.actionSurfaceLight,
        t,
      ),
      actionSurfaceDark: lerpDouble(
        a.actionSurfaceDark,
        b.actionSurfaceDark,
        t,
      ),
      actionBorderLight: lerpDouble(
        a.actionBorderLight,
        b.actionBorderLight,
        t,
      ),
      actionBorderDark: lerpDouble(a.actionBorderDark, b.actionBorderDark, t),
      statusSurface: lerpDouble(a.statusSurface, b.statusSurface, t),
      statusBorder: lerpDouble(a.statusBorder, b.statusBorder, t),
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

double lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
