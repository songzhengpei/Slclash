import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

import 'widgets/network_overview_card.dart';
import 'widgets/surge_dashboard_hero.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  static const _pageBackground = Color(0xFFF4F6FA);

  @override
  Widget build(BuildContext context) {
    final bottomPadding = 80 + MediaQuery.paddingOf(context).bottom;

    return CommonScaffold(
      title: context.appLocalizations.dashboard,
      backgroundColor: _pageBackground,
      body: ColoredBox(
        color: _pageBackground,
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
