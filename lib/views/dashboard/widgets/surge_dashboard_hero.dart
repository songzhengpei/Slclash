import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SurgeDashboardHero extends ConsumerWidget {
  const SurgeDashboardHero({super.key});

  String _modeLabel(Mode mode) {
    return switch (mode) {
      Mode.rule => 'Rule',
      Mode.global => 'Global',
      Mode.direct => 'Direct',
    };
  }

  String _localizedModeLabel(BuildContext context, Mode mode) {
    final appLocalizations = context.appLocalizations;
    return switch (mode) {
      Mode.rule => appLocalizations.rule,
      Mode.direct => appLocalizations.direct,
      Mode.global => appLocalizations.global,
    };
  }

  String _coreStatusLabel(BuildContext context, CoreStatus status) {
    return switch (status) {
      CoreStatus.connecting => context.appLocalizations.connecting,
      CoreStatus.connected => '已就绪',
      CoreStatus.disconnected => '未就绪',
    };
  }

  String _stopLabel(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      return '停止';
    }
    return context.appLocalizations.stop;
  }

  void _handleSwitchStart(WidgetRef ref) {
    final nextIsStart = !ref.read(isStartProvider);
    debouncer.call(FunctionTag.updateStatus, () {
      ref
          .read(setupActionProvider.notifier)
          .updateStatus(nextIsStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  void _handleChangeMode(Mode mode, WidgetRef ref) {
    ref.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final appLocalizations = context.appLocalizations;
    final isStart = ref.watch(isStartProvider);
    final runTime = ref.watch(runTimeProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final coreStatus = ref.watch(coreStatusProvider);
    final profileName = ref.watch(
      currentProfileProvider.select((profile) => profile?.realLabel),
    );
    final modeLabel = _modeLabel(mode);
    final statusLabel = isStart
        ? appLocalizations.connected
        : appLocalizations.disconnected;
    final runtimeText = utils.getTimeText(runTime);

    return SizedBox(
      width: double.infinity,
      child: SurgeCard(
        padding: const EdgeInsets.all(14),
        shadow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SlClash',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: surge.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profileName.takeFirstValid([
                          appLocalizations.dashboard,
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: surge.textSecondary,
                          fontSize: 13,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SurgeStatusButton(
                  isActive: isStart,
                  activeLabel: _stopLabel(context),
                  inactiveLabel: appLocalizations.start,
                  loading: coreStatus == CoreStatus.connecting,
                  compact: true,
                  onPressed: () {
                    _handleSwitchStart(ref);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SurgeFeatureCard(
              title: appLocalizations.outboundMode,
              subtitle: '$modeLabel Mode',
              icon: Icons.call_split_rounded,
              color: surge.primary,
              height: 88,
              trailing: _StatusPill(active: isStart, label: statusLabel),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SurgeSegmentedControl<Mode>(
                value: mode,
                items: [
                  SurgeSegmentedItem(
                    value: Mode.rule,
                    label: _localizedModeLabel(context, Mode.rule),
                  ),
                  SurgeSegmentedItem(
                    value: Mode.direct,
                    label: _localizedModeLabel(context, Mode.direct),
                  ),
                  SurgeSegmentedItem(
                    value: Mode.global,
                    label: _localizedModeLabel(context, Mode.global),
                  ),
                ],
                onChanged: (value) {
                  _handleChangeMode(value, ref);
                },
                height: 36,
              ),
            ),
            const SizedBox(height: 10),
            _HeroInfoBar(
              items: [
                _HeroInfoItem(label: '运行', value: runtimeText),
                _HeroInfoItem(
                  label: 'Core',
                  value: _coreStatusLabel(context, coreStatus),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(surge.radii.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? surge.green : Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInfoItem {
  const _HeroInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _HeroInfoBar extends StatelessWidget {
  const _HeroInfoBar({required this.items});

  final List<_HeroInfoItem> items;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: surge.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(surge.radii.smallCard),
        border: Border.all(
          color: surge.separator.withValues(alpha: 0.55),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: surge.separator.withValues(alpha: 0.55),
              ),
            Expanded(child: _HeroInfoText(item: items[index])),
          ],
        ],
      ),
    );
  }
}

class _HeroInfoText extends StatelessWidget {
  const _HeroInfoText({required this.item});

  final _HeroInfoItem item;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Row(
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: surge.textSecondary,
            fontSize: 11,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: surge.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}
