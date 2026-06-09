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

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
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
        return SurgeCard(
          key: key,
          onTap: () {
            _changeProxy(ref);
          },
          padding: EdgeInsets.zero,
          shadow: false,
          borderRadius: surge.radii.list,
          backgroundColor: isSelected
              ? surge.primary.withValues(alpha: 0.055)
              : surge.card,
          border: Border.all(
            color: isSelected
                ? surge.primary.withValues(alpha: 0.16)
                : surge.separator,
            width: 0.5,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: _ProxyTextBlock(proxy: proxy, type: type),
                ),
                if (groupType.isComputedSelected) ...[
                  const SizedBox(width: 8),
                  _ProxyComputedMark(groupName: groupName, proxy: proxy),
                ],
                const SizedBox(width: 8),
                _DelayBadge(
                  proxyName: proxy.name,
                  testUrl: testUrl,
                  onTap: _handleTestCurrentDelay,
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 18,
                  child: AnimatedOpacity(
                    opacity: isSelected ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.check_rounded,
                      color: surge.primary,
                      size: 18,
                    ),
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

class _DelayBadge extends ConsumerWidget {
  const _DelayBadge({
    required this.proxyName,
    required this.testUrl,
    required this.onTap,
  });

  final String proxyName;
  final String? testUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final delay = ref.watch(
      delayProvider(proxyName: proxyName, testUrl: testUrl),
    );
    final color = delay == null
        ? surge.textSecondary
        : delay == 0
        ? surge.primary
        : delay < 0
        ? surge.red
        : utils.getDelayColor(delay) ?? surge.textSecondary;
    final label = delay == null
        ? 'Test'
        : delay == 0
        ? ''
        : delay > 0
        ? '$delay ms'
        : 'Timeout';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 50,
          maxWidth: 76,
          minHeight: 24,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: delay == null
              ? surge.separator.withValues(alpha: 0.55)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(surge.radii.button),
        ),
        child: Center(
          child: FadeThroughBox(
            child: delay == 0
                ? SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
      ),
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
        color: surge.primary.withValues(alpha: 0.14),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: 12, color: surge.primary),
    );
  }
}
