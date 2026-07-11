import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:flutter/material.dart';

const double _softOsActionTapSize = 48;
const double _softOsActionVisualHeight = 34;
const double _softOsActionCompactVisualHeight = 32;
const double _softOsActionIconWidth = 40;
const double _softOsActionCompactIconWidth = 38;
const double _softOsActionDockButtonWidth = 44;
const double _softOsActionCompactDockButtonWidth = 40;
const double _softOsActionIconSize = SurgeIconSize.compact;
const double _softOsActionCompactIconSize = SurgeIconSize.compact;
const double _softOsShortTextVisualWidth = 55;
const double _softOsShortTextTapWidth = 56;

Color _softOsActionSurface(BuildContext context) {
  final surge = SurgeTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Color.alphaBlend(
    surge.textPrimary.withValues(alpha: isDark ? 0.22 : 0.12),
    surge.card,
  );
}

Color _softOsActionBorder(BuildContext context) {
  final surge = SurgeTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return surge.textPrimary.withValues(alpha: isDark ? 0.34 : 0.22);
}

Color _softOsActionForeground(BuildContext context, bool enabled) {
  final surge = SurgeTheme.of(context);
  return enabled
      ? surge.textPrimary.withValues(alpha: 0.96)
      : surge.textSecondary.withValues(alpha: 0.46);
}

List<BoxShadow> _softOsActionShadows(BuildContext context) {
  final surge = SurgeTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: surge.shadow.withValues(alpha: isDark ? 0.12 : 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
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
    this.iconSize = 16,
    this.visualSize = 32,
    this.tapSize = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double iconSize;
  final double visualSize;
  final double tapSize;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final effectiveTapSize = metrics.tap(tapSize);
    return SizedBox(
      width: effectiveTapSize,
      height: effectiveTapSize,
      child: Center(
        child: Material(
          color: surge.textSecondary.withValues(alpha: 0.06),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: metrics.value(visualSize),
              child: Center(
                child: Icon(
                  icon,
                  size: metrics.value(iconSize),
                  color: surge.textPrimary.withValues(alpha: 0.75),
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

  double get _visualWidth =>
      compact ? _softOsActionCompactIconWidth : _softOsActionIconWidth;
  double get _visualHeight =>
      compact ? _softOsActionCompactVisualHeight : _softOsActionVisualHeight;
  double get _iconSize =>
      compact ? _softOsActionCompactIconSize : _softOsActionIconSize;
  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final visualWidth = metrics.value(_visualWidth);
    final visualHeight = metrics.value(_visualHeight);
    final tapSize = metrics.tap(_softOsActionTapSize);
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
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: loading ? null : onPressed,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: loading
                      ? SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.7,
                            color: foreground,
                          ),
                        )
                      : IconTheme.merge(
                          data: IconThemeData(
                            size: metrics.value(_iconSize),
                            color: foreground,
                          ),
                          child:
                              child ??
                              Icon(
                                icon,
                                size: metrics.value(_iconSize),
                                color: foreground,
                              ),
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

  double get _height =>
      compact ? _softOsActionCompactVisualHeight : _softOsActionVisualHeight;
  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final height = metrics.value(_height);
    final tapSize = metrics.tap(_softOsActionTapSize);
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

  double get _iconSize =>
      compact ? _softOsActionCompactIconSize : _softOsActionIconSize;
  double get _width => compact
      ? _softOsActionCompactDockButtonWidth
      : _softOsActionDockButtonWidth;
  double get _visualHeight =>
      compact ? _softOsActionCompactVisualHeight : _softOsActionVisualHeight;

  @override
  Widget build(BuildContext context) {
    final metrics = SoftOsMetrics.of(context);
    final width = metrics.value(_width);
    final visualHeight = metrics.value(_visualHeight);
    final tapSize = metrics.tap(_softOsActionTapSize);
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
          overlayOpacity: 0.045,
          borderRadius: BorderRadius.circular(visualHeight / 2),
          child: SizedBox(
            width: width,
            height: visualHeight,
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.7,
                        color: foreground,
                      ),
                    )
                  : IconTheme.merge(
                      data: IconThemeData(
                        size: metrics.value(_iconSize),
                        color: foreground,
                      ),
                      child:
                          child ??
                          Icon(
                            icon,
                            size: metrics.value(_iconSize),
                            color: foreground,
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
    return result;
  }
}

/// A thin divider for [SoftOsActionDock].
class SoftOsActionDivider extends StatelessWidget {
  const SoftOsActionDivider({super.key, this.height = 18, this.alpha = 0.28});

  final double height;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    return SizedBox(
      height: metrics.tap(_softOsActionTapSize),
      child: Center(
        child: SizedBox(
          height: metrics.value(height),
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

  double get _visualHeight =>
      compact ? _softOsActionCompactVisualHeight : _softOsActionVisualHeight;
  bool get _isShortLabel => label.trim().runes.length <= 2;
  double get _minWidth => _isShortLabel ? _softOsShortTextVisualWidth : 50;
  double? get _tapWidth => _isShortLabel ? _softOsShortTextTapWidth : null;
  double? get _visualWidth =>
      _isShortLabel ? _softOsShortTextVisualWidth : null;
  double get _horizontalPadding => _isShortLabel ? 0 : (compact ? 10 : 12);
  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final visualHeight = metrics.value(_visualHeight);
    final minWidth = metrics.value(_minWidth);
    final tapWidth = _tapWidth == null ? null : metrics.value(_tapWidth!);
    final visualWidth = _visualWidth == null
        ? null
        : metrics.value(_visualWidth!);
    final tapHeight = metrics.tap(_softOsActionTapSize);
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
                      horizontal: metrics.value(_horizontalPadding),
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
        style: TextStyle(color: foreground),
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

  double get _minWidth => compact ? 46 : 50;

  @override
  Widget build(BuildContext context) {
    final metrics = SoftOsMetrics.of(context);
    final enabled = onPressed != null;
    final foreground = _softOsActionForeground(context, enabled);

    Widget result = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: metrics.value(_minWidth)),
          child: SizedBox(
            height: metrics.tap(_softOsActionTapSize),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.value(10)),
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
        style: TextStyle(color: foreground),
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
    this.loading = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? accentColor;
  final double? width;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final accent = accentColor ?? surge.textSecondary;
    final active = accentColor != null;
    final height = metrics.value(30);
    final radius = BorderRadius.circular(height / 2);
    return SurgePressable(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      compact: true,
      borderRadius: radius,
      overlayOpacity: 0.045,
      child: AnimatedContainer(
        duration: SurgeMotion.state,
        curve: SurgeMotion.stateCurve,
        width: width == null ? null : metrics.value(width!),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: metrics.value(12)),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.10)
              : _softOsActionSurface(context),
          borderRadius: radius,
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.22)
                : _softOsActionBorder(context),
            width: surge.spacing.hairline,
          ),
          boxShadow: active ? const [] : _softOsActionShadows(context),
        ),
        alignment: Alignment.center,
        child: child,
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
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: color,
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
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
    this.height = 34,
    this.tapHeight = 44,
    this.surfaceAlpha = 0.052,
    this.borderAlpha = 0.38,
    this.borderRadius,
    required this.children,
  });

  final double height;
  final double tapHeight;
  final double surfaceAlpha;
  final double borderAlpha;
  final double? borderRadius;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveHeight = metrics.value(height);
    final effectiveTapHeight = metrics.tap(tapHeight);
    final radius = borderRadius == null
        ? effectiveHeight / 2
        : metrics.value(borderRadius!);
    final effectiveSurfaceAlpha = isDark
        ? surfaceAlpha.clamp(0.09, 1.0).toDouble()
        : surfaceAlpha;
    final effectiveBorderAlpha = isDark
        ? borderAlpha.clamp(0.48, 1.0).toDouble()
        : borderAlpha;
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
    this.iconSize = 15.5,
    this.foregroundAlpha = 0.70,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final double iconSize;
  final double foregroundAlpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final foreground = loading
        ? surge.textSecondary
        : surge.textPrimary.withValues(alpha: foregroundAlpha);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: metrics.value(36),
            height: metrics.tap(44),
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: foreground,
                      ),
                    )
                  : Icon(
                      icon,
                      size: metrics.value(iconSize),
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
  const SoftOsDockDivider({
    super.key,
    this.height = 17,
    this.dividerAlpha = 0.34,
  });

  final double height;
  final double dividerAlpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    return SizedBox(
      height: metrics.tap(44),
      child: Center(
        child: SizedBox(
          height: metrics.value(height),
          child: VerticalDivider(
            width: 1,
            thickness: surge.spacing.hairline,
            color: surge.separator.withValues(alpha: dividerAlpha),
          ),
        ),
      ),
    );
  }
}
