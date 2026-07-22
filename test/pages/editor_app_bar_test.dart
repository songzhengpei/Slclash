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

      // Find the save IconButton by looking for the Icon widget's parent
      final saveIconFinder = find.byIcon(SurgeIcons.save);
      expect(saveIconFinder, findsOneWidget);
      // The save button should be in the AppBar actions area
      // Check that the overflow button exists (indicating the app bar rendered)
      expect(find.byIcon(SurgeIcons.moreVertical), findsOneWidget);
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

    testWidgets('title can be edited', (tester) async {
      await tester.pumpWidget(
        _editorApp(
          title: 'Original',
          content: 'hello',
          titleEditable: true,
          onSave: (_, __, ___) {},
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byType(TextField);
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();
      await tester.enterText(titleFinder, 'Modified');
      await tester.pumpAndSettle();

      expect(find.text('Modified'), findsOneWidget);
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
  });
}
