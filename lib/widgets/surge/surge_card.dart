import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';

class SurgeCard extends StatelessWidget {
  const SurgeCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.onTap,
    this.height,
    this.width,
    this.shadow = true,
    this.border,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final bool shadow;
  final BoxBorder? border;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(borderRadius ?? surge.radii.card);
    final decoration = BoxDecoration(
      color: backgroundColor ?? surge.card,
      border: border ?? Border.all(color: surge.separator, width: 0.5),
      borderRadius: radius,
      boxShadow: shadow
          ? [
              BoxShadow(
                color: surge.shadow.withValues(alpha: 0.55),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        clipBehavior: clipBehavior,
        borderRadius: radius,
        child: Ink(
          height: height,
          width: width,
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: padding ?? EdgeInsets.all(surge.spacing.cardPadding),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
