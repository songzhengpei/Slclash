import 'package:flutter/material.dart';

export '../../theme/typography/surge_typography.dart';

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

/// Named state, traffic, and dashboard colors which previously lived in page
/// constants.  Keeping the original values makes this a rendering-equivalent
/// refactor for fixed and dynamic themes.
@immutable
class SurgeStateColors {
  const SurgeStateColors({
    required this.toggleActive,
    required this.onToggleActive,
    required this.heroStart,
    required this.heroPause,
    required this.heroStop,
    required this.onHeroAction,
  });

  final Color toggleActive;
  final Color onToggleActive;
  final Color heroStart;
  final Color heroPause;
  final Color heroStop;
  final Color onHeroAction;

  /// The active-profile status intentionally shares the mainline start green.
  Color get profileActive => heroStart;

  static SurgeStateColors lerp(
    SurgeStateColors a,
    SurgeStateColors b,
    double t,
  ) {
    return SurgeStateColors(
      toggleActive: Color.lerp(a.toggleActive, b.toggleActive, t)!,
      onToggleActive: Color.lerp(a.onToggleActive, b.onToggleActive, t)!,
      heroStart: Color.lerp(a.heroStart, b.heroStart, t)!,
      heroPause: Color.lerp(a.heroPause, b.heroPause, t)!,
      heroStop: Color.lerp(a.heroStop, b.heroStop, t)!,
      onHeroAction: Color.lerp(a.onHeroAction, b.onHeroAction, t)!,
    );
  }
}

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
    required this.statusLightPaused,
    required this.statusLightError,
    required this.profileSelectionBorderFixed,
    required this.state,
  });

  factory SurgeSemanticColors.regular(
    SurgeColors colors, {
    SurgeStateColors? state,
  }) {
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
      statusLightPaused: const Color(0xFFFF9500),
      statusLightError: const Color(0xFFFF8A80),
      profileSelectionBorderFixed: const Color(0xFFD8DAE0),
      state:
          state ??
          SurgeStateColors(
            toggleActive: colors.primary,
            onToggleActive: colors.onPrimary,
            heroStart: colors.green,
            heroPause: colors.orange,
            heroStop: colors.red,
            onHeroAction: Colors.white,
          ),
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
  final Color statusLightPaused;
  final Color statusLightError;
  final Color profileSelectionBorderFixed;
  final SurgeStateColors state;

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
      statusLightPaused: Color.lerp(
        a.statusLightPaused,
        b.statusLightPaused,
        t,
      )!,
      statusLightError: Color.lerp(a.statusLightError, b.statusLightError, t)!,
      profileSelectionBorderFixed: Color.lerp(
        a.profileSelectionBorderFixed,
        b.profileSelectionBorderFixed,
        t,
      )!,
      state: SurgeStateColors.lerp(a.state, b.state, t),
    );
  }
}

@immutable
class SurgeControlSizes {
  const SurgeControlSizes({
    required this.minimumTapExtent,
    required this.iconButtonTapExtent,
    required this.iconButtonVisualSize,
    required this.iconButtonIconSize,
    required this.actionTapExtent,
    required this.actionVisualHeight,
    required this.compactActionVisualHeight,
    required this.actionVisualWidth,
    required this.compactActionVisualWidth,
    required this.actionDockButtonWidth,
    required this.compactActionDockButtonWidth,
    required this.actionIconSize,
    required this.actionLoaderSize,
    required this.actionLoaderStrokeWidth,
    required this.actionDividerHeight,
    required this.actionShadowBlur,
    required this.actionShadowOffsetY,
    required this.shortTextActionVisualWidth,
    required this.shortTextActionTapWidth,
    required this.textActionMinWidth,
    required this.compactTextActionMinWidth,
    required this.textActionHorizontalPadding,
    required this.compactTextActionHorizontalPadding,
    required this.statusPillHeight,
    required this.statusPillHorizontalPadding,
    required this.selectPillHeight,
    required this.segmentedHeight,
    required this.dockButtonWidth,
    required this.dockButtonIconSize,
    required this.dockButtonLoaderSize,
    required this.dockButtonLoaderStrokeWidth,
    required this.dockDividerHeight,
  });

  factory SurgeControlSizes.regular() {
    return const SurgeControlSizes(
      minimumTapExtent: 44,
      iconButtonTapExtent: 44,
      iconButtonVisualSize: 32,
      iconButtonIconSize: 16,
      actionTapExtent: 48,
      actionVisualHeight: 34,
      compactActionVisualHeight: 32,
      actionVisualWidth: 40,
      compactActionVisualWidth: 38,
      actionDockButtonWidth: 44,
      compactActionDockButtonWidth: 40,
      actionIconSize: 16,
      actionLoaderSize: 15,
      actionLoaderStrokeWidth: 1.7,
      actionDividerHeight: 18,
      actionShadowBlur: 4,
      actionShadowOffsetY: 1,
      shortTextActionVisualWidth: 55,
      shortTextActionTapWidth: 56,
      textActionMinWidth: 50,
      compactTextActionMinWidth: 46,
      textActionHorizontalPadding: 12,
      compactTextActionHorizontalPadding: 10,
      statusPillHeight: 30,
      statusPillHorizontalPadding: 12,
      selectPillHeight: 38,
      segmentedHeight: 34,
      dockButtonWidth: 36,
      dockButtonIconSize: 15.5,
      dockButtonLoaderSize: 13,
      dockButtonLoaderStrokeWidth: 1.5,
      dockDividerHeight: 17,
    );
  }

  final double minimumTapExtent;
  final double iconButtonTapExtent;
  final double iconButtonVisualSize;
  final double iconButtonIconSize;
  final double actionTapExtent;
  final double actionVisualHeight;
  final double compactActionVisualHeight;
  final double actionVisualWidth;
  final double compactActionVisualWidth;
  final double actionDockButtonWidth;
  final double compactActionDockButtonWidth;
  final double actionIconSize;
  final double actionLoaderSize;
  final double actionLoaderStrokeWidth;
  final double actionDividerHeight;
  final double actionShadowBlur;
  final double actionShadowOffsetY;
  final double shortTextActionVisualWidth;
  final double shortTextActionTapWidth;
  final double textActionMinWidth;
  final double compactTextActionMinWidth;
  final double textActionHorizontalPadding;
  final double compactTextActionHorizontalPadding;
  final double statusPillHeight;
  final double statusPillHorizontalPadding;
  final double selectPillHeight;
  final double segmentedHeight;
  final double dockButtonWidth;
  final double dockButtonIconSize;
  final double dockButtonLoaderSize;
  final double dockButtonLoaderStrokeWidth;
  final double dockDividerHeight;

  static SurgeControlSizes lerp(
    SurgeControlSizes a,
    SurgeControlSizes b,
    double t,
  ) {
    return SurgeControlSizes(
      minimumTapExtent: lerpDouble(a.minimumTapExtent, b.minimumTapExtent, t),
      iconButtonTapExtent: lerpDouble(
        a.iconButtonTapExtent,
        b.iconButtonTapExtent,
        t,
      ),
      iconButtonVisualSize: lerpDouble(
        a.iconButtonVisualSize,
        b.iconButtonVisualSize,
        t,
      ),
      iconButtonIconSize: lerpDouble(
        a.iconButtonIconSize,
        b.iconButtonIconSize,
        t,
      ),
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
      actionVisualWidth: lerpDouble(
        a.actionVisualWidth,
        b.actionVisualWidth,
        t,
      ),
      compactActionVisualWidth: lerpDouble(
        a.compactActionVisualWidth,
        b.compactActionVisualWidth,
        t,
      ),
      actionDockButtonWidth: lerpDouble(
        a.actionDockButtonWidth,
        b.actionDockButtonWidth,
        t,
      ),
      compactActionDockButtonWidth: lerpDouble(
        a.compactActionDockButtonWidth,
        b.compactActionDockButtonWidth,
        t,
      ),
      actionIconSize: lerpDouble(a.actionIconSize, b.actionIconSize, t),
      actionLoaderSize: lerpDouble(a.actionLoaderSize, b.actionLoaderSize, t),
      actionLoaderStrokeWidth: lerpDouble(
        a.actionLoaderStrokeWidth,
        b.actionLoaderStrokeWidth,
        t,
      ),
      actionDividerHeight: lerpDouble(
        a.actionDividerHeight,
        b.actionDividerHeight,
        t,
      ),
      actionShadowBlur: lerpDouble(a.actionShadowBlur, b.actionShadowBlur, t),
      actionShadowOffsetY: lerpDouble(
        a.actionShadowOffsetY,
        b.actionShadowOffsetY,
        t,
      ),
      shortTextActionVisualWidth: lerpDouble(
        a.shortTextActionVisualWidth,
        b.shortTextActionVisualWidth,
        t,
      ),
      shortTextActionTapWidth: lerpDouble(
        a.shortTextActionTapWidth,
        b.shortTextActionTapWidth,
        t,
      ),
      textActionMinWidth: lerpDouble(
        a.textActionMinWidth,
        b.textActionMinWidth,
        t,
      ),
      compactTextActionMinWidth: lerpDouble(
        a.compactTextActionMinWidth,
        b.compactTextActionMinWidth,
        t,
      ),
      textActionHorizontalPadding: lerpDouble(
        a.textActionHorizontalPadding,
        b.textActionHorizontalPadding,
        t,
      ),
      compactTextActionHorizontalPadding: lerpDouble(
        a.compactTextActionHorizontalPadding,
        b.compactTextActionHorizontalPadding,
        t,
      ),
      statusPillHeight: lerpDouble(a.statusPillHeight, b.statusPillHeight, t),
      statusPillHorizontalPadding: lerpDouble(
        a.statusPillHorizontalPadding,
        b.statusPillHorizontalPadding,
        t,
      ),
      selectPillHeight: lerpDouble(a.selectPillHeight, b.selectPillHeight, t),
      segmentedHeight: lerpDouble(a.segmentedHeight, b.segmentedHeight, t),
      dockButtonWidth: lerpDouble(a.dockButtonWidth, b.dockButtonWidth, t),
      dockButtonIconSize: lerpDouble(
        a.dockButtonIconSize,
        b.dockButtonIconSize,
        t,
      ),
      dockButtonLoaderSize: lerpDouble(
        a.dockButtonLoaderSize,
        b.dockButtonLoaderSize,
        t,
      ),
      dockButtonLoaderStrokeWidth: lerpDouble(
        a.dockButtonLoaderStrokeWidth,
        b.dockButtonLoaderStrokeWidth,
        t,
      ),
      dockDividerHeight: lerpDouble(
        a.dockDividerHeight,
        b.dockDividerHeight,
        t,
      ),
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
    required this.actionForeground,
    required this.actionDisabledForeground,
    required this.actionShadowLight,
    required this.actionShadowDark,
    required this.iconButtonSurface,
    required this.iconButtonForeground,
    required this.controlSurface,
    required this.controlBorder,
    required this.dockForeground,
    required this.dockDivider,
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
      actionForeground: 0.96,
      actionDisabledForeground: 0.46,
      actionShadowLight: 0.04,
      actionShadowDark: 0.12,
      iconButtonSurface: 0.06,
      iconButtonForeground: 0.75,
      controlSurface: 0.052,
      controlBorder: 0.38,
      dockForeground: 0.70,
      dockDivider: 0.34,
      statusSurface: 0.10,
      statusBorder: 0.22,
    );
  }

  final double selectedSurface;
  final double actionSurfaceLight;
  final double actionSurfaceDark;
  final double actionBorderLight;
  final double actionBorderDark;
  final double actionForeground;
  final double actionDisabledForeground;
  final double actionShadowLight;
  final double actionShadowDark;
  final double iconButtonSurface;
  final double iconButtonForeground;
  final double controlSurface;
  final double controlBorder;
  final double dockForeground;
  final double dockDivider;
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
      actionForeground: lerpDouble(a.actionForeground, b.actionForeground, t),
      actionDisabledForeground: lerpDouble(
        a.actionDisabledForeground,
        b.actionDisabledForeground,
        t,
      ),
      actionShadowLight: lerpDouble(
        a.actionShadowLight,
        b.actionShadowLight,
        t,
      ),
      actionShadowDark: lerpDouble(a.actionShadowDark, b.actionShadowDark, t),
      iconButtonSurface: lerpDouble(
        a.iconButtonSurface,
        b.iconButtonSurface,
        t,
      ),
      iconButtonForeground: lerpDouble(
        a.iconButtonForeground,
        b.iconButtonForeground,
        t,
      ),
      controlSurface: lerpDouble(a.controlSurface, b.controlSurface, t),
      controlBorder: lerpDouble(a.controlBorder, b.controlBorder, t),
      dockForeground: lerpDouble(a.dockForeground, b.dockForeground, t),
      dockDivider: lerpDouble(a.dockDivider, b.dockDivider, t),
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
