import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

class ProxiesEmptyState extends StatelessWidget {
  const ProxiesEmptyState({
    super.key,
    required this.label,
    this.description,
    this.actionLabel,
    this.onAction,
    this.actionLoading = false,
  });

  final String label;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionLoading;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_rounded,
              color: surge.textSecondary.withValues(alpha: 0.62),
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: surge.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: actionLoading ? null : onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: surge.primary,
                  disabledBackgroundColor: surge.primary.withValues(
                    alpha: 0.55,
                  ),
                  foregroundColor: surge.onPrimary,
                  disabledForegroundColor: surge.onPrimary.withValues(
                    alpha: 0.8,
                  ),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(surge.radii.button),
                  ),
                  textStyle: textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionLoading) ...[
                      SizedBox(
                        height: 13,
                        width: 13,
                        child: CircularProgressIndicator(
                          color: surge.onPrimary,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(actionLabel!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
