import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'surge_dashboard_card.dart';

class OutboundMode extends StatelessWidget {
  const OutboundMode({super.key});

  void _handleChangeMode(Mode mode) {
    globalState.container.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;

    return SizedBox(
      height: getWidgetHeight(2),
      child: Consumer(
        builder: (_, ref, _) {
          final mode = ref.watch(
            patchClashConfigProvider.select((state) => state.mode),
          );
          return SurgeDashboardCard(
            title: appLocalizations.outboundMode,
            subtitle: 'Outbound Mode',
            icon: Icons.call_split_rounded,
            height: getWidgetHeight(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SurgeSegmentedControl<Mode>(
                  value: mode,
                  items: _modeItems,
                  onChanged: _handleChangeMode,
                  height: 38,
                ),
                const SizedBox(height: 12),
                Expanded(child: _ModeDescription(mode: mode)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OutboundModeV2 extends StatelessWidget {
  const OutboundModeV2({super.key});

  void _handleChangeMode(Mode mode) {
    globalState.container.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;

    return SizedBox(
      height: getWidgetHeight(1),
      child: Consumer(
        builder: (_, ref, _) {
          final mode = ref.watch(
            patchClashConfigProvider.select((state) => state.mode),
          );
          return SurgeDashboardCard(
            title: appLocalizations.outboundMode,
            icon: Icons.call_split_rounded,
            height: getWidgetHeight(1),
            child: Align(
              alignment: Alignment.topCenter,
              child: SurgeSegmentedControl<Mode>(
                value: mode,
                items: _modeItems,
                onChanged: _handleChangeMode,
                height: 34,
              ),
            ),
          );
        },
      ),
    );
  }
}

const _modeItems = [
  SurgeSegmentedItem(value: Mode.rule, label: 'Rule'),
  SurgeSegmentedItem(value: Mode.global, label: 'Global'),
  SurgeSegmentedItem(value: Mode.direct, label: 'Direct'),
];

class _ModeDescription extends StatelessWidget {
  const _ModeDescription({required this.mode});

  final Mode mode;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final text = switch (mode) {
      Mode.rule => 'Rule Mode',
      Mode.global => 'Global Mode',
      Mode.direct => 'Direct Mode',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surge.background,
        borderRadius: BorderRadius.circular(surge.radii.smallCard),
        border: Border.all(color: surge.separator, width: 0.5),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: surge.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
