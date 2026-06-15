import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';

@immutable
class SurgeSegmentedItem<T> {
  const SurgeSegmentedItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class SurgeSegmentedControl<T> extends StatelessWidget {
  const SurgeSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.height = 34,
    this.padding = const EdgeInsets.all(3),
  });

  final T value;
  final List<SurgeSegmentedItem<T>> items;
  final ValueChanged<T> onChanged;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(surge.radii.button);

    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: radius,
        border: Border.all(color: surge.separator, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            Expanded(
              child: _SurgeSegment<T>(
                item: item,
                selected: item.value == value,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _SurgeSegment<T> extends StatelessWidget {
  const _SurgeSegment({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  final SurgeSegmentedItem<T> item;
  final bool selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final foreground = selected ? surge.primary : surge.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? surge.elevatedCard : Colors.transparent,
        borderRadius: BorderRadius.circular(surge.radii.button),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: surge.shadow.withValues(alpha: 0.7),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(item.value),
          borderRadius: BorderRadius.circular(surge.radii.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, color: foreground, size: 15),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
