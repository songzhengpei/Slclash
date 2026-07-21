import 'package:flutter/material.dart';

import '../popup.dart';
import 'sl_app_bar_action.dart';

/// Minimum tap-target size used by every app-bar button.
const kSlAppBarTapHeight = 48.0;
const _kIconVisualSize = 24.0;

/// ───────────────────────────────────────
///  SlAppBarIconButton
/// ───────────────────────────────────────

/// A flat, container-less icon button for AppBars and Sheet toolbars.
///
/// * No background, border, or shadow in its resting state.
/// * 48 dp tap target.
/// * Always exposes [tooltip] and a [Semantics] label.
class SlAppBarIconButton extends StatelessWidget {
  const SlAppBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = SlAppBarActionTone.normal,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final SlAppBarActionTone tone;

  @override
  Widget build(BuildContext context) {
    final color = onPressed != null
        ? SlAppBarAction.resolveColor(context, tone)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          onTap: onPressed,
          child: SizedBox(
            width: kSlAppBarTapHeight,
            height: kSlAppBarTapHeight,
            child: Icon(
              icon,
              size: _kIconVisualSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// ───────────────────────────────────────
///  SlAppBarTextButton
/// ───────────────────────────────────────

/// A flat, container-less text button for AppBars and Sheet toolbars.
///
/// * No background, border, or shadow.
/// * 48 dp minimum tap height.
/// * Tone drives text colour (primary = accent, destructive = error).
class SlAppBarTextButton extends StatelessWidget {
  const SlAppBarTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.tone = SlAppBarActionTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final SlAppBarActionTone tone;

  @override
  Widget build(BuildContext context) {
    final color = onPressed != null
        ? SlAppBarAction.resolveColor(context, tone)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

    final Widget content = Semantics(
      label: label,
      button: true,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kSlAppBarTapHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: content);
    }
    return content;
  }
}

/// ───────────────────────────────────────
///  SlAppBarOverflowButton
/// ───────────────────────────────────────

/// A flat three-dot overflow button that opens [popup].
///
/// * No background, border, or shadow.
/// * 48 dp tap target.
/// * Uses the same [CommonPopupRoute] mechanism as the rest of the app.
class SlAppBarOverflowButton extends StatefulWidget {
  const SlAppBarOverflowButton({
    super.key,
    required this.popup,
    required this.tooltip,
  });

  final Widget popup;
  final String tooltip;

  @override
  State<SlAppBarOverflowButton> createState() => _SlAppBarOverflowButtonState();
}

class _SlAppBarOverflowButtonState extends State<SlAppBarOverflowButton> {
  final _offsetNotifier = ValueNotifier<Offset>(Offset.zero);

  void _handleTap() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Position the popup relative to the button's top-right corner.
    final global = renderBox.localToGlobal(Offset.zero);
    _offsetNotifier.value = Offset(global.dx, global.dy);

    Navigator.of(context)
        .push(
          CommonPopupRoute(
            barrierLabel: 'app_bar_overflow',
            builder: (_) => widget.popup,
            offsetNotifier: _offsetNotifier,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: widget.tooltip,
      button: true,
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          onTap: _handleTap,
          child: SizedBox(
            width: kSlAppBarTapHeight,
            height: kSlAppBarTapHeight,
            child: Icon(
              Icons.more_horiz_rounded,
              size: _kIconVisualSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// ───────────────────────────────────────
///  Leading-button factory
/// ───────────────────────────────────────

/// Builds a flat back or close button for the leading slot.
SlAppBarIconButton slAppBarLeadingButton({
  required String tooltip,
  required VoidCallback? onPressed,
  bool isClose = false,
}) {
  return SlAppBarIconButton(
    icon: isClose ? Icons.close_rounded : Icons.arrow_back_rounded,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}
