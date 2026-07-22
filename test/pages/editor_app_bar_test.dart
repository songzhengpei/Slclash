import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_buttons.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _editorApp({
  required String title,
  String? content,
  bool titleEditable = true,
  Function(BuildContext, String, String)? onSave,
}) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return UncontrolledProviderScope(
    container: globalState.container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        textTheme: textTheme,
        extensions: [SurgeTheme.light(), typography],
      ),
      home: SheetProvider(
        type: SheetType.page,
        child: EditorPage(
          title: title,
          content: content,
          titleEditable: titleEditable,
          onSave: onSave,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    globalState.container = ProviderContainer();
  });

  group('Editor app bar reactive behavior', () {
    testWidgets('save button disabled when content unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _editorApp(
          title: 'Test',
          content: 'hello',
          onSave: (_, __, ___) {},
        ),
      );
      await tester.pumpAndSettle();

      // Verify save button exists and is disabled (onPressed is null)
      final saveButton = find.widgetWithIcon(SlAppBarIconButton, SurgeIcons.save);
      expect(saveButton, findsOneWidget);
      final saveAction = tester.widget<SlAppBarIconButton>(saveButton);
      expect(saveAction.onPressed, isNull);
    });

    testWidgets('save button hidden in read-only mode', (tester) async {
      await tester.pumpWidget(
        _editorApp(
          title: 'Test',
          content: 'hello',
          onSave: null,
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byIcon(SurgeIcons.save);
      expect(saveButton, findsNothing);
    });

    testWidgets('overflow menu button exists and is tappable', (tester) async {
      await tester.pumpWidget(
        _editorApp(
          title: 'Test',
          content: 'hello',
          onSave: (_, __, ___) {},
        ),
      );
      await tester.pumpAndSettle();

      final overflowButton = find.byType(SlAppBarOverflowButton);
      expect(overflowButton, findsOneWidget);
      // Tap should not throw
      await tester.tap(overflowButton);
      await tester.pumpAndSettle();
    });

    testWidgets('title TextField is rendered', (tester) async {
      await tester.pumpWidget(
        _editorApp(
          title: 'Test Title',
          content: 'hello',
          onSave: (_, __, ___) {},
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byType(TextField);
      expect(titleFinder, findsOneWidget);
    });

    testWidgets('title can be edited and save becomes enabled', (tester) async {
      await tester.pumpWidget(
        _editorApp(
          title: 'Original',
          content: 'hello',
          titleEditable: true,
          onSave: (_, __, ___) {},
        ),
      );
      await tester.pumpAndSettle();

      // Initially save should be disabled
      final saveButton = find.widgetWithIcon(SlAppBarIconButton, SurgeIcons.save);
      expect(saveButton, findsOneWidget);
      final initialSaveAction = tester.widget<SlAppBarIconButton>(saveButton);
      expect(initialSaveAction.onPressed, isNull);

      // Edit title
      final titleFinder = find.byType(TextField);
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();
      await tester.enterText(titleFinder, 'Modified');
      await tester.pumpAndSettle();

      expect(find.text('Modified'), findsOneWidget);

      // Save button should now be enabled
      final updatedSaveAction = tester.widget<SlAppBarIconButton>(saveButton);
      expect(updatedSaveAction.onPressed, isNotNull);
    });

    testWidgets('title not editable when titleEditable is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _editorApp(
          title: 'Read Only Title',
          content: 'hello',
          titleEditable: false,
          onSave: (_, __, ___) {},
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byType(TextField);
      final textField = tester.widget<TextField>(titleFinder);
      expect(textField.enabled, isFalse);
    });

    testWidgets('save callback receives modified title and content', (
      tester,
    ) async {
      String? savedTitle;
      String? savedContent;

      await tester.pumpWidget(
        _editorApp(
          title: 'Original',
          content: 'hello',
          titleEditable: true,
          onSave: (_, title, content) {
            savedTitle = title;
            savedContent = content;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Edit title to trigger save button enable
      final titleFinder = find.byType(TextField);
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();
      await tester.enterText(titleFinder, 'Modified');
      await tester.pumpAndSettle();

      // Verify save button is now enabled
      final saveButton = find.widgetWithIcon(SlAppBarIconButton, SurgeIcons.save);
      final updatedSaveAction = tester.widget<SlAppBarIconButton>(saveButton);
      expect(updatedSaveAction.onPressed, isNotNull);

      // Tap save button
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify callback received correct values
      expect(savedTitle, 'Modified');
      expect(savedContent, 'hello');
    });
  });
}
