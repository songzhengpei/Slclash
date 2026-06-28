import 'package:flutter/material.dart';

import 'surge_card.dart';
import 'surge_motion.dart';
import 'surge_theme_extension.dart';

enum SurgeActionCardVariant { plain, filled, tonal }

class SurgeActionCard extends StatefulWidget {
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
    this.pressFeedback = true,
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
  final bool pressFeedback;

  @override
  State<SurgeActionCard> createState() => _SurgeActionCardState();
}

class _SurgeActionCardState extends State<SurgeActionCard> {
  bool _pressed = false;

  Color _backgroundColor(SurgeTheme surge) {
    if (widget.destructive) {
      return surge.red.withValues(alpha: widget.selected ? 0.18 : 0.10);
    }
    if (widget.selected) {
      return surge.selectedFill;
    }
    return switch (widget.variant) {
      SurgeActionCardVariant.plain => surge.card,
      SurgeActionCardVariant.filled => surge.fill.withValues(alpha: 0.68),
      SurgeActionCardVariant.tonal => surge.primary.withValues(alpha: 0.08),
    };
  }

  Color _borderColor(SurgeTheme surge) {
    if (widget.destructive) {
      return surge.red.withValues(alpha: widget.selected ? 0.72 : 0.42);
    }
    if (widget.selected) {
      return surge.primary.withValues(alpha: 0.48);
    }
    return switch (widget.variant) {
      SurgeActionCardVariant.plain => surge.separator,
      SurgeActionCardVariant.filled => Colors.transparent,
      SurgeActionCardVariant.tonal => surge.primary.withValues(alpha: 0.16),
    };
  }

  void _setPressed(bool value) {
    if (_pressed == value || !widget.pressFeedback || widget.onTap == null) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: SurgeMotion.press,
        curve: SurgeMotion.stateCurve,
        child: SurgeCard(
          margin: widget.margin,
          padding: widget.padding ?? EdgeInsets.zero,
          borderRadius: widget.borderRadius ?? surge.radii.list,
          backgroundColor: _backgroundColor(surge),
          border: Border.all(
            color: _borderColor(surge),
            width:
                widget.variant == SurgeActionCardVariant.filled &&
                    !widget.selected
                ? 0
                : surge.spacing.hairline,
          ),
          shadow: widget.shadow,
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}
