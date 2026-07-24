import 'package:flutter/material.dart';

import 'soft_os_metrics.dart';
import 'surge_theme_extension.dart';

class SurgeStatusButton extends StatelessWidget {
  const SurgeStatusButton({
    super.key,
    required this.isActive,
    required this.activeLabel,
    required this.inactiveLabel,
    this.label,
    this.onPressed,
    this.loading = false,
    this.compact = false,
    this.activeIcon,
    this.inactiveIcon,
    this.activeColor,
    this.inactiveColor,
    this.height,
    this.horizontalPadding,
    this.minWidth,
    this.textStyle,
  });

  final bool isActive;
  final String? label;
  final String activeLabel;
  final String inactiveLabel;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;
  final IconData? activeIcon;
  final IconData? inactiveIcon;
  final Color? activeColor;
  final Color? inactiveColor;
  final double? height;
  final double? horizontalPadding;
  final double? minWidth;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final background = isActive
        ? activeColor ?? surge.green
        : inactiveColor ?? surge.primary;
    final text = label ?? (isActive ? activeLabel : inactiveLabel);
    final icon = isActive ? activeIcon : inactiveIcon;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final baseHeight = metrics.value(height ?? (compact ? 34 : 40));
    final effectiveHeight = baseHeight * (1 + (textScale - 1) * 0.45);

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        foregroundColor: surge.onPrimary,
        disabledForegroundColor: surge.onPrimary.withValues(alpha: 0.8),
        minimumSize: Size(
          metrics.value(minWidth ?? (compact ? 0 : 96)),
          effectiveHeight,
        ),
        maximumSize: Size(double.infinity, effectiveHeight),
        padding: EdgeInsets.symmetric(
          horizontal: metrics.value(horizontalPadding ?? (compact ? 12 : 16)),
          vertical: 0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surge.radii.button),
        ),
        alignment: Alignment.center,
        textStyle: textStyle ?? context.typography.controlLabel,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            SizedBox.square(
              dimension: metrics.value(compact ? 13 : 15),
              child: CircularProgressIndicator(
                color: surge.onPrimary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Icon(icon, size: metrics.value(compact ? 14 : 16)),
            SizedBox(width: metrics.value(6)),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
