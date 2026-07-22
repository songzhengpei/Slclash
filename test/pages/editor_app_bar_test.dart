import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/app_bar/sl_app_bar_buttons_test.dart';

void main() {
  group('Editor app bar action model', () {
    test('SlAppBarIconAction with save icon', () {
      final action = SlAppBarIconAction(
        icon: SurgeIcons.save,
        tooltip: 'Save',
        onPressed: () {},
      );
      expect(action.tooltip, 'Save');
      expect(action.onPressed, isNotNull);
      expect(action.enabled, isTrue);
    });

    test('SlAppBarIconAction disabled when onPressed is null', () {
      final action = SlAppBarIconAction(
        icon: SurgeIcons.save,
        tooltip: 'Save',
        onPressed: null,
      );
      expect(action.onPressed, isNull);
      expect(action.enabled, isTrue);
    });

    test('SlAppBarOverflowAction with popup', () {
      final action = SlAppBarOverflowAction(
        tooltip: 'More',
        popup: const SizedBox(),
      );
      expect(action.tooltip, 'More');
      expect(action.popup, isNotNull);
    });

    test('SlAppBarIconAction with destructive tone', () {
      final action = SlAppBarIconAction(
        icon: SurgeIcons.delete,
        tooltip: 'Delete',
        onPressed: () {},
        tone: SlAppBarActionTone.destructive,
      );
      expect(action.tone, SlAppBarActionTone.destructive);
    });
  });
}
