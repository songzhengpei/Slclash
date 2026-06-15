import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesSetting extends ConsumerWidget {
  const ProxiesSetting({super.key});

  String _sortLabel(BuildContext context, ProxiesSortType type) {
    final appLocalizations = context.appLocalizations;
    return switch (type) {
      ProxiesSortType.none => appLocalizations.defaultText,
      ProxiesSortType.delay => appLocalizations.delay,
      ProxiesSortType.name => appLocalizations.name,
    };
  }

  IconData _sortIcon(ProxiesSortType type) {
    return switch (type) {
      ProxiesSortType.none => Icons.sort_rounded,
      ProxiesSortType.delay => Icons.network_ping_rounded,
      ProxiesSortType.name => Icons.sort_by_alpha_rounded,
    };
  }

  String _iconStyleLabel(BuildContext context, ProxiesIconStyle style) {
    final appLocalizations = context.appLocalizations;
    return switch (style) {
      ProxiesIconStyle.standard => appLocalizations.standard,
      ProxiesIconStyle.none => appLocalizations.none,
      ProxiesIconStyle.icon => appLocalizations.onlyIcon,
    };
  }

  IconData _iconStyleIcon(ProxiesIconStyle style) {
    return switch (style) {
      ProxiesIconStyle.standard => Icons.view_agenda_rounded,
      ProxiesIconStyle.none => Icons.format_align_left_rounded,
      ProxiesIconStyle.icon => Icons.apps_rounded,
    };
  }

  void _setListStyle(WidgetRef ref) {
    ref.read(proxiesStyleSettingProvider.notifier).update((state) {
      return state.copyWith(type: ProxiesType.list);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final state = ref.watch(proxiesStyleSettingProvider);

    if (state.type != ProxiesType.list) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setListStyle(ref));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingSection(
            title: appLocalizations.style,
            subtitle: appLocalizations.proxies,
            children: [
              _SettingOption(
                icon: Icons.view_list_rounded,
                label: appLocalizations.list,
                selected: true,
                onTap: () => _setListStyle(ref),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingSection(
            title: appLocalizations.sort,
            subtitle: appLocalizations.delay,
            children: [
              for (final item in ProxiesSortType.values)
                _SettingOption(
                  icon: _sortIcon(item),
                  label: _sortLabel(context, item),
                  selected: state.sortType == item,
                  onTap: () {
                    ref.read(proxiesStyleSettingProvider.notifier).update((
                      state,
                    ) {
                      return state.copyWith(sortType: item);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingSection(
            title: appLocalizations.iconStyle,
            subtitle: appLocalizations.icon,
            children: [
              for (final item in ProxiesIconStyle.values)
                _SettingOption(
                  icon: _iconStyleIcon(item),
                  label: _iconStyleLabel(context, item),
                  selected: state.iconStyle == item,
                  onTap: () {
                    ref.read(proxiesStyleSettingProvider.notifier).update((
                      state,
                    ) {
                      return state.copyWith(iconStyle: item);
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  const _SettingSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        SurgeCard(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          shadow: true,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingOption extends StatelessWidget {
  const _SettingOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final foreground = selected ? surge.textPrimary : surge.textSecondary;
    final selectedFill = surge.selectedFill;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? selectedFill : surge.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected ? surge.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? surge.primary : surge.separator,
                    width: 1.2,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: surge.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
