import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/surge/soft_os_metrics.dart';
import 'package:fl_clash/widgets/surge/surge_motion.dart';
import 'package:fl_clash/widgets/surge/surge_pressable.dart';
import 'package:fl_clash/widgets/surge/surge_theme_extension.dart';
import 'package:flutter/material.dart';

enum SurgeMetricState { idle, loading, value, error }

/// Shared compact metric shell used by delay and future status metrics.
class SurgeMetricBadge extends StatelessWidget {
  const SurgeMetricBadge({
    super.key,
    required this.state,
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
    this.onTap,
    this.width = 64,
  });

  final SurgeMetricState state;
  final String label;
  final Color background;
  final Color border;
  final Color foreground;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final height = metrics.value(surge.controls.statusPillHeight);
    return SurgePressable(
      compact: true,
      borderRadius: BorderRadius.circular(height / 2),
      onTap: onTap,
      child: SizedBox(
        width: metrics.value(width),
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: border, width: surge.spacing.hairline),
          ),
          child: AnimatedSwitcher(
            duration: SurgeMotion.state,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: [...previousChildren, ?currentChild],
            ),
            child: Center(
              key: ValueKey(label),
              child: state == SurgeMetricState.loading
                  ? SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: foreground,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      strutStyle: const StrutStyle(
                        forceStrutHeight: true,
                        height: 1,
                      ),
                      style: surge.typography.micro.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared Soft OS delay-test control for a single proxy.
class SurgeDelayPill extends StatelessWidget {
  const SurgeDelayPill({super.key, required this.delay, required this.onTap});

  final int? delay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isTesting = delay == 0;
    final isUntested = delay == null;
    final isTimeout = delay != null && delay! < 0;
    final isSuccess = delay != null && delay! > 0;
    final Color background;
    final Color border;
    final Color foreground;

    if (isUntested) {
      background = surge.textSecondary.withValues(alpha: 0.052);
      border = surge.separator.withValues(alpha: 0.42);
      foreground = surge.textPrimary.withValues(alpha: 0.72);
    } else if (isTesting) {
      background = surge.textSecondary.withValues(alpha: 0.052);
      border = surge.separator.withValues(alpha: 0.42);
      foreground = surge.textSecondary.withValues(alpha: 0.85);
    } else if (isSuccess) {
      final delayColor = utils.getDelayColor(delay) ?? surge.green;
      background = delayColor.withValues(alpha: 0.085);
      border = delayColor.withValues(alpha: 0.14);
      foreground = delayColor.withValues(alpha: 0.92);
    } else if (isTimeout) {
      background = surge.red.withValues(alpha: 0.085);
      border = surge.red.withValues(alpha: 0.14);
      foreground = surge.red.withValues(alpha: 0.92);
    } else {
      background = surge.fill;
      border = surge.separator;
      foreground = surge.textSecondary;
    }

    final label = isUntested
        ? 'Test'
        : isTesting
        ? ''
        : isSuccess
        ? '$delay ms'
        : 'Timeout';

    return SurgeMetricBadge(
      state: isTesting
          ? SurgeMetricState.loading
          : isTimeout
          ? SurgeMetricState.error
          : isSuccess
          ? SurgeMetricState.value
          : SurgeMetricState.idle,
      label: label,
      background: background,
      border: border,
      foreground: foreground,
      onTap: onTap,
    );
  }
}
