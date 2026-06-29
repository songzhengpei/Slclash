import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/dashboard/widgets/network_overview_card.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'widgets/surge_dashboard_hero.dart';

@visibleForTesting
class DashboardOverviewLayout {
  const DashboardOverviewLayout({required this.scale});

  final double scale;
}

class DashboardAdaptiveLayout {
  const DashboardAdaptiveLayout._();

  static const double baseShortestSide = 384;
  static const double minScale = 0.92;
  static const double maxScale = 1.12;
  static const double horizontalPadding = 18;
  static const double topPadding = 16;
  static const double cardGap = 16;

  @visibleForTesting
  static double scaleForShortestSide(double shortestSide) {
    return (shortestSide / baseShortestSide).clamp(minScale, maxScale);
  }

  @visibleForTesting
  static DashboardOverviewLayout overviewLayoutFor(double shortestSide) {
    return DashboardOverviewLayout(scale: scaleForShortestSide(shortestSide));
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final pageBackground = SurgeTheme.of(context).background;
    final bottomPadding = SurgeBottomNavLayout.mainPageBottomPadding(context);
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final overviewLayout = DashboardAdaptiveLayout.overviewLayoutFor(
      shortestSide,
    );

    return CommonScaffold(
      title: context.appLocalizations.dashboard,
      backgroundColor: pageBackground,
      body: ColoredBox(
        color: pageBackground,
        child: ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DashboardAdaptiveLayout.horizontalPadding,
              DashboardAdaptiveLayout.topPadding,
              DashboardAdaptiveLayout.horizontalPadding,
              bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero card - natural height
                const SurgeDashboardHero(),
                const SizedBox(height: DashboardAdaptiveLayout.cardGap),
                // Network overview card - fills remaining space
                Flexible(
                  child: SurgeNetworkOverviewCard(
                    layoutScale: overviewLayout.scale,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
