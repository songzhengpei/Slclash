import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:flutter/material.dart';

/// Applies the dedicated top app-bar capsule treatment without changing the
/// shared Soft OS controls used by sheets, cards, and lists.
class SoftOsAppBarActionTemplate extends InheritedWidget {
  const SoftOsAppBarActionTemplate({super.key, required super.child});

  static bool active(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SoftOsAppBarActionTemplate>() !=
        null;
  }

  @override
  bool updateShouldNotify(SoftOsAppBarActionTemplate oldWidget) => false;
}

/// Marks the lightweight controls placed in a bottom sheet's title bar.
class SoftOsSheetActionTemplate extends InheritedWidget {
  const SoftOsSheetActionTemplate({
    super.key,
    required this.surfaceColor,
    required super.child,
  });

  final Color surfaceColor;

  static Color? surfaceOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SoftOsSheetActionTemplate>()
        ?.surfaceColor;
  }

  @override
  bool updateShouldNotify(SoftOsSheetActionTemplate oldWidget) =>
      oldWidget.surfaceColor != surfaceColor;
}

Color _softOsActionSurface(BuildContext context) {
  final surge = SurgeTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (SoftOsAppBarActionTemplate.active(context)) {
    return Color.alphaBlend(
      surge.textPrimary.withValues(alpha: isDark ? 0.10 : 0.025),
      surge.background,
    );
  }
  final sheetSurface = SoftOsSheetActionTemplate.surfaceOf(context);
  if (sheetSurface != null) {
    return sheetSurface;
  }
  return Color.alphaBlend(
    surge.textPrimary.withValues(
      alpha: isDark
          ? surge.opacity.actionSurfaceDark
          : surge.opacity.actionSurfaceLight,
    ),
    surge.card,
  );
}

Color _softOsActionBorder(BuildContext context) {
  final surge = SurgeTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (SoftOsAppBarActionTemplate.active(context)) {
    return surge.separator;
  }
  return surge.textPrimary.withValues(
    alpha: isDark
        ? surge.opacity.actionBorderDark
        : surge.opacity.actionBorderLight,
  );
}

Color _softOsActionForeground(BuildContext context, bool enabled) {
  final surge = SurgeTheme.of(context);
  return enabled
      ? surge.textPrimary.withValues(alpha: surge.opacity.actionForeground)
      : surge.textSecondary.withValues(
          alpha: surge.opacity.actionDisabledForeground,
        );
}

List<BoxShadow> _softOsActionShadows(BuildContext context) {
  final surge = SurgeTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (SoftOsAppBarActionTemplate.active(context)) {
    return [
      BoxShadow(
        color: surge.shadow.withValues(alpha: 0.08),
        blurRadius: 3,
        offset: const Offset(0, 0.5),
      ),
      BoxShadow(
        color: surge.shadow.withValues(alpha: 0.035),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }
  return [
    BoxShadow(
      color: surge.shadow.withValues(
        alpha: isDark
            ? surge.opacity.actionShadowDark
            : surge.opacity.actionShadowLight,
      ),
      blurRadius: surge.controls.actionShadowBlur,
      offset: Offset(0, surge.controls.actionShadowOffsetY),
    ),
  ];
}

/// A standalone circular icon button following the Soft OS visual language.
///
/// Used for BottomSheet toolbar buttons where AppBar must not stretch the
/// button. Fixed 32dp visual size inside a 44dp tap target.
class SoftOsIconButton extends StatelessWidget {
  const SoftOsIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconSize,
    this.visualSize,
    this.tapSize,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double? iconSize;
  final double? visualSize;
  final double? tapSize;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final effectiveTapSize = metrics.tap(
      tapSize ?? surge.controls.iconButtonTapExtent,
    );
    final effectiveVisualSize = metrics.value(
      visualSize ?? surge.controls.iconButtonVisualSize,
    );
    final effectiveIconSize = metrics.value(
      iconSize ?? surge.controls.iconButtonIconSize,
    );
    return SizedBox(
      width: effectiveTapSize,
      height: effectiveTapSize,
      child: Center(
        child: Material(
          color: surge.textSecondary.withValues(
            alpha: surge.opacity.iconButtonSurface,
          ),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: effectiveVisualSize,
              child: Center(
                child: Icon(
                  icon,
                  size: effectiveIconSize,
                  color: surge.textPrimary.withValues(
                    alpha: surge.opacity.iconButtonForeground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// AppBar-level Soft OS action button.
///
/// This is intentionally larger than [SoftOsIconButton] so it visually balances
/// the heavy mobile page titles.
class SoftOsActionButton extends StatelessWidget {
  const SoftOsActionButton({
    super.key,
    this.icon,
    this.child,
    required this.onPressed,
    this.tooltip,
    this.loading = false,
    this.compact = false,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final visualWidth = metrics.value(
      compact
          ? surge.controls.compactActionVisualWidth
          : surge.controls.actionVisualWidth,
    );
    final visualHeight = metrics.value(
      compact
          ? surge.controls.compactActionVisualHeight
          : surge.controls.actionVisualHeight,
    );
    final appBarTemplate = SoftOsAppBarActionTemplate.active(context);
    final iconSize = metrics.value(
      appBarTemplate ? 18 : surge.controls.actionIconSize,
    );
    final tapSize = metrics.tap(surge.controls.actionTapExtent);
    final enabled = onPressed != null && !loading;
    final foreground = _softOsActionForeground(context, enabled);
    final radius = BorderRadius.circular(visualHeight / 2);

    Widget result = SizedBox.square(
      dimension: tapSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: _softOsActionSurface(context),
              borderRadius: radius,
              border: Border.all(
                color: _softOsActionBorder(context),
                width: surge.spacing.hairline,
              ),
              boxShadow: _softOsActionShadows(context),
            ),
            child: SizedBox(width: visualWidth, height: visualHeight),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(surge.radii.button),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: loading ? null : onPressed,
                borderRadius: BorderRadius.circular(surge.radii.button),
                child: Center(
                  child: loading
                      ? SizedBox.square(
                          dimension: metrics.value(
                            surge.controls.actionLoaderSize,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: surge.controls.actionLoaderStrokeWidth,
                            color: foreground,
                          ),
                        )
                      : IconTheme.merge(
                          data: IconThemeData(
                            size: iconSize,
                            color: foreground,
                            weight: appBarTemplate ? 600 : null,
                          ),
                          child:
                              child ??
                              Icon(icon, size: iconSize, color: foreground),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      result = Tooltip(message: tooltip!, child: result);
    }
    return result;
  }
}

/// AppBar-level pill dock for two or more actions.
class SoftOsActionDock extends StatelessWidget {
  const SoftOsActionDock({
    super.key,
    required this.children,
    this.compact = false,
  });

  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final height = metrics.value(
      compact
          ? surge.controls.compactActionVisualHeight
          : surge.controls.actionVisualHeight,
    );
    final tapSize = metrics.tap(surge.controls.actionTapExtent);
    return SizedBox(
      height: tapSize,
      child: IntrinsicWidth(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: (tapSize - height) / 2,
              bottom: (tapSize - height) / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _softOsActionSurface(context),
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(
                    color: _softOsActionBorder(context),
                    width: surge.spacing.hairline,
                  ),
                  boxShadow: _softOsActionShadows(context),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(tapSize / 2),
              child: SizedBox(
                height: tapSize,
                child: Row(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single independently clickable button inside [SoftOsActionDock].
class SoftOsActionDockButton extends StatelessWidget {
  const SoftOsActionDockButton({
    super.key,
    this.icon,
    this.child,
    required this.onPressed,
    this.tooltip,
    this.loading = false,
    this.compact = false,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final width = metrics.value(
      compact
          ? surge.controls.compactActionDockButtonWidth
          : surge.controls.actionDockButtonWidth,
    );
    final visualHeight = metrics.value(
      compact
          ? surge.controls.compactActionVisualHeight
          : surge.controls.actionVisualHeight,
    );
    final appBarTemplate = SoftOsAppBarActionTemplate.active(context);
    final iconSize = metrics.value(
      appBarTemplate ? 18 : surge.controls.actionIconSize,
    );
    final tapSize = metrics.tap(surge.controls.actionTapExtent);
    final enabled = onPressed != null && !loading;
    final foreground = _softOsActionForeground(context, enabled);

    Widget result = SizedBox(
      width: width,
      height: tapSize,
      child: Center(
        child: SurgePressable(
          onTap: loading ? null : onPressed,
          enabled: enabled,
          scaleFeedback: false,
          overlayOpacity: surge.opacity.selectedSurface,
          borderRadius: BorderRadius.circular(visualHeight / 2),
          child: SizedBox(
            width: width,
            height: visualHeight,
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: metrics.value(surge.controls.actionLoaderSize),
                      child: CircularProgressIndicator(
                        strokeWidth: surge.controls.actionLoaderStrokeWidth,
                        color: foreground,
                      ),
                    )
                  : IconTheme.merge(
                      data: IconThemeData(
                        size: iconSize,
                        color: foreground,
                        weight: appBarTemplate ? 600 : null,
                      ),
                      child:
                          child ??
                          Icon(icon, size: iconSize, color: foreground),
                    ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      result = Tooltip(message: tooltip!, child: result);
    }
    return result;
  }
}

/// A thin divider for [SoftOsActionDock].
class SoftOsActionDivider extends StatelessWidget {
  const SoftOsActionDivider({super.key, this.height, this.alpha = 0.28});

  final double? height;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    return SizedBox(
      height: metrics.tap(surge.controls.actionTapExtent),
      child: Center(
        child: SizedBox(
          height: metrics.value(height ?? surge.controls.actionDividerHeight),
          child: VerticalDivider(
            width: 1,
            thickness: surge.spacing.hairline,
            color: surge.textPrimary.withValues(alpha: alpha),
          ),
        ),
      ),
    );
  }
}

/// AppBar-level text action matching [SoftOsActionButton].
class SoftOsActionTextButton extends StatelessWidget {
  const SoftOsActionTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool compact;

  bool get _isShortLabel => label.trim().runes.length <= 2;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final visualHeight = metrics.value(
      compact
          ? surge.controls.compactActionVisualHeight
          : surge.controls.actionVisualHeight,
    );
    final minWidth = metrics.value(
      _isShortLabel
          ? surge.controls.shortTextActionVisualWidth
          : surge.controls.textActionMinWidth,
    );
    final tapWidth = _isShortLabel
        ? metrics.value(surge.controls.shortTextActionTapWidth)
        : null;
    final visualWidth = _isShortLabel
        ? metrics.value(surge.controls.shortTextActionVisualWidth)
        : null;
    final horizontalPadding = _isShortLabel
        ? 0.0
        : metrics.value(
            compact
                ? surge.controls.compactTextActionHorizontalPadding
                : surge.controls.textActionHorizontalPadding,
          );
    final tapHeight = metrics.tap(surge.controls.actionTapExtent);
    final enabled = onPressed != null;
    final foreground = _softOsActionForeground(context, enabled);
    final radius = BorderRadius.circular(visualHeight / 2);

    Widget result = SizedBox(
      width: tapWidth,
      height: tapHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _softOsActionSurface(context),
            borderRadius: radius,
            border: Border.all(
              color: _softOsActionBorder(context),
              width: surge.spacing.hairline,
            ),
            boxShadow: _softOsActionShadows(context),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minWidth,
                  maxWidth: visualWidth ?? double.infinity,
                ),
                child: SizedBox(
                  width: visualWidth,
                  height: visualHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Center(child: _SoftOsActionText(label: label)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      result = Tooltip(message: tooltip!, child: result);
    }
    return IconTheme.merge(
      data: IconThemeData(color: foreground),
      child: DefaultTextStyle.merge(
        style: context.typography.controlLabel.copyWith(color: foreground),
        child: result,
      ),
    );
  }
}

/// A text segment inside [SoftOsActionDock].
class SoftOsActionDockTextButton extends StatelessWidget {
  const SoftOsActionDockTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final enabled = onPressed != null;
    final foreground = _softOsActionForeground(context, enabled);
    final minWidth = metrics.value(
      compact
          ? surge.controls.compactTextActionMinWidth
          : surge.controls.textActionMinWidth,
    );
    final horizontalPadding = metrics.value(
      surge.controls.compactTextActionHorizontalPadding,
    );

    Widget result = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: SizedBox(
            height: metrics.tap(surge.controls.actionTapExtent),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Center(child: _SoftOsActionText(label: label)),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      result = Tooltip(message: tooltip!, child: result);
    }
    return IconTheme.merge(
      data: IconThemeData(color: foreground),
      child: DefaultTextStyle.merge(
        style: context.typography.controlLabel.copyWith(color: foreground),
        child: result,
      ),
    );
  }
}

/// Compact status/action capsule used inside Soft OS cards and lists.
class SoftOsStatusPill extends StatelessWidget {
  const SoftOsStatusPill({
    super.key,
    required this.child,
    this.onPressed,
    this.accentColor,
    this.width,
    this.minWidth,
    this.loading = false,
    this.semanticLabel,
    this.surfaceAlpha,
    this.borderAlpha,
    this.height,
    this.padding,
    this.duration = SurgeMotion.state,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? accentColor;
  final double? width;
  final double? minWidth;
  final bool loading;
  final String? semanticLabel;
  final double? surfaceAlpha;
  final double? borderAlpha;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final accent = accentColor ?? surge.textSecondary;
    final active = accentColor != null;
    final resolvedHeight = metrics.value(
      height ?? surge.controls.statusPillHeight,
    );
    final radius = BorderRadius.circular(resolvedHeight / 2);
    return Semantics(
      label: semanticLabel,
      enabled: onPressed != null && !loading,
      child: SurgePressable(
        onTap: loading ? null : onPressed,
        enabled: onPressed != null && !loading,
        compact: true,
        borderRadius: radius,
        overlayOpacity: surge.opacity.selectedSurface,
        child: AnimatedContainer(
          duration: duration,
          curve: SurgeMotion.stateCurve,
          constraints: minWidth == null
              ? null
              : BoxConstraints(minWidth: metrics.value(minWidth!)),
          width: width == null ? null : metrics.value(width!),
          height: resolvedHeight,
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: metrics.value(
                  surge.controls.statusPillHorizontalPadding,
                ),
              ),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(
                    alpha: surfaceAlpha ?? surge.opacity.statusSurface,
                  )
                : _softOsActionSurface(context),
            borderRadius: radius,
            border: Border.all(
              color: active
                  ? accent.withValues(
                      alpha: borderAlpha ?? surge.opacity.statusBorder,
                    )
                  : _softOsActionBorder(context),
              width: surge.spacing.hairline,
            ),
            boxShadow: active ? const [] : _softOsActionShadows(context),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

/// A stable popup entry point rendered with the AppBar Soft OS action style.
class SoftOsPopupActionButton extends StatelessWidget {
  const SoftOsPopupActionButton({
    super.key,
    required this.popup,
    this.inDock = false,
    this.compact = false,
    this.tooltip,
    this.offset = Offset.zero,
  });

  final Widget popup;
  final bool inDock;
  final bool compact;
  final String? tooltip;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return CommonPopupBox(
      popup: popup,
      targetBuilder: (open) {
        void handleOpen() {
          open(offset: offset);
        }

        return inDock
            ? SoftOsActionDockButton(
                icon: SurgeIcons.more,
                onPressed: handleOpen,
                tooltip: tooltip,
                compact: compact,
              )
            : SoftOsActionButton(
                icon: SurgeIcons.more,
                onPressed: handleOpen,
                tooltip: tooltip,
                compact: compact,
              );
      },
    );
  }
}

class _SoftOsActionText extends StatelessWidget {
  const _SoftOsActionText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      style: context.typography.controlLabel.copyWith(color: color),
    );
  }
}

/// A pill-shaped dock container following the Soft OS visual language.
///
/// Outer height is [tapHeight] (44dp) for real touch targets.
/// The visible pill with background/border is only [height] (34dp) tall,
/// centered vertically inside the tap area.
class SoftOsControlDock extends StatelessWidget {
  const SoftOsControlDock({
    super.key,
    this.height,
    this.tapHeight,
    this.surfaceAlpha,
    this.borderAlpha,
    this.borderRadius,
    required this.children,
  });

  final double? height;
  final double? tapHeight;
  final double? surfaceAlpha;
  final double? borderAlpha;
  final double? borderRadius;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveHeight = metrics.value(
      height ?? surge.controls.actionVisualHeight,
    );
    final effectiveTapHeight = metrics.tap(
      tapHeight ?? surge.controls.minimumTapExtent,
    );
    final radius = borderRadius == null
        ? effectiveHeight / 2
        : metrics.value(borderRadius!);
    final effectiveSurfaceAlpha = isDark
        ? (surfaceAlpha ?? surge.opacity.controlSurface)
              .clamp(0.09, 1.0)
              .toDouble()
        : surfaceAlpha ?? surge.opacity.controlSurface;
    final effectiveBorderAlpha = isDark
        ? (borderAlpha ?? surge.opacity.controlBorder)
              .clamp(0.48, 1.0)
              .toDouble()
        : borderAlpha ?? surge.opacity.controlBorder;
    return SizedBox(
      height: effectiveTapHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surge.textSecondary.withValues(alpha: effectiveSurfaceAlpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: surge.separator.withValues(alpha: effectiveBorderAlpha),
              width: surge.spacing.hairline,
            ),
          ),
          child: SizedBox(
            height: effectiveHeight,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// A single button inside [SoftOsControlDock].
///
/// Click area is 36dp wide × 44dp tall; the icon centers vertically
/// inside the visual pill. Taps are disabled while [loading] is true.
class SoftOsDockButton extends StatelessWidget {
  const SoftOsDockButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.iconSize,
    this.foregroundAlpha,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final double? iconSize;
  final double? foregroundAlpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final foreground = loading
        ? surge.textSecondary
        : surge.textPrimary.withValues(
            alpha: foregroundAlpha ?? surge.opacity.dockForeground,
          );
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: metrics.value(surge.controls.dockButtonWidth),
            height: metrics.tap(surge.controls.minimumTapExtent),
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: metrics.value(
                        surge.controls.dockButtonLoaderSize,
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: surge.controls.dockButtonLoaderStrokeWidth,
                        color: foreground,
                      ),
                    )
                  : Icon(
                      icon,
                      size: metrics.value(
                        iconSize ?? surge.controls.dockButtonIconSize,
                      ),
                      color: foreground,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin vertical divider inside [SoftOsControlDock], centered in the tap area.
class SoftOsDockDivider extends StatelessWidget {
  const SoftOsDockDivider({super.key, this.height, this.dividerAlpha});

  final double? height;
  final double? dividerAlpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    return SizedBox(
      height: metrics.tap(surge.controls.minimumTapExtent),
      child: Center(
        child: SizedBox(
          height: metrics.value(height ?? surge.controls.dockDividerHeight),
          child: VerticalDivider(
            width: 1,
            thickness: surge.spacing.hairline,
            color: surge.separator.withValues(
              alpha: dividerAlpha ?? surge.opacity.dockDivider,
            ),
          ),
        ),
      ),
    );
  }
}
