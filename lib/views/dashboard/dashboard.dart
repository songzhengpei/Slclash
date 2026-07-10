import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/views/dashboard/widgets/network_overview_card.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'widgets/surge_dashboard_hero.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final pageBackground = SurgeTheme.of(context).background;
    final bottomPadding = SurgeBottomNavLayout.mainPageBottomPadding(context);

    return CommonScaffold(
      title: context.appLocalizations.dashboard,
      backgroundColor: pageBackground,
      body: ColoredBox(
        color: pageBackground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = DashboardResponsiveLayout.fromViewport(
              viewportWidth: constraints.maxWidth,
              textScaler: MediaQuery.textScalerOf(context),
            );
            final availableContentHeight = (constraints.maxHeight -
                    layout.pageTopPadding -
                    bottomPadding)
                .clamp(0.0, double.infinity)
                .toDouble();
            final networkNaturalHeight =
                NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
                  layout,
                );
            final networkHeight = (availableContentHeight -
                    layout.heroNaturalHeight -
                    layout.cardGap)
                .clamp(networkNaturalHeight, double.infinity)
                .toDouble();

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                layout.pageHorizontalPadding,
                layout.pageTopPadding,
                layout.pageHorizontalPadding,
                bottomPadding,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SurgeDashboardHero(layout: layout),
                      SizedBox(height: layout.cardGap),
                      SizedBox(
                        height: networkHeight,
                        child: SurgeNetworkOverviewCard(layout: layout),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
