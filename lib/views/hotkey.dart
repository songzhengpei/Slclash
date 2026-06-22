import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/card.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final Map<PhysicalKeyboardKey, String> _knownKeyLabels =
    <PhysicalKeyboardKey, String>{
      PhysicalKeyboardKey.keyA: 'A',
      PhysicalKeyboardKey.keyB: 'B',
      PhysicalKeyboardKey.keyC: 'C',
      PhysicalKeyboardKey.keyD: 'D',
      PhysicalKeyboardKey.keyE: 'E',
      PhysicalKeyboardKey.keyF: 'F',
      PhysicalKeyboardKey.keyG: 'G',
      PhysicalKeyboardKey.keyH: 'H',
      PhysicalKeyboardKey.keyI: 'I',
      PhysicalKeyboardKey.keyJ: 'J',
      PhysicalKeyboardKey.keyK: 'K',
      PhysicalKeyboardKey.keyL: 'L',
      PhysicalKeyboardKey.keyM: 'M',
      PhysicalKeyboardKey.keyN: 'N',
      PhysicalKeyboardKey.keyO: 'O',
      PhysicalKeyboardKey.keyP: 'P',
      PhysicalKeyboardKey.keyQ: 'Q',
      PhysicalKeyboardKey.keyR: 'R',
      PhysicalKeyboardKey.keyS: 'S',
      PhysicalKeyboardKey.keyT: 'T',
      PhysicalKeyboardKey.keyU: 'U',
      PhysicalKeyboardKey.keyV: 'V',
      PhysicalKeyboardKey.keyW: 'W',
      PhysicalKeyboardKey.keyX: 'X',
      PhysicalKeyboardKey.keyY: 'Y',
      PhysicalKeyboardKey.keyZ: 'Z',
      PhysicalKeyboardKey.digit1: '1',
      PhysicalKeyboardKey.digit2: '2',
      PhysicalKeyboardKey.digit3: '3',
      PhysicalKeyboardKey.digit4: '4',
      PhysicalKeyboardKey.digit5: '5',
      PhysicalKeyboardKey.digit6: '6',
      PhysicalKeyboardKey.digit7: '7',
      PhysicalKeyboardKey.digit8: '8',
      PhysicalKeyboardKey.digit9: '9',
      PhysicalKeyboardKey.digit0: '0',
      PhysicalKeyboardKey.enter: 'ENTER',
      PhysicalKeyboardKey.escape: 'ESCAPE',
      PhysicalKeyboardKey.backspace: 'BACKSPACE',
      PhysicalKeyboardKey.tab: 'TAB',
      PhysicalKeyboardKey.space: 'SPACE',
      PhysicalKeyboardKey.minus: '-',
      PhysicalKeyboardKey.equal: '=',
      PhysicalKeyboardKey.bracketLeft: '[',
      PhysicalKeyboardKey.bracketRight: ']',
      PhysicalKeyboardKey.backslash: '\\',
      PhysicalKeyboardKey.semicolon: ';',
      PhysicalKeyboardKey.quote: '"',
      PhysicalKeyboardKey.backquote: '`',
      PhysicalKeyboardKey.comma: ',',
      PhysicalKeyboardKey.period: '.',
      PhysicalKeyboardKey.slash: '/',
      PhysicalKeyboardKey.capsLock: 'CAPSLOCK',
      PhysicalKeyboardKey.f1: 'F1',
      PhysicalKeyboardKey.f2: 'F2',
      PhysicalKeyboardKey.f3: 'F3',
      PhysicalKeyboardKey.f4: 'F4',
      PhysicalKeyboardKey.f5: 'F5',
      PhysicalKeyboardKey.f6: 'F6',
      PhysicalKeyboardKey.f7: 'F7',
      PhysicalKeyboardKey.f8: 'F8',
      PhysicalKeyboardKey.f9: 'F9',
      PhysicalKeyboardKey.f10: 'F10',
      PhysicalKeyboardKey.f11: 'F11',
      PhysicalKeyboardKey.f12: 'F12',
      PhysicalKeyboardKey.home: 'HOME',
      PhysicalKeyboardKey.pageUp: 'PAGEUP',
      PhysicalKeyboardKey.delete: 'DELETE',
      PhysicalKeyboardKey.end: 'END',
      PhysicalKeyboardKey.pageDown: 'PAGEDOWN',
      PhysicalKeyboardKey.arrowRight: '→',
      PhysicalKeyboardKey.arrowLeft: '←',
      PhysicalKeyboardKey.arrowDown: '↓',
      PhysicalKeyboardKey.arrowUp: '↑',
      PhysicalKeyboardKey.controlLeft: 'CTRL',
      PhysicalKeyboardKey.shiftLeft: 'SHIFT',
      PhysicalKeyboardKey.altLeft: 'ALT',
      PhysicalKeyboardKey.metaLeft: 'WIN',
      PhysicalKeyboardKey.controlRight: 'CTRL',
      PhysicalKeyboardKey.shiftRight: 'SHIFT',
      PhysicalKeyboardKey.altRight: 'ALT',
      PhysicalKeyboardKey.metaRight: 'WIN',
      PhysicalKeyboardKey.fn: 'FN',
    };

extension KeyboardKeyExt on KeyboardKey {
  String get label {
    if (this is PhysicalKeyboardKey) {
      final physicalKey = this as PhysicalKeyboardKey;
      return _knownKeyLabels[physicalKey] ?? physicalKey.debugName ?? 'Unknown';
    }
    if (this is LogicalKeyboardKey) {
      return (this as LogicalKeyboardKey).debugName ?? 'Unknown';
    }
    return 'Unknown';
  }
}

extension IntlExt on Intl {
  static String actionMessage(String messageText) =>
      Intl.message('action_$messageText');
}

class HotKeyView extends StatelessWidget {
  const HotKeyView({super.key});

  String getSubtitle(BuildContext context, HotKeyAction hotKeyAction) {
    final appLocalizations = context.appLocalizations;
    final key = hotKeyAction.key;
    if (key == null) {
      return appLocalizations.noHotKey;
    }
    final modifierLabels = hotKeyAction.modifiers.map(
      (item) => item.physicalKeys.first.label,
    );
    var text = '';
    if (modifierLabels.isNotEmpty) {
      text += "${modifierLabels.join(" ")}+";
    }
    text += PhysicalKeyboardKey(key).label;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return BaseScaffold(
      title: appLocalizations.hotkeyManagement,
      body: ListView.builder(
        itemCount: HotAction.values.length,
        itemBuilder: (_, index) {
          final hotAction = HotAction.values[index];
          return Consumer(
            builder: (_, ref, _) {
              final hotKeyAction = ref.watch(
                getHotKeyActionProvider(hotAction),
              );
              return ListItem(
                title: Text(IntlExt.actionMessage(hotAction.name)),
                subtitle: Text(
                  getSubtitle(context, hotKeyAction),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.primary,
                  ),
                ),
                onTap: () {
                  globalState.showCommonDialog(
                    child: HotKeyRecorder(hotKeyAction: hotKeyAction),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class HotKeyRecorder extends ConsumerStatefulWidget {
  final HotKeyAction hotKeyAction;

  const HotKeyRecorder({super.key, required this.hotKeyAction});

  @override
  ConsumerState<HotKeyRecorder> createState() => _HotKeyRecorderState();
}

class _HotKeyRecorderState extends ConsumerState<HotKeyRecorder> {
  late ValueNotifier<HotKeyAction> hotKeyActionNotifier;

  @override
  void initState() {
    super.initState();
    hotKeyActionNotifier = ValueNotifier<HotKeyAction>(
      widget.hotKeyAction.copyWith(),
    );
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent keyEvent) {
    if (keyEvent is KeyUpEvent) return false;
    final keys = HardwareKeyboard.instance.physicalKeysPressed;

    final key = keyEvent.physicalKey;

    final modifiers = KeyboardModifier.values
        .where(
          (e) =>
              e.physicalKeys.any(keys.contains) &&
              !e.physicalKeys.contains(key),
        )
        .toSet();
    hotKeyActionNotifier.value = hotKeyActionNotifier.value.copyWith(
      modifiers: modifiers,
      key: key.usbHidUsage,
    );
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void _handleRemove() {
    Navigator.of(context).pop();
    _updateOrAddHotKeyAction(
      hotKeyActionNotifier.value.copyWith(modifiers: {}, key: null),
    );
  }

  void _handleConfirm() {
    final appLocalizations = context.appLocalizations;
    Navigator.of(context).pop();
    final hotKeyActions = ref.read(hotKeyActionsProvider);
    final currentHotkeyAction = hotKeyActionNotifier.value;
    if (currentHotkeyAction.key == null ||
        currentHotkeyAction.modifiers.isEmpty) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: appLocalizations.inputCorrectHotkey),
      );
      return;
    }
    final index = hotKeyActions.indexWhere(
      (item) =>
          item.key == currentHotkeyAction.key &&
          keyboardModifierListEquality.equals(
            item.modifiers,
            currentHotkeyAction.modifiers,
          ),
    );
    if (index != -1) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: appLocalizations.hotkeyConflict),
      );
      return;
    }
    _updateOrAddHotKeyAction(currentHotkeyAction);
  }

  void _updateOrAddHotKeyAction(HotKeyAction hotKeyAction) {
    final hotKeyActions = ref.read(hotKeyActionsProvider);
    final index = hotKeyActions.indexWhere(
      (item) => item.action == hotKeyAction.action,
    );
    if (index == -1) {
      ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..add(hotKeyAction);
    } else {
      ref.read(hotKeyActionsProvider.notifier).value = List.from(hotKeyActions)
        ..[index] = hotKeyAction;
    }

    ref.read(hotKeyActionsProvider.notifier).value = index == -1
        ? (List.from(hotKeyActions)..add(hotKeyAction))
        : (List.from(hotKeyActions)..[index] = hotKeyAction);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Focus(
      onKeyEvent: (_, _) {
        return KeyEventResult.handled;
      },
      autofocus: true,
      child: CommonDialog(
        title: IntlExt.actionMessage(widget.hotKeyAction.action.name),
        actions: [
          TextButton(
            onPressed: () {
              _handleRemove();
            },
            child: Text(appLocalizations.remove),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _handleConfirm();
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: ValueListenableBuilder(
          valueListenable: hotKeyActionNotifier,
          builder: (_, hotKeyAction, _) {
            final key = hotKeyAction.key;
            final modifiers = hotKeyAction.modifiers;
            return SizedBox(
              width: dialogCommonWidth,
              child: key != null
                  ? Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final modifier in modifiers)
                          KeyboardKeyBox(
                            keyboardKey: modifier.physicalKeys.first,
                          ),
                        if (modifiers.isNotEmpty)
                          Text('+', style: context.textTheme.titleMedium),
                        KeyboardKeyBox(keyboardKey: PhysicalKeyboardKey(key)),
                      ],
                    )
                  : Text(
                      appLocalizations.pressKeyboard,
                      style: context.textTheme.titleMedium,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class KeyboardKeyBox extends StatelessWidget {
  final KeyboardKey keyboardKey;

  const KeyboardKeyBox({super.key, required this.keyboardKey});

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(keyboardKey.label, style: const TextStyle(fontSize: 16)),
      ),
      onPressed: () {},
    );
  }
}
