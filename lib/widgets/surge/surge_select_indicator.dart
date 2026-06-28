import 'package:flutter/material.dart';

import 'surge_motion.dart';
import 'surge_theme_extension.dart';

class SurgeSelectIndicator extends StatelessWidget {
  const SurgeSelectIndicator({
    super.key,
    required this.selected,
    this.size = 24,
    this.iconSize = 16,
    this.showCheck = true,
  });

  final bool selected;
  final double size;
  final double iconSize;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    if (!showCheck) {
      final selectedColor = surge.primary;
      final idleColor = surge.textSecondary.withValues(alpha: 0.42);
      final borderColor = selected ? selectedColor : idleColor;
      return AnimatedContainer(
        duration: SurgeMotion.state,
        curve: SurgeMotion.stateCurve,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: borderColor,
            width: selected ? 1.25 : surge.spacing.hairline,
          ),
        ),
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1 : 0,
            duration: SurgeMotion.state,
            curve: SurgeMotion.stateCurve,
            child: Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: SurgeMotion.state,
      curve: SurgeMotion.stateCurve,
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
        duration: SurgeMotion.state,
        curve: SurgeMotion.stateCurve,
        child: selected
            ? Icon(Icons.check, size: iconSize, color: surge.onPrimary)
            : const SizedBox.shrink(),
      ),
    );
  }
}
