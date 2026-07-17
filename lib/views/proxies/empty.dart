import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

enum ProxiesEmptyStateKind { loading, timeout, coreUnavailable, failed, empty }

class ProxiesEmptyState extends StatelessWidget {
  const ProxiesEmptyState({
    super.key,
    required this.label,
    this.description,
    this.actionLabel,
    this.onAction,
    this.actionLoading = false,
    this.kind = ProxiesEmptyStateKind.empty,
  });

  final String label;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionLoading;
  final ProxiesEmptyStateKind kind;

  (IconData, Color) _visuals(SurgeTheme surge) => switch (kind) {
    ProxiesEmptyStateKind.loading => (SurgeIcons.cloudSync, surge.primary),
    ProxiesEmptyStateKind.timeout => (SurgeIcons.schedule, surge.orange),
    ProxiesEmptyStateKind.coreUnavailable => (
      SurgeIcons.wifiDisabled,
      surge.red,
    ),
    ProxiesEmptyStateKind.failed => (SurgeIcons.warning, surge.red),
    ProxiesEmptyStateKind.empty => (SurgeIcons.route, surge.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final metrics = SoftOsMetrics.of(context);
    final (icon, accent) = _visuals(surge);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: label,
                child: Container(
                  width: metrics.value(68),
                  height: metrics.value(68),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(surge.radii.card),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.16),
                      width: surge.spacing.hairline,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: actionLoading
                      ? SizedBox.square(
                          dimension: metrics.value(26),
                          child: CircularProgressIndicator(
                            color: accent,
                            strokeWidth: 2.4,
                          ),
                        )
                      : Icon(icon, color: accent, size: metrics.value(30)),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(surge.radii.button),
                ),
                child: Text(
                  kind == ProxiesEmptyStateKind.loading ? '连接中' : '代理状态',
                  style: surge.typography.badge.copyWith(color: accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: surge.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                SurgeStatusButton(
                  isActive: false,
                  label: actionLabel,
                  activeLabel: actionLabel!,
                  inactiveLabel: actionLabel!,
                  inactiveIcon: kind == ProxiesEmptyStateKind.coreUnavailable
                      ? SurgeIcons.cloudSync
                      : SurgeIcons.refresh,
                  inactiveColor: accent,
                  loading: actionLoading,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
