import 'package:flutter/material.dart';

/// Determines the icon/text color of an app-bar action.
enum SlAppBarActionTone {
  normal,
  primary,
  destructive,
}

/// Base class for every semantic action that can appear in a SlClash AppBar
/// or Sheet toolbar.
abstract base class SlAppBarAction {
  const SlAppBarAction({this.enabled = true});

  final bool enabled;

  /// Resolves the foreground colour for [tone] against [context]'s colour
  /// scheme.
  static Color resolveColor(
    BuildContext context,
    SlAppBarActionTone tone,
  ) {
    final cs = Theme.of(context).colorScheme;
    return switch (tone) {
      SlAppBarActionTone.normal => cs.onSurfaceVariant,
      SlAppBarActionTone.primary => cs.primary,
      SlAppBarActionTone.destructive => cs.error,
    };
  }
}

/// A single-icon action (search, refresh, settings, back, close, …).
final class SlAppBarIconAction extends SlAppBarAction {
  const SlAppBarIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = SlAppBarActionTone.normal,
    super.enabled,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final SlAppBarActionTone tone;
}

/// A text-label action (save, done, apply, delete, cancel, …).
///
/// At most one text action should appear in a single toolbar.
final class SlAppBarTextAction extends SlAppBarAction {
  const SlAppBarTextAction({
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.tone = SlAppBarActionTone.primary,
    super.enabled,
  });

  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final SlAppBarActionTone tone;
}

/// A three-dot overflow action that opens a popup menu.
final class SlAppBarOverflowAction extends SlAppBarAction {
  const SlAppBarOverflowAction({
    required this.popup,
    required this.tooltip,
    super.enabled,
  });

  final Widget popup;
  final String tooltip;
}

/// An explicitly declared group of tightly-coupled icon actions that MAY keep
/// the Soft-OS Dock visual (the only path that still uses the grouped look).
final class SlAppBarActionGroup extends SlAppBarAction {
  const SlAppBarActionGroup({
    required this.actions,
    super.enabled,
  });

  final List<SlAppBarIconAction> actions;
}
