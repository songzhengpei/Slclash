import 'package:flutter/material.dart';

import 'surge_motion.dart';
import 'surge_theme_extension.dart';

class SurgePressable extends StatefulWidget {
  const SurgePressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = BorderRadius.zero,
    this.scaleFeedback = true,
    this.overlayFeedback = true,
    this.overlayOpacity,
    this.compact = false,
    this.enabled = true,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadiusGeometry borderRadius;
  final bool scaleFeedback;
  final bool overlayFeedback;
  final double? overlayOpacity;
  final bool compact;
  final bool enabled;
  final String? semanticLabel;
  final HitTestBehavior behavior;

  @override
  State<SurgePressable> createState() => _SurgePressableState();
}

class _SurgePressableState extends State<SurgePressable> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant SurgePressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final scale = !widget.scaleFeedback || !_pressed
        ? 1.0
        : widget.compact
        ? SurgeMotion.compactPressedScale
        : SurgeMotion.pressedScale;
    Widget result = AnimatedScale(
      scale: scale,
      duration: SurgeMotion.press,
      curve: SurgeMotion.stateCurve,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (widget.overlayFeedback)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _pressed ? 1 : 0,
                    duration: SurgeMotion.press,
                    curve: SurgeMotion.stateCurve,
                    child: ColoredBox(
                      color: surge.textPrimary.withValues(
                        alpha:
                            widget.overlayOpacity ??
                            SurgeMotion.pressedOverlayOpacity,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    result = GestureDetector(
      behavior: widget.behavior,
      onTap: _interactive ? widget.onTap : null,
      onTapDown: _interactive ? (_) => _setPressed(true) : null,
      onTapUp: _interactive ? (_) => _setPressed(false) : null,
      onTapCancel: _interactive ? () => _setPressed(false) : null,
      child: result,
    );
    return Semantics(
      button: _interactive,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: result,
    );
  }
}
