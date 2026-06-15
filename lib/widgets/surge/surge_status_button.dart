import 'package:flutter/material.dart';

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
  });

  final bool isActive;
  final String? label;
  final String activeLabel;
  final String inactiveLabel;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final background = isActive ? surge.green : surge.primary;
    final text = label ?? (isActive ? activeLabel : inactiveLabel);

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        foregroundColor: surge.onPrimary,
        disabledForegroundColor: surge.onPrimary.withValues(alpha: 0.8),
        minimumSize: Size(compact ? 0 : 96, compact ? 34 : 40),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
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
            SizedBox(
              height: compact ? 13 : 15,
              width: compact ? 13 : 15,
              child: CircularProgressIndicator(
                color: surge.onPrimary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
