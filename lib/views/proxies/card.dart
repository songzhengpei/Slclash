import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyCard extends StatelessWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;
  final bool isExpanded;
  final ProxyListRowPosition rowPosition;
  final bool showDivider;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
    this.isExpanded = false,
    this.rowPosition = ProxyListRowPosition.single,
    this.showDivider = false,
  });

  void _handleTestCurrentDelay() {
    proxyDelayTest(proxy, testUrl);
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(proxyNameProvider(groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == proxy.name ? '' : proxy.name,
        false => proxy.name,
      };
      ref
          .read(profilesActionProvider.notifier)
          .updateCurrentSelectedMap(groupName, nextProxyName);
      ref
          .read(proxiesActionProvider.notifier)
          .changeProxyDebounce(groupName, nextProxyName);
      return;
    }
    globalState.showNotifier(currentAppLocalizations.notSelectedTip);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final selectedProxyName = ref.watch(
          selectedProxyNameProvider(groupName),
        );
        final isSelected = selectedProxyName == proxy.name;
        return SurgeSelectableRow(
          key: key,
          selected: isSelected,
          onTap: () => _changeProxy(ref),
          position: switch (rowPosition) {
            ProxyListRowPosition.single => SurgeSelectableRowPosition.single,
            ProxyListRowPosition.first => SurgeSelectableRowPosition.first,
            ProxyListRowPosition.middle => SurgeSelectableRowPosition.middle,
            ProxyListRowPosition.last => SurgeSelectableRowPosition.last,
          },
          showBorder: true,
          showDivider: showDivider,
          dividerInsets: const EdgeInsets.only(left: 32, right: 16),
          dividerOpacity: 0.35,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 7, 12, 7),
            child: Row(
              children: [
                Expanded(
                  child: _ProxyTextBlock(proxy: proxy, type: type),
                ),
                if (groupType.isComputedSelected) ...[
                  const SizedBox(width: 8),
                  _ProxyComputedMark(groupName: groupName, proxy: proxy),
                ],
                const SizedBox(width: 12),
                Consumer(
                  builder: (context, ref, child) => SurgeDelayPill(
                    delay: ref.watch(
                      delayProvider(proxyName: proxy.name, testUrl: testUrl),
                    ),
                    onTap: _handleTestCurrentDelay,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProxyTextBlock extends ConsumerWidget {
  const _ProxyTextBlock({required this.proxy, required this.type});

  final Proxy proxy;
  final ProxyCardType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final desc = ref.watch(proxyDescProvider(proxy));
    final subtitle = type == ProxyCardType.min ? proxy.type : desc;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmojiText(
          proxy.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.compactRowTitle.copyWith(color: surge.textPrimary),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.detailLabel.copyWith(
            color: surge.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProxyComputedMark extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;

  const _ProxyComputedMark({required this.groupName, required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final proxyName = ref.watch(proxyNameProvider(groupName));
    if (proxyName != proxy.name) {
      return const SizedBox();
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: surge.textSecondary.withValues(alpha: 0.12),
      ),
      child: Icon(SurgeIcons.autoAwesome, size: 12, color: surge.textPrimary),
    );
  }
}
