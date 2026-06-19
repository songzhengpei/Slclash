import 'package:flutter/material.dart';

import 'surge_card.dart';
import 'surge_theme_extension.dart';

enum SurgeActionCardVariant { plain, filled, tonal }

class SurgeActionCard extends StatelessWidget {
  const SurgeActionCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.variant = SurgeActionCardVariant.plain,
    this.selected = false,
    this.destructive = false,
    this.shadow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final SurgeActionCardVariant variant;
  final bool selected;
  final bool destructive;
  final bool shadow;

  Color _backgroundColor(SurgeTheme surge) {
    if (destructive) {
      return surge.red.withValues(alpha: selected ? 0.18 : 0.10);
    }
    if (selected) {
      return surge.selectedFill;
    }
    return switch (variant) {
      SurgeActionCardVariant.plain => surge.card,
      SurgeActionCardVariant.filled => surge.fill.withValues(alpha: 0.68),
      SurgeActionCardVariant.tonal => surge.primary.withValues(alpha: 0.08),
    };
  }

  Color _borderColor(SurgeTheme surge) {
    if (destructive) {
      return surge.red.withValues(alpha: selected ? 0.72 : 0.42);
    }
    if (selected) {
      return surge.primary.withValues(alpha: 0.48);
    }
    return switch (variant) {
      SurgeActionCardVariant.plain => surge.separator,
      SurgeActionCardVariant.filled => Colors.transparent,
      SurgeActionCardVariant.tonal => surge.primary.withValues(alpha: 0.16),
    };
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return SurgeCard(
      margin: margin,
      padding: padding ?? EdgeInsets.zero,
      borderRadius: borderRadius ?? surge.radii.list,
      backgroundColor: _backgroundColor(surge),
      border: Border.all(
        color: _borderColor(surge),
        width: variant == SurgeActionCardVariant.filled && !selected
            ? 0
            : surge.spacing.hairline,
      ),
      shadow: shadow,
      onTap: onTap,
      child: child,
    );
  }
}
