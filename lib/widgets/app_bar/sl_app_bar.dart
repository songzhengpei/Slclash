import 'package:flutter/material.dart';

import '../surge/soft_os_control_dock.dart';
import 'sl_app_bar_action.dart';
import 'sl_app_bar_buttons.dart';

/// Maximum number of top-level actions (excluding [SlAppBarActionGroup] which
/// counts as one slot) that the AppBar will render independently.
///
/// Callers that need more should fold the extras into an
/// [SlAppBarOverflowAction].
const _kMaxDirectActions = 2;

/// Renders a list of [SlAppBarAction]s into the trailing slot of an AppBar or
/// Sheet toolbar.
///
/// * 0 actions → nothing
/// * 1 action → single button
/// * 2+ independent actions → rendered side by side (no dock)
/// * [SlAppBarActionGroup] → wrapped in the Soft-OS dock visual (the *only*
///   path that keeps a grouped look in the toolbar)
List<Widget> buildAppBarActions(BuildContext context, List<SlAppBarAction> actions) {
  assert(() {
    final topLevel = actions.where((a) => a is! SlAppBarActionGroup).length;
    if (topLevel > _kMaxDirectActions) {
      throw FlutterError(
        'AppBar has $topLevel direct actions (max $_kMaxDirectActions). '
        'Fold extras into SlAppBarOverflowAction or SlAppBarActionGroup.',
      );
    }
    return true;
  }());

  return [for (final action in actions) _buildAction(context, action)];

  // ignore_for_file: prefer_final_locals
}

Widget _buildAction(BuildContext context, SlAppBarAction action) {
  return switch (action) {
    SlAppBarIconAction a => _buildIconAction(context, a),
    SlAppBarTextAction a => _buildTextAction(context, a),
    SlAppBarOverflowAction a => _buildOverflowAction(context, a),
    SlAppBarActionGroup a => _buildActionGroup(context, a),
    _ => const SizedBox.shrink(),
  };
}

Widget _buildIconAction(BuildContext context, SlAppBarIconAction action) {
  return SlAppBarIconButton(
    icon: action.icon,
    tooltip: action.tooltip,
    onPressed: action.enabled ? action.onPressed : null,
    tone: action.tone,
  );
}

Widget _buildTextAction(BuildContext context, SlAppBarTextAction action) {
  return SlAppBarTextButton(
    label: action.label,
    onPressed: action.enabled ? action.onPressed : null,
    tooltip: action.tooltip,
    tone: action.tone,
  );
}

Widget _buildOverflowAction(BuildContext context, SlAppBarOverflowAction action) {
  return SlAppBarOverflowButton(
    popup: action.popup,
    tooltip: action.tooltip,
  );
}

/// Builds the Soft-OS dock for an explicitly-declared [SlAppBarActionGroup].
///
/// This is the **only** path that still uses [SoftOsActionDock] in the AppBar.
Widget _buildActionGroup(BuildContext context, SlAppBarActionGroup group) {
  final buttons = group.actions.map((a) {
    return SoftOsActionDockButton(
      icon: a.icon,
      tooltip: a.tooltip,
      onPressed: a.enabled ? a.onPressed : null,
    );
  }).toList();

  return SoftOsActionDock(children: buttons);
}
