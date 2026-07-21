import 'package:flutter/material.dart';

enum SlAppBarActionTone { normal, primary, destructive }

sealed class SlAppBarAction {
  const SlAppBarAction();
}

class SlAppBarIconAction extends SlAppBarAction {
  const SlAppBarIconAction({
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
}

class SlAppBarTextAction extends SlAppBarAction {
  const SlAppBarTextAction({
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
}

class SlAppBarOverflowAction extends SlAppBarAction {
  const SlAppBarOverflowAction({
    required this.popup,
    required this.tooltip,
    this.enabled = true,
  });

  final Widget popup;
  final String tooltip;
  final bool enabled;
}

class SlAppBarActionGroup extends SlAppBarAction {
  const SlAppBarActionGroup({
    required this.actions,
    this.enabled = true,
  });

  final List<SlAppBarIconAction> actions;
  final bool enabled;
}
