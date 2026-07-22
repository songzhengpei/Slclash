import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:flutter/material.dart';

import 'soft_os_metrics.dart';
import 'surge_motion.dart';
import 'surge_pressable.dart';
import 'surge_select_indicator.dart';
import 'surge_theme_extension.dart';

@immutable
class SoftOsSelectItem<T> {
  const SoftOsSelectItem({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
}

class SoftOsSelectPill<T> extends StatelessWidget {
  const SoftOsSelectPill({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.semanticLabel,
    this.width,
    this.maxPopupHeight = 320,
  });

  final T value;
  final List<SoftOsSelectItem<T>> items;
  final ValueChanged<T>? onChanged;
  final String semanticLabel;
  final double? width;
  final double maxPopupHeight;

  @override
  Widget build(BuildContext context) {
    final selected = items.firstWhere((item) => item.value == value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        return CommonPopupBox(
          belowTarget: true,
          popup: _SoftOsSelectPopup<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            maxHeight: maxPopupHeight,
            width: resolvedWidth,
          ),
          targetBuilder: (open) => Semantics(
            button: true,
            enabled: onChanged != null,
            label: semanticLabel,
            value: selected.label,
            child: _SoftOsSelectTarget(
              item: selected,
              enabled: onChanged != null,
              width: resolvedWidth,
              onTap: onChanged == null
                  ? null
                  : () => open(offset: const Offset(0, 3)),
            ),
          ),
        );
      },
    );
  }
}

class _SoftOsSelectTarget<T> extends StatelessWidget {
  const _SoftOsSelectTarget({
    required this.item,
    required this.enabled,
    required this.width,
    required this.onTap,
  });

  final SoftOsSelectItem<T> item;
  final bool enabled;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    final height = metrics.value(surge.controls.selectPillHeight);
    return SurgePressable(
      onTap: onTap,
      enabled: enabled,
      scaleFeedback: false,
      borderRadius: BorderRadius.circular(height / 2),
      child: AnimatedContainer(
        duration: SurgeMotion.state,
        curve: SurgeMotion.stateCurve,
        width: width,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: metrics.value(12)),
        decoration: BoxDecoration(
          color: surge.fill,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: surge.separator, width: 0.5),
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: metrics.value(15),
                color: enabled ? surge.textPrimary : surge.textSecondary,
              ),
              SizedBox(width: metrics.value(7)),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 2,
                style: context.typography.controlLabel.copyWith(
                  color: enabled ? surge.textPrimary : surge.textSecondary,
                ),
              ),
            ),
            SizedBox(width: metrics.value(6)),
            Icon(
              SurgeIcons.down,
              size: metrics.value(19),
              color: surge.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftOsSelectPopup<T> extends StatelessWidget {
  const _SoftOsSelectPopup({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.maxHeight,
    required this.width,
  });

  final T value;
  final List<SoftOsSelectItem<T>> items;
  final ValueChanged<T>? onChanged;
  final double maxHeight;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final metrics = SoftOsMetrics.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? metrics.value(188),
        maxWidth: width ?? metrics.value(280),
        maxHeight: metrics.value(maxHeight),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surge.elevatedCard,
          borderRadius: BorderRadius.circular(surge.radii.card),
          border: Border.all(color: surge.separator),
          boxShadow: [
            BoxShadow(
              color: surge.shadow.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(surge.radii.card),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: items.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: surge.separator.withValues(alpha: 0.58),
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = item.value == value;
                return SurgePressable(
                  scaleFeedback: false,
                  onTap: onChanged == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onChanged!(item.value);
                        },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: metrics.tap(44)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.value(14),
                        vertical: metrics.value(8),
                      ),
                      child: Row(
                        children: [
                          if (item.icon != null) ...[
                            Icon(
                              item.icon,
                              size: metrics.value(17),
                              color: selected
                                  ? surge.primary
                                  : surge.textSecondary,
                            ),
                            SizedBox(width: metrics.value(10)),
                          ],
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  maxLines: 2,
                                  style: context.typography.rowTitle.copyWith(
                                    color: selected
                                        ? surge.primary
                                        : surge.textPrimary,
                                  ),
                                ),
                                if (item.subtitle case final subtitle?) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    style: context.typography.supporting
                                        .copyWith(color: surge.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(width: metrics.value(12)),
                          SurgeSelectIndicator(selected: selected, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
