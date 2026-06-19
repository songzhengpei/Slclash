// ignore_for_file: deprecated_member_use

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/config/scripts.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScriptContent extends ConsumerWidget {
  const ScriptContent({super.key});

  void _handleChange(WidgetRef ref, int profileId, int scriptId) {
    ref.read(profilesProvider.notifier).updateProfile(profileId, (state) {
      return state.copyWith(
        scriptId: state.scriptId == scriptId ? null : scriptId,
      );
    });
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final scriptId = ref.watch(
      profileProvider(profileId).select((state) => state?.scriptId),
    );
    final scripts = ref.watch(scriptsProvider).value ?? [];
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: Column(
            children: [
              InfoHeader(info: Info(label: appLocalizations.overrideScript)),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        Consumer(
          builder: (_, ref, _) {
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: scripts.length,
                itemBuilder: (_, index) {
                  final script = scripts[index];
                  final selected = script.id == scriptId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _ScriptOptionRow(
                      label: script.label,
                      selected: selected,
                      onPressed: () {
                        _handleChange(ref, profileId, script.id);
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, scripts.isEmpty ? 4 : 8, 16, 4),
            child: Column(
              children: [
                if (scripts.isEmpty) ...[
                  SurgeActionCard(
                    variant: SurgeActionCardVariant.filled,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    borderRadius: surge.radii.list,
                    child: Row(
                      children: [
                        Icon(
                          Icons.code_off,
                          color: surge.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            appLocalizations.nullTip(appLocalizations.script),
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: surge.textSecondary,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _ConfigureScriptButton(
                  label: appLocalizations.goToConfigureScript,
                  onPressed: () {
                    BaseNavigator.push(context, const ScriptsView());
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScriptOptionRow extends StatelessWidget {
  const _ScriptOptionRow({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeActionCard(
      selected: selected,
      variant: SurgeActionCardVariant.filled,
      onTap: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      borderRadius: surge.radii.list,
      child: Row(
        children: [
          SurgeSelectIndicator(selected: selected),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: selected ? surge.primary : surge.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigureScriptButton extends StatelessWidget {
  const _ConfigureScriptButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeActionCard(
      onTap: onPressed,
      variant: SurgeActionCardVariant.tonal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: surge.radii.list,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: surge.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.tune, size: 18, color: surge.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: surge.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward_ios, size: 16, color: surge.textSecondary),
        ],
      ),
    );
  }
}
