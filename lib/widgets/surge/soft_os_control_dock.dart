import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const double _softOsActionTapSize = 48;
const double _softOsActionVisualHeight = 34;
const double _softOsActionCompactVisualHeight = 32;
const double _softOsActionIconWidth = 40;
const double _softOsActionCompactIconWidth = 38;
const double _softOsActionDockButtonWidth = 44;
const double _softOsActionCompactDockButtonWidth = 40;
const double _softOsActionIconSize = 19;
const double _softOsActionCompactIconSize = 18.5;
const double _softOsShortTextVisualWidth = 55;
const double _softOsShortTextTapWidth = 56;

IconData normalizeSoftOsActionIcon(IconData icon) {
  return switch (icon) {
    Icons.close || Icons.close_rounded => CupertinoIcons.xmark,
    Icons.arrow_back ||
    Icons.arrow_back_rounded ||
    Icons.arrow_back_ios_new_rounded => CupertinoIcons.chevron_back,
    Icons.search || Icons.search_rounded => CupertinoIcons.search,
    Icons.check || Icons.check_rounded => CupertinoIcons.check_mark,
    Icons.add || Icons.add_rounded => CupertinoIcons.plus,
    Icons.save_as_outlined ||
    Icons.save_as_rounded => CupertinoIcons.square_arrow_down,
    Icons.delete ||
    Icons.delete_rounded ||
    Icons.delete_outline ||
    Icons.delete_outline_rounded ||
    Icons.delete_sweep_outlined ||
    Icons.delete_sweep_rounded => CupertinoIcons.trash,
    Icons.filter_alt_outlined ||
    Icons.settings_outlined ||
    Icons.tune ||
    Icons.tune_rounded => CupertinoIcons.slider_horizontal_3,
    Icons.sync || Icons.sync_rounded => CupertinoIcons.arrow_2_circlepath,
    Icons.cloud_sync ||
    Icons.cloud_sync_rounded => CupertinoIcons.cloud_download,
    Icons.refresh ||
    Icons.refresh_rounded ||
    Icons.replay ||
    Icons.replay_rounded => CupertinoIcons.arrow_counterclockwise,
    Icons.more_horiz ||
    Icons.more_horiz_rounded ||
    Icons.more_vert ||
    Icons.more_vert_rounded => CupertinoIcons.ellipsis,
    _ => icon,
  };
}

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
    return SizedBox(
      width: tapSize,
      height: tapSize,
      child: Center(
        child: Material(
          color: surge.textSecondary.withValues(alpha: 0.06),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: visualSize,
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
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
  double get _radius => _visualHeight / 2;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final enabled = onPressed != null && !loading;
    final foreground = _softOsActionForeground(context, enabled);
    final radius = BorderRadius.circular(_radius);

    Widget result = SizedBox.square(
      dimension: _softOsActionTapSize,
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
            child: SizedBox(width: _visualWidth, height: _visualHeight),
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
                            size: _iconSize,
                            color: foreground,
                          ),
                          child:
                              child ??
                              Icon(icon, size: _iconSize, color: foreground),
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
  double get _radius => _height / 2;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      height: _softOsActionTapSize,
      child: IntrinsicWidth(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: (_softOsActionTapSize - _height) / 2,
              bottom: (_softOsActionTapSize - _height) / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _softOsActionSurface(context),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: _softOsActionBorder(context),
                    width: surge.spacing.hairline,
                  ),
                  boxShadow: _softOsActionShadows(context),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: _softOsActionTapSize,
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

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final foreground = _softOsActionForeground(context, enabled);

    Widget result = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: _width,
          height: _softOsActionTapSize,
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
                    data: IconThemeData(size: _iconSize, color: foreground),
                    child:
                        child ?? Icon(icon, size: _iconSize, color: foreground),
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
    return SizedBox(
      height: _softOsActionTapSize,
      child: Center(
        child: SizedBox(
          height: height,
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
  double get _radius => _visualHeight / 2;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final enabled = onPressed != null;
    final foreground = _softOsActionForeground(context, enabled);
    final radius = BorderRadius.circular(_radius);

    Widget result = SizedBox(
      width: _tapWidth,
      height: _softOsActionTapSize,
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
                  minWidth: _minWidth,
                  maxWidth: _visualWidth ?? double.infinity,
                ),
                child: SizedBox(
                  width: _visualWidth,
                  height: _visualHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _horizontalPadding,
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
    final enabled = onPressed != null;
    final foreground = _softOsActionForeground(context, enabled);

    Widget result = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: _minWidth),
          child: SizedBox(
            height: _softOsActionTapSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                icon: normalizeSoftOsActionIcon(Icons.more_vert),
                onPressed: handleOpen,
                tooltip: tooltip,
                compact: compact,
              )
            : SoftOsActionButton(
                icon: normalizeSoftOsActionIcon(Icons.more_vert),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? height / 2;
    final effectiveSurfaceAlpha = isDark
        ? surfaceAlpha.clamp(0.09, 1.0).toDouble()
        : surfaceAlpha;
    final effectiveBorderAlpha = isDark
        ? borderAlpha.clamp(0.48, 1.0).toDouble()
        : borderAlpha;
    return SizedBox(
      height: tapHeight,
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
            height: height,
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
            width: 36,
            height: 44,
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: foreground,
                      ),
                    )
                  : Icon(icon, size: iconSize, color: foreground),
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
    return SizedBox(
      height: 44,
      child: Center(
        child: SizedBox(
          height: height,
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
