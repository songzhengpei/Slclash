import 'package:flutter/material.dart';
import 'package:fl_clash/widgets/surge/surge.dart';

import 'sl_app_bar_action.dart';
import 'sl_app_bar_buttons.dart';

class SlAppBarActionsRenderer extends StatelessWidget {
  const SlAppBarActionsRenderer({
    super.key,
    required this.actions,
    this.softOs = false,
  });

  final List<SlAppBarAction> actions;
  final bool softOs;

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
      SlAppBarIconAction(
        :final icon,
        :final tooltip,
        :final onPressed,
        :final enabled,
        :final tone,
      ) =>
        softOs
            ? SoftOsActionButton(
                icon: icon,
                tooltip: tooltip,
                onPressed: enabled ? onPressed : null,
                compact: true,
              )
            : SlAppBarIconButton(
                icon: icon,
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
          softOs: softOs,
        ),
      SlAppBarActionGroup(:final actions, :final enabled) => _ActionGroupWidget(
        actions: actions,
        enabled: enabled,
        softOs: softOs,
      ),
    };
  }
}

class _ActionGroupWidget extends StatelessWidget {
  const _ActionGroupWidget({
    required this.actions,
    required this.enabled,
    required this.softOs,
  });

  final List<SlAppBarIconAction> actions;
  final bool enabled;
  final bool softOs;

  @override
  Widget build(BuildContext context) {
    if (softOs) {
      return SoftOsActionDock(
        compact: true,
        children: [
          for (final action in actions)
            SoftOsActionDockButton(
              icon: action.icon,
              tooltip: action.tooltip,
              onPressed: enabled && action.enabled ? action.onPressed : null,
              compact: true,
            ),
        ],
      );
    }
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
