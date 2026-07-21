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
    final mediaQuery = MediaQuery.of(context);
    final pageBackground = SurgeTheme.of(context).background;
    final bottomPadding = SurgeBottomNavLayout.mainPageBottomPadding(context);

    return MediaQuery(
      data: mediaQuery,
      child: CommonScaffold(
        title: context.appLocalizations.dashboard,
        backgroundColor: pageBackground,
        appBarActions: const [],
        body: ColoredBox(
          color: pageBackground,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportSize = MediaQuery.sizeOf(context);
              final layout = DashboardResponsiveLayout.fromViewport(
                viewportWidth: constraints.maxWidth,
                viewportHeight: viewportSize.height,
                textScaler: MediaQuery.textScalerOf(context),
              );
              final availableContentHeight =
                  (constraints.maxHeight -
                          layout.pageTopPadding -
                          bottomPadding)
                      .clamp(0.0, double.infinity)
                      .toDouble();
              final networkNaturalHeight =
                  NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
                    layout,
                  );
              final pageHeights = layout.resolvePageHeightAllocation(
                availableContentHeight: availableContentHeight,
                networkNaturalHeight: networkNaturalHeight,
              );

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  layout.pageHorizontalPadding,
                  layout.pageTopPadding,
                  layout.pageHorizontalPadding,
                  bottomPadding + DashboardResponsiveLayout.scrollEndBottomGap,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layout.contentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SurgeDashboardHero(
                          layout: layout,
                          allocatedHeight: pageHeights.hasHeroExpansion
                              ? pageHeights.heroHeight
                              : null,
                        ),
                        SizedBox(height: layout.cardGap),
                        SurgeNetworkOverviewCard(
                          layout: layout,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
