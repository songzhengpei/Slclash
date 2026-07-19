import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

import 'card.dart';

class SettingInfoCard extends StatelessWidget {
  final Info info;
  final bool? isSelected;
  final VoidCallback onPressed;

  const SettingInfoCard(
    this.info, {
    super.key,
    this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeActionCard(
      selected: isSelected == true,
      variant: SurgeActionCardVariant.filled,
      onTap: onPressed,
      padding: const EdgeInsets.all(12),
      child: IconTheme.merge(
        data: IconThemeData(color: surge.primary, size: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(child: Icon(info.iconData)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                info.label,
                style: context.typography.rowTitle.copyWith(
                  color: surge.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingTextCard extends StatelessWidget {
  final String text;
  final bool? isSelected;
  final VoidCallback onPressed;

  const SettingTextCard(
    this.text, {
    super.key,
    this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeActionCard(
      onTap: onPressed,
      selected: isSelected == true,
      variant: SurgeActionCardVariant.filled,
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: context.typography.body.copyWith(color: surge.textPrimary),
      ),
    );
  }
}

class SurgeSettingSection extends StatelessWidget {
  const SurgeSettingSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.margin,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding:
          margin ??
          EdgeInsets.fromLTRB(
            surge.spacing.pagePadding,
            0,
            surge.spacing.pagePadding,
            14,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    style: context.typography.rowTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      style: context.typography.supporting.copyWith(
                        color: surge.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SurgeCard(
            padding: EdgeInsets.zero,
            borderRadius: surge.radii.list,
            shadow: false,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class SurgeSettingOption extends StatelessWidget {
  const SurgeSettingOption({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.showDivider = true,
    this.enabled = true,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool showDivider;
  final bool enabled;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurgeListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      onTap: onTap,
      showDivider: showDivider,
      dense: dense,
      trailing:
          trailing ??
          SurgeSelectIndicator(
            selected: selected,
            size: 20,
            iconSize: 13,
            showCheck: false,
          ),
    );
  }
}
