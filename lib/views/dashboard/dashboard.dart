import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'widgets/network_overview_card.dart';
import 'widgets/surge_dashboard_hero.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final pageBackground = SurgeTheme.of(context).background;
    final bottomPadding = 80 + MediaQuery.paddingOf(context).bottom;

    return CommonScaffold(
      title: context.appLocalizations.dashboard,
      backgroundColor: pageBackground,
      body: ColoredBox(
        color: pageBackground,
        child: ExcludeSemantics(
          child: ListView(
            padding: EdgeInsets.fromLTRB(18, 16, 18, bottomPadding),
            children: const [
              SurgeDashboardHero(),
              SizedBox(height: 16),
              SurgeNetworkOverviewCard(),
            ],
          ),
        ),
      ),
    );
  }
}
