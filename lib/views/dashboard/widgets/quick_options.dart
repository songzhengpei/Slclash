import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TUNButton extends StatelessWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: _QuickOptionCard(
        title: appLocalizations.tun,
        icon: Icons.account_tree_rounded,
        onTap: () {
          showSheet(
            context: context,
            builder: (_) {
              return Builder(
                builder: (context) {
                  return AdaptiveSheetScaffold(
                    body: generateListView(
                      generateSection(
                        items: [
                          if (system.isDesktop) const TUNItem(),
                          if (system.isMacOS) const AutoSetSystemDnsItem(),
                          const TunStackItem(),
                        ],
                      ),
                    ),
                    title: appLocalizations.tun,
                  );
                },
              );
            },
          );
        },
        child: Consumer(
          builder: (_, ref, _) {
            final enable = ref.watch(
              patchClashConfigProvider.select((state) => state.tun.enable),
            );
            return SurgeSwitch(
              value: enable,
              onChanged: (value) {
                ref
                    .read(patchClashConfigProvider.notifier)
                    .update((state) => state.copyWith.tun(enable: value));
              },
            );
          },
        ),
      ),
    );
  }
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: _QuickOptionCard(
        title: appLocalizations.systemProxy,
        icon: Icons.lan_rounded,
        onTap: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(
                  generateSection(
                    items: [const SystemProxyItem(), const BypassDomainItem()],
                  ),
                ),
                title: appLocalizations.systemProxy,
              );
            },
          );
        },
        child: Consumer(
          builder: (_, ref, _) {
            final systemProxy = ref.watch(
              networkSettingProvider.select((state) => state.systemProxy),
            );
            return SurgeSwitch(
              value: systemProxy,
              onChanged: (value) {
                ref
                    .read(networkSettingProvider.notifier)
                    .update((state) => state.copyWith(systemProxy: value));
              },
            );
          },
        ),
      ),
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: _QuickOptionCard(
        title: 'VPN',
        icon: Icons.vpn_lock_rounded,
        onTap: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(
                  generateSection(
                    items: [
                      const VPNItem(),
                      const VpnSystemProxyItem(),
                      const TunStackItem(),
                    ],
                  ),
                ),
                title: 'VPN',
              );
            },
          );
        },
        child: Consumer(
          builder: (_, ref, _) {
            final enable = ref.watch(
              vpnSettingProvider.select((state) => state.enable),
            );
            return SurgeSwitch(
              value: enable,
              onChanged: (value) {
                ref
                    .read(vpnSettingProvider.notifier)
                    .update((state) => state.copyWith(enable: value));
              },
            );
          },
        ),
      ),
    );
  }
}

class _QuickOptionCard extends StatelessWidget {
  const _QuickOptionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeActionCard(
      onTap: onTap,
      variant: SurgeActionCardVariant.filled,
      borderRadius: surge.radii.card,
      padding: EdgeInsets.all(surge.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: surge.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.appLocalizations.options,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: surge.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 12),
              child,
            ],
          ),
        ],
      ),
    );
  }
}
