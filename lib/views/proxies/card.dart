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
        final surface = isExpanded
            ? (isSelected ? surge.selectedFill : surge.card)
            : (isSelected ? surge.selectedFill : surge.card);
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
        final borderColor = isSelected
            ? surge.primary.withValues(alpha: 0.16)
            : surge.separator.withValues(alpha: 0.78);
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
                        _DelayBadge(
                          proxyName: proxy.name,
                          testUrl: testUrl,
                          onTap: _handleTestCurrentDelay,
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
                        color: surge.separator.withValues(alpha: 0.40),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      left: 14,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 24,
                          decoration: BoxDecoration(
                            color: surge.primary.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(1),
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

    // Determine colors and label based on delay state
    final bool isTesting = delay == 0;
    final bool isUntested = delay == null;
    final bool isTimeout = delay != null && delay < 0;
    final bool isSuccess = delay != null && delay > 0;

    final Color bg;
    final Color border;
    final Color fg;

    if (isUntested) {
      bg = surge.textSecondary.withValues(alpha: 0.06);
      border = surge.separator.withValues(alpha: 0.45);
      fg = surge.textPrimary.withValues(alpha: 0.75);
    } else if (isTesting) {
      bg = surge.textSecondary.withValues(alpha: 0.06);
      border = surge.separator.withValues(alpha: 0.45);
      fg = surge.textSecondary;
    } else if (isSuccess) {
      final delayColor = utils.getDelayColor(delay) ?? surge.green;
      bg = delayColor.withValues(alpha: 0.10);
      border = delayColor.withValues(alpha: 0.16);
      fg = delayColor;
    } else if (isTimeout) {
      bg = surge.red.withValues(alpha: 0.10);
      border = surge.red.withValues(alpha: 0.16);
      fg = surge.red;
    } else {
      bg = surge.fill;
      border = surge.separator;
      fg = surge.textSecondary;
    }

    final label = isUntested
        ? 'Test'
        : isTesting
        ? ''
        : isSuccess
        ? '$delay ms'
        : 'Timeout';

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: border, width: 0.5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              );
            },
            child: Center(
              key: ValueKey(label),
              child: isTesting
                  ? SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      strutStyle: const StrutStyle(
                        forceStrutHeight: true,
                        height: 1,
                      ),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0,
                      ),
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
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 12,
        color: surge.textPrimary,
      ),
    );
  }
}
