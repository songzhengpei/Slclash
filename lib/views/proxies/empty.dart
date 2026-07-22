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
    final metrics = SoftOsMetrics.of(context);
    final (icon, accent) = _visuals(surge);

    return Align(
      alignment: const Alignment(0, -0.18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SurgeCard(
            shadow: false,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label: label,
                      child: Container(
                        width: metrics.value(44),
                        height: metrics.value(44),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(
                            surge.radii.menuRow,
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.14),
                            width: surge.spacing.hairline,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: kind == ProxiesEmptyStateKind.loading
                            ? SizedBox.square(
                                dimension: metrics.value(20),
                                child: CircularProgressIndicator(
                                  color: accent,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Icon(
                                icon,
                                color: accent,
                                size: metrics.value(22),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.cardTitle.copyWith(
                              color: surge.textPrimary,
                            ),
                          ),
                          if (description != null &&
                              description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.supporting.copyWith(
                                color: surge.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (kind != ProxiesEmptyStateKind.loading &&
                    actionLabel != null &&
                    onAction != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SurgeStatusButton(
                      isActive: false,
                      label: actionLabel,
                      activeLabel: actionLabel!,
                      inactiveLabel: actionLabel!,
                      inactiveIcon:
                          kind == ProxiesEmptyStateKind.coreUnavailable
                          ? SurgeIcons.cloudSync
                          : SurgeIcons.refresh,
                      inactiveColor: accent,
                      compact: true,
                      height: 32,
                      loading: actionLoading,
                      onPressed: onAction,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
