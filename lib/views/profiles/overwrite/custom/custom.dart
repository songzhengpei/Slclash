import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'groups.dart';
import 'rules.dart';
import 'widgets.dart';

class CustomContent extends ConsumerWidget {
  const CustomContent({super.key});

  void _handleUseDefault(WidgetRef ref, int profileId) async {
    final res = await globalState.showMessage(
      message: TextSpan(text: currentAppLocalizations.confirmOverwriteTip),
    );
    if (res != true) {
      return;
    }
    final clashConfig = await ref.read(clashConfigProvider(profileId).future);
    await database.setProfileCustomData(
      profileId,
      clashConfig.proxyGroups,
      clashConfig.rules,
    );
  }

  void _handleToProxyGroupsView(BuildContext context, int profileId) {
    BaseNavigator.push(context, CustomProxyGroupsView(profileId));
  }

  void _handleToRulesView(BuildContext context, int profileId) {
    BaseNavigator.push(context, CustomRulesView(profileId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    ref.listen(proxyGroupsProvider(profileId), (_, _) {});
    ref.listen(profileCustomRulesProvider(profileId), (_, _) {});
    ref.listen(customOverwriteDateProvider(profileId), (_, _) {});
    final proxyGroupNum =
        ref.watch(proxyGroupsCountProvider(profileId)).value ?? -1;
    final ruleNum = ref.watch(customRulesCountProvider(profileId)).value ?? -1;
    final vm2 = ref.watch(
      clashConfigProvider(profileId).select((state) {
        final clashConfig = state.value;
        return VM2(
          clashConfig?.proxyGroups.isNotEmpty ?? false,
          clashConfig?.rules.isEmpty ?? false,
        );
      }),
    );
    final hasDefaultGroups = vm2.a;
    final hasDefaultRules = vm2.b;
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: OverwriteSectionHeader(label: appLocalizations.custom),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SurgeCard(
              shadow: false,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _CustomNavigationRow(
                    label: appLocalizations.proxyGroup,
                    icon: SurgeIcons.proxyGroup,
                    count: proxyGroupNum,
                    onTap: () {
                      _handleToProxyGroupsView(context, profileId);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 52,
                    color: SurgeTheme.of(context).separator,
                  ),
                  _CustomNavigationRow(
                    label: appLocalizations.rule,
                    icon: SurgeIcons.rule,
                    count: ruleNum,
                    onTap: () {
                      _handleToRulesView(context, profileId);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        if ((proxyGroupNum == 0 && hasDefaultGroups) ||
            (ruleNum == 0 && hasDefaultRules) ||
            kDebugMode)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SurgeActionCard(
                  variant: SurgeActionCardVariant.tonal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(appLocalizations.configDataDetected),
                      ),
                      const SizedBox(width: 12),
                      SoftOsActionTextButton(
                        onPressed: () {
                          _handleUseDefault(ref, profileId);
                        },
                        label: appLocalizations.quickFill,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomNavigationRow extends StatelessWidget {
  const _CustomNavigationRow({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgePressable(
      onTap: onTap,
      scaleFeedback: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: surge.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: context.typography.rowTitle.copyWith(
                  color: surge.textPrimary,
                ),
              ),
            ),
            SoftOsStatusPill(
              width: 44,
              child: Text(
                '$count',
                style: context.typography.badgeLabel.copyWith(
                  color: surge.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(SurgeIcons.forward, size: 18, color: surge.textSecondary),
          ],
        ),
      ),
    );
  }
}
