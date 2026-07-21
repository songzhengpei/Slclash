import 'package:flutter/material.dart';

import 'sl_app_bar_action.dart';
import 'sl_app_bar_buttons.dart';

class SlAppBarActionsRenderer extends StatelessWidget {
  const SlAppBarActionsRenderer({super.key, required this.actions});

  final List<SlAppBarAction> actions;

  @override
  Widget build(BuildContext context) {
    assert(
      actions.length <= 2,
      'SlAppBarActionsRenderer expects at most 2 actions. '
      'Use SlAppBarActionGroup to combine tightly-coupled actions into one slot.',
    );

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _buildAction(context, actions[i]),
        ],
      ],
    );
  }

  Widget _buildAction(BuildContext context, SlAppBarAction action) {
    return switch (action) {
      SlAppBarIconAction(:final icon, :final tooltip, :final onPressed, :final enabled, :final tone) =>
        SlAppBarIconButton(
          icon: icon,
          tooltip: tooltip,
          onPressed: onPressed,
          enabled: enabled,
          tone: tone,
        ),
      SlAppBarTextAction(:final label, :final tooltip, :final onPressed, :final enabled, :final tone) =>
        SlAppBarTextButton(
          label: label,
          tooltip: tooltip,
          onPressed: onPressed,
          enabled: enabled,
          tone: tone,
        ),
      SlAppBarOverflowAction(:final popup, :final tooltip, :final enabled) =>
        SlAppBarOverflowButton(
          popup: popup,
          tooltip: tooltip,
          enabled: enabled,
        ),
      SlAppBarActionGroup(:final actions, :final enabled) =>
        _ActionGroupWidget(actions: actions, enabled: enabled),
    };
  }
}

class _ActionGroupWidget extends StatelessWidget {
  const _ActionGroupWidget({required this.actions, required this.enabled});

  final List<SlAppBarIconAction> actions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          SlAppBarIconButton(
            icon: actions[i].icon,
            tooltip: actions[i].tooltip,
            onPressed: actions[i].onPressed,
            enabled: enabled && actions[i].enabled,
            tone: actions[i].tone,
          ),
        ],
      ],
    );
  }
}
