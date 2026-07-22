import 'package:fl_clash/widgets/popup.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

import 'sl_app_bar_action.dart';

Color _resolveActionColor(
  BuildContext context,
  SlAppBarActionTone tone,
  bool enabled,
) {
  final colorScheme = Theme.of(context).colorScheme;
  if (!enabled) {
    return colorScheme.onSurfaceVariant.withValues(alpha: 0.38);
  }
  return switch (tone) {
    SlAppBarActionTone.normal => colorScheme.onSurfaceVariant,
    SlAppBarActionTone.primary => colorScheme.primary,
    SlAppBarActionTone.destructive => colorScheme.error,
  };
}

class SlAppBarIconButton extends StatelessWidget {
  const SlAppBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.enabled = true,
    this.tone = SlAppBarActionTone.normal,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool enabled;
  final SlAppBarActionTone tone;

  static const double _tapSize = 48;
  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final color = _resolveActionColor(context, tone, enabled);
    return Semantics(
      label: tooltip,
      button: true,
      enabled: enabled,
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: _tapSize,
          child: IconButton(
            icon: Icon(icon, size: _iconSize),
            onPressed: enabled ? onPressed : null,
            color: color,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: WidgetStatePropertyAll(Size(_tapSize, _tapSize)),
              maximumSize: WidgetStatePropertyAll(Size(_tapSize, _tapSize)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              shadowColor: WidgetStatePropertyAll(Colors.transparent),
              elevation: WidgetStatePropertyAll(0),
              side: WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(CircleBorder()),
            ),
          ),
        ),
      ),
    );
  }
}

class SlAppBarTextButton extends StatelessWidget {
  const SlAppBarTextButton({
    super.key,
    required this.label,
    required this.tooltip,
    this.onPressed,
    this.enabled = true,
    this.tone = SlAppBarActionTone.normal,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool enabled;
  final SlAppBarActionTone tone;

  static const double _minHeight = 48;

  @override
  Widget build(BuildContext context) {
    final color = _resolveActionColor(context, tone, enabled);
    return Semantics(
      label: tooltip,
      button: true,
      enabled: enabled,
      child: Tooltip(
        message: tooltip,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: TextButton(
            onPressed: enabled ? onPressed : null,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
              minimumSize: const WidgetStatePropertyAll(
                Size(_minHeight, _minHeight),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              backgroundColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              shadowColor: const WidgetStatePropertyAll(Colors.transparent),
              elevation: const WidgetStatePropertyAll(0),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(),
              ),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return color.withValues(alpha: 0.38);
                }
                return color;
              }),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.controlLabel.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class SlAppBarOverflowButton extends StatefulWidget {
  const SlAppBarOverflowButton({
    super.key,
    required this.popup,
    required this.tooltip,
    this.enabled = true,
  });

  final Widget popup;
  final String tooltip;
  final bool enabled;

  @override
  State<SlAppBarOverflowButton> createState() => _SlAppBarOverflowButtonState();
}

class _SlAppBarOverflowButtonState extends State<SlAppBarOverflowButton> {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.tooltip,
      button: true,
      enabled: widget.enabled,
      child: CommonPopupBox(
        popup: widget.popup,
        targetBuilder: (open) {
          return SlAppBarIconButton(
            icon: SurgeIcons.moreVertical,
            tooltip: widget.tooltip,
            enabled: widget.enabled,
            onPressed: widget.enabled ? () => open() : null,
          );
        },
      ),
    );
  }
}
