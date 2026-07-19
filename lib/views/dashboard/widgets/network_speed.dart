import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'surge_dashboard_card.dart';

class NetworkSpeed extends StatefulWidget {
  const NetworkSpeed({super.key});

  @override
  State<NetworkSpeed> createState() => _NetworkSpeedState();
}

class _NetworkSpeedState extends State<NetworkSpeed> {
  List<Point> initPoints = const [Point(0, 0), Point(1, 0)];

  List<Point> _getPoints(List<Traffic> traffics) {
    final points = List<Point>.of(initPoints, growable: true);
    for (var i = 0; i < traffics.length; i++) {
      final traffic = traffics[i];
      points.add(
        Point((i + initPoints.length).toDouble(), traffic.speed.toDouble()),
      );
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final height = getWidgetHeight(1.65);
    return SizedBox(
      height: height,
      child: RepaintBoundary(
        child: Consumer(
          builder: (_, ref, _) {
            final traffics = ref.watch(trafficsProvider).list;
            return SurgeDashboardCard(
              title: appLocalizations.networkSpeed,
              subtitle: 'Speed',
              icon: SurgeIcons.speed,
              height: height,
              trailing: ValueListenableBuilder<Traffic>(
                valueListenable: currentSpeedNotifier,
                builder: (_, speed, _) {
                  return Text(
                    speed.speedText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.chartLabel.copyWith(
                      color: surge.textSecondary,
                    ),
                  );
                },
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 5),
                child: LineChart(
                  gradient: true,
                  color: surge.primary.withValues(alpha: 0.88),
                  points: _getPoints(traffics),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
