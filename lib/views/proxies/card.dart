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
    final ref = globalState.container;
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
    final surge = SurgeTheme.of(context);
    return Consumer(
      builder: (_, ref, _) {
        final selectedProxyName = ref.watch(
          selectedProxyNameProvider(groupName),
        );
        final isSelected = selectedProxyName == proxy.name;
        final surface = isSelected
            ? Color.alphaBlend(
                surge.primary.withValues(alpha: 0.045),
                surge.card,
              )
            : surge.card;
        final radius = BorderRadius.vertical(
          top:
              rowPosition == ProxyListRowPosition.first ||
                  rowPosition == ProxyListRowPosition.single
              ? Radius.circular(surge.radii.card)
              : Radius.zero,
          bottom:
              rowPosition == ProxyListRowPosition.last ||
                  rowPosition == ProxyListRowPosition.single
              ? Radius.circular(surge.radii.card)
              : Radius.zero,
        );
        final borderColor = surge.separator.withValues(alpha: 0.74);
        final border = Border(
          left: BorderSide(color: borderColor, width: 0.5),
          right: BorderSide(color: borderColor, width: 0.5),
          top:
              rowPosition == ProxyListRowPosition.first ||
                  rowPosition == ProxyListRowPosition.single
              ? BorderSide(color: borderColor, width: 0.5)
              : BorderSide.none,
          bottom:
              rowPosition == ProxyListRowPosition.last ||
                  rowPosition == ProxyListRowPosition.single
              ? BorderSide(color: borderColor, width: 0.5)
              : BorderSide.none,
        );

        return Material(
          key: key,
          color: Colors.transparent,
          clipBehavior: Clip.none,
          borderRadius: radius,
          child: InkWell(
            onTap: () {
              _changeProxy(ref);
            },
            child: Ink(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: radius,
                border: border,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 7, 12, 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProxyTextBlock(proxy: proxy, type: type),
                        ),
                        if (groupType.isComputedSelected) ...[
                          const SizedBox(width: 8),
                          _ProxyComputedMark(
                            groupName: groupName,
                            proxy: proxy,
                          ),
                        ],
                        const SizedBox(width: 12),
                        Consumer(
                          builder: (context, ref, child) => SurgeDelayPill(
                            delay: ref.watch(
                              delayProvider(
                                proxyName: proxy.name,
                                testUrl: testUrl,
                              ),
                            ),
                            onTap: _handleTestCurrentDelay,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showDivider)
                    Positioned(
                      left: 32,
                      right: 16,
                      bottom: 0,
                      child: Divider(
                        height: 0,
                        thickness: surge.spacing.hairline,
                        color: surge.separator.withValues(alpha: 0.35),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      left: 14,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 3,
                          height: 28,
                          decoration: BoxDecoration(
                            color: surge.primary.withValues(alpha: 0.64),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
          style: context.textTheme.bodyMedium?.copyWith(
            color: surge.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.05,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(
            color: surge.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
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
