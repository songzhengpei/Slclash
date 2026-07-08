import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

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

  double get _visualSize => compact ? 40 : 42;
  double get _iconSize => compact ? 19 : 20;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final enabled = onPressed != null && !loading;
    final foreground = enabled
        ? surge.textPrimary.withValues(alpha: 0.82)
        : surge.textSecondary.withValues(alpha: 0.42);
    final backgroundAlpha = enabled ? (compact ? 0.05 : 0.052) : 0.035;
    final borderAlpha = enabled ? (compact ? 0.40 : 0.44) : 0.30;

    Widget result = SizedBox.square(
      dimension: 48,
      child: Center(
        child: Material(
          color: surge.textSecondary.withValues(alpha: backgroundAlpha),
          shape: CircleBorder(
            side: BorderSide(
              color: surge.separator.withValues(alpha: borderAlpha),
              width: surge.spacing.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: _visualSize,
              child: Center(
                child: loading
                    ? SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: foreground,
                        ),
                      )
                    : IconTheme.merge(
                        data: IconThemeData(size: _iconSize, color: foreground),
                        child:
                            child ??
                            Icon(icon, size: _iconSize, color: foreground),
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

/// AppBar-level pill dock for two or more actions.
class SoftOsActionDock extends StatelessWidget {
  const SoftOsActionDock({
    super.key,
    required this.children,
    this.compact = false,
  });

  final List<Widget> children;
  final bool compact;

  double get _height => compact ? 42 : 44;
  double get _radius => compact ? 21 : 22;
  double get _surfaceAlpha => compact ? 0.05 : 0.052;
  double get _borderAlpha => compact ? 0.40 : 0.44;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      height: 48,
      child: Center(
        child: Material(
          color: surge.textSecondary.withValues(alpha: _surfaceAlpha),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: BorderSide(
              color: surge.separator.withValues(alpha: _borderAlpha),
              width: surge.spacing.hairline,
            ),
          ),
          child: SizedBox(
            height: _height,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
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

  double get _iconSize => compact ? 19 : 20;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final enabled = onPressed != null && !loading;
    final foreground = enabled
        ? surge.textPrimary.withValues(alpha: 0.82)
        : surge.textSecondary.withValues(alpha: 0.42);

    Widget result = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: 44,
          height: 48,
          child: Center(
            child: loading
                ? SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
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
  const SoftOsActionDivider({super.key, this.height = 20, this.alpha = 0.40});

  final double height;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      height: 48,
      child: Center(
        child: SizedBox(
          height: height,
          child: VerticalDivider(
            width: 1,
            thickness: surge.spacing.hairline,
            color: surge.separator.withValues(alpha: alpha),
          ),
        ),
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
    final radius = borderRadius ?? height / 2;
    return SizedBox(
      height: tapHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surge.textSecondary.withValues(alpha: surfaceAlpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: surge.separator.withValues(alpha: borderAlpha),
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
