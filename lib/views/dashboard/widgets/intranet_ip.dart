import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'surge_dashboard_card.dart';

class IntranetIP extends StatelessWidget {
  const IntranetIP({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);

    return SizedBox(
      height: getWidgetHeight(1),
      child: SurgeDashboardCard(
        title: appLocalizations.intranetIP,
        subtitle: 'Local IP',
        icon: SurgeIcons.connection,
        height: getWidgetHeight(1),
        child: Consumer(
          builder: (_, ref, _) {
            final localIp = ref.watch(localIpProvider);
            return FadeThroughBox(
              child: localIp != null
                  ? Text(
                      localIp.isNotEmpty ? localIp : appLocalizations.noNetwork,
                      key: ValueKey(localIp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.rowTitle.copyWith(
                        color: surge.textPrimary,
                      ),
                    )
                  : Align(
                      key: const ValueKey('local-ip-loading'),
                      alignment: Alignment.centerLeft,
                      child: SizedBox.square(
                        dimension: 18,
                        child: CommonCircleLoading(color: surge.primary),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
