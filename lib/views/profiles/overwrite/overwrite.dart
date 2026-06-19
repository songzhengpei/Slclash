import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/preview.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom/custom.dart';
import 'script.dart';
import 'standard.dart';

class OverwriteView extends ConsumerStatefulWidget {
  final int profileId;

  const OverwriteView({super.key, required this.profileId});

  @override
  ConsumerState<OverwriteView> createState() => _OverwriteViewState();
}

class _OverwriteViewState extends ConsumerState<OverwriteView> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _handlePreview() async {
    final profile = ref.read(profileProvider(widget.profileId));
    if (profile == null) {
      return;
    }
    BaseNavigator.push<String>(context, PreviewProfileView(profile: profile));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ProfileIdProvider(
      profileId: widget.profileId,
      child: CommonScaffold(
        title: appLocalizations.override,
        actions: [
          CommonMinFilledButtonTheme(
            child: FilledButton(
              onPressed: _handlePreview,
              child: Text(appLocalizations.preview),
            ),
          ),
          const SizedBox(width: 8),
        ],
        body: const CustomScrollView(slivers: [_Title(), _Content()]),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    globalState.container.read(setupActionProvider.notifier).autoApplyProfile();
  }
}

class _Title extends ConsumerWidget {
  const _Title();

  String _getTitle(BuildContext context, OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => context.appLocalizations.standard,
      OverwriteType.script => context.appLocalizations.script,
      OverwriteType.custom => context.appLocalizations.overwriteTypeCustom,
    };
  }

  IconData _getIcon(OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => Icons.stars,
      OverwriteType.script => Icons.rocket,
      OverwriteType.custom => Icons.dashboard_customize,
    };
  }

  String _getDesc(BuildContext context, OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => context.appLocalizations.standardModeDesc,
      OverwriteType.script => context.appLocalizations.scriptModeDesc,
      OverwriteType.custom => context.appLocalizations.overwriteTypeCustomDesc,
    };
  }

  void _handleChangeType(WidgetRef ref, int profileId, OverwriteType type) {
    ref.read(profilesProvider.notifier).updateProfile(profileId, (state) {
      return state.copyWith(overwriteType: type);
    });
  }

  @override
  Widget build(context, ref) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final overwriteType = ref.watch(overwriteTypeProvider(profileId));
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoHeader(info: Info(label: appLocalizations.overrideMode)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              children: [
                for (final type in OverwriteType.values)
                  _OverwriteModeCard(
                    title: _getTitle(context, type),
                    icon: _getIcon(type),
                    selected: overwriteType == type,
                    onPressed: () {
                      _handleChangeType(ref, profileId, type);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SurgeActionCard(
              variant: SurgeActionCardVariant.tonal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderRadius: surge.radii.list,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: surge.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getDesc(context, overwriteType),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: surge.textSecondary,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverwriteModeCard extends StatelessWidget {
  const _OverwriteModeCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      width: 118,
      child: SurgeActionCard(
        selected: selected,
        variant: SurgeActionCardVariant.filled,
        onTap: onPressed,
        padding: const EdgeInsets.all(12),
        borderRadius: surge.radii.list,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? surge.primary
                        : surge.fill.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? surge.onPrimary : surge.textSecondary,
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(Icons.check_circle, size: 18, color: surge.green),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelLarge?.copyWith(
                color: selected ? surge.primary : surge.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  @override
  Widget build(BuildContext context, ref) {
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final overwriteType = ref.watch(overwriteTypeProvider(profileId));
    ref.listen(clashConfigProvider(profileId), (_, _) {});
    return switch (overwriteType) {
      OverwriteType.standard => const StandardContent(),
      OverwriteType.script => const ScriptContent(),
      OverwriteType.custom => const CustomContent(),
    };
  }
}
