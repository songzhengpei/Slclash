import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'surge_dashboard_card.dart';

class TrafficUsage extends StatelessWidget {
  const TrafficUsage({super.key});

  Widget _buildTrafficDataItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required num trafficValue,
    required Color color,
  }) {
    final surge = SurgeTheme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.chartLabel.copyWith(
            color: surge.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  trafficValue.traffic.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.metric.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                trafficValue.traffic.unit,
                maxLines: 1,
                style: context.typography.chartLabel.copyWith(
                  color: surge.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final primaryColor = surge.primary;
    final secondaryColor = surge.green;
    final height = getWidgetHeight(1.65);

    return SizedBox(
      height: height,
      child: RepaintBoundary(
        child: Consumer(
          builder: (_, ref, _) {
            final totalTraffic = ref.watch(totalTrafficProvider);
            final upTotalTrafficValue = totalTraffic.up;
            final downTotalTrafficValue = totalTraffic.down;

            return SurgeDashboardCard(
              title: appLocalizations.trafficUsage,
              subtitle: 'Traffic',
              icon: SurgeIcons.traffic,
              height: height,
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final chartSize = constraints.maxWidth < 300 ? 52.0 : 62.0;
                  final chart = SizedBox.square(
                    dimension: chartSize,
                    child: DonutChart(
                      data: [
                        DonutChartData(
                          value: upTotalTrafficValue.toDouble(),
                          color: primaryColor,
                        ),
                        DonutChartData(
                          value: downTotalTrafficValue.toDouble(),
                          color: secondaryColor,
                        ),
                      ],
                    ),
                  );
                  final data = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTrafficDataItem(
                        context: context,
                        icon: SurgeIcons.arrowUp,
                        label: appLocalizations.upload,
                        trafficValue: upTotalTrafficValue,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 8),
                      _buildTrafficDataItem(
                        context: context,
                        icon: SurgeIcons.arrowDown,
                        label: appLocalizations.download,
                        trafficValue: downTotalTrafficValue,
                        color: secondaryColor,
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 240) {
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: 8),
                        Expanded(child: data),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      chart,
                      const SizedBox(width: 12),
                      Expanded(child: data),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
