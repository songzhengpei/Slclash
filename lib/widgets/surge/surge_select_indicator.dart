import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';

class SurgeSelectIndicator extends StatelessWidget {
  const SurgeSelectIndicator({
    super.key,
    required this.selected,
    this.size = 24,
    this.iconSize = 16,
  });

  final bool selected;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? surge.primary : surge.fill.withValues(alpha: 0.58),
        border: Border.all(
          color: selected ? Colors.transparent : surge.separator,
          width: surge.spacing.hairline,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0.72,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: selected
            ? Icon(Icons.check, size: iconSize, color: surge.onPrimary)
            : const SizedBox.shrink(),
      ),
    );
  }
}
