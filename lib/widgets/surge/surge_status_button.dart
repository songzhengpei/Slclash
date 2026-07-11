import 'package:flutter/material.dart';

import 'soft_os_metrics.dart';
import 'surge_theme_extension.dart';

class SurgeStatusButton extends StatelessWidget {
  const SurgeStatusButton({
    super.key,
    required this.isActive,
    this.label,
    this.activeLabel = 'Running',
    this.inactiveLabel = 'Stopped',
    this.onPressed,
    this.loading = false,
    this.compact = false,
    this.activeIcon,
    this.inactiveIcon,
    this.activeColor,
    this.inactiveColor,
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

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final background = isActive
        ? activeColor ?? surge.green
        : inactiveColor ?? surge.primary;
    final text = label ?? (isActive ? activeLabel : inactiveLabel);
    final icon = isActive ? activeIcon : inactiveIcon;
    final height = metrics.value(compact ? 34 : 40);

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        foregroundColor: surge.onPrimary,
        disabledForegroundColor: surge.onPrimary.withValues(alpha: 0.8),
        minimumSize: Size(compact ? 0 : metrics.value(96), height),
        padding: EdgeInsets.symmetric(
          horizontal: metrics.value(compact ? 12 : 16),
          vertical: 0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surge.radii.button),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
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
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
