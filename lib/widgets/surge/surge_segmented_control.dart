import 'package:flutter/material.dart';

import 'surge_motion.dart';
import 'surge_pressable.dart';
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
    this.height,
    this.padding = const EdgeInsets.all(3),
  });

  final T value;
  final List<SurgeSegmentedItem<T>> items;
  final ValueChanged<T> onChanged;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(surge.radii.button);
    final height = this.height ?? surge.controls.segmentedHeight;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

/// Sliding variant for dense dashboard controls. It keeps the same semantic
/// item model as [SurgeSegmentedControl] while preserving a moving selection
/// surface where that is part of the current visual language.
class SurgeSlidingSegmentedControl<T> extends StatelessWidget {
  const SurgeSlidingSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.height,
    required this.padding,
    required this.backgroundColor,
    required this.selectedSurfaceColor,
    required this.selectedColor,
    required this.unselectedColor,
    required this.outerRadius,
    required this.selectedRadius,
    required this.labelStyle,
    this.indicatorDuration = SurgeMotion.container,
    this.textDuration = SurgeMotion.state,
  });

  final T value;
  final List<SurgeSegmentedItem<T>> items;
  final ValueChanged<T> onChanged;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color selectedSurfaceColor;
  final Color selectedColor;
  final Color unselectedColor;
  final double outerRadius;
  final double selectedRadius;
  final TextStyle labelStyle;
  final Duration indicatorDuration;
  final Duration textDuration;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexWhere((item) => item.value == value);
    final resolvedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(outerRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: indicatorDuration,
                curve: SurgeMotion.stateCurve,
                left: itemWidth * resolvedIndex,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selectedSurfaceColor,
                    borderRadius: BorderRadius.circular(selectedRadius),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onChanged(item.value),
                          borderRadius: BorderRadius.circular(selectedRadius),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: textDuration,
                              curve: SurgeMotion.stateCurve,
                              style: labelStyle.copyWith(
                                color: item.value == value
                                    ? selectedColor
                                    : unselectedColor,
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
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
      duration: SurgeMotion.reveal,
      curve: SurgeMotion.stateCurve,
      decoration: BoxDecoration(
        color: selected
            ? surge.card.withValues(alpha: 0.92)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(surge.radii.button),
        border: Border.all(
          color: selected
              ? surge.separator.withValues(alpha: 0.72)
              : Colors.transparent,
          width: surge.spacing.hairline,
        ),
      ),
      child: SurgePressable(
        onTap: () => onChanged(item.value),
        scaleFeedback: false,
        overlayFeedback: false,
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
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: context.typography.controlLabel.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
