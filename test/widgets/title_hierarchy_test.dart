import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return MaterialApp(
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
    home: home,
  );
}

Widget _sheetApp(Widget child, {SheetType sheetType = SheetType.page}) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return MaterialApp(
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
      type: sheetType,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    globalState.container = ProviderContainer();
  });

  group('Standard App Bar title', () {
    testWidgets('uses appBarTitle (19sp / w500)', (tester) async {
      await tester.pumpWidget(
        _app(CommonScaffold(title: 'Standard', body: const SizedBox())),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('Standard'));
      final expectedStyle = SurgeTypography.fromTextTheme(
        buildSlclashTextTheme(),
      ).appBarTitle;
      expect(title.style?.fontSize, expectedStyle.fontSize);
      expect(title.style?.fontWeight, expectedStyle.fontWeight);
    });
  });

  group('Root App Bar title', () {
    testWidgets('default state uses rootAppBarTitle (20sp / w600)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Root',
            titleVariant: SlAppBarTitleVariant.root,
            body: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('Root'));
      final expectedStyle = SurgeTypography.fromTextTheme(
        buildSlclashTextTheme(),
      ).rootAppBarTitle;
      expect(title.style?.fontSize, expectedStyle.fontSize);
      expect(title.style?.fontWeight, expectedStyle.fontWeight);
    });

    testWidgets('search state switches to appBarTitle (19sp / w500)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Root',
            titleVariant: SlAppBarTitleVariant.root,
            body: const SizedBox(),
            searchState: AppBarSearchState(
              query: '',
              onSearch: (_) {},
              autoAddSearch: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search should show TextField with appBarTitle style
      final textField = tester.widget<TextField>(find.byType(TextField));
      final expectedStyle = SurgeTypography.fromTextTheme(
        buildSlclashTextTheme(),
      ).appBarTitle;
      expect(textField.style?.fontSize, expectedStyle.fontSize);
      expect(textField.style?.fontWeight, expectedStyle.fontWeight);
    });

    testWidgets('edit state switches to appBarTitle (19sp / w500)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Root',
            titleVariant: SlAppBarTitleVariant.root,
            body: const SizedBox(),
            editState: AppBarEditState(editCount: 1, onExit: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Edit state shows selected count with appBarTitle style
      final titleFinder = find.byType(Text);
      final title = tester.widget<Text>(titleFinder.last);
      final expectedStyle = SurgeTypography.fromTextTheme(
        buildSlclashTextTheme(),
      ).appBarTitle;
      expect(title.style?.fontSize, expectedStyle.fontSize);
      expect(title.style?.fontWeight, expectedStyle.fontWeight);
    });
  });

  group('Sheet title', () {
    testWidgets('bottom sheet uses sheetTitle (18sp / w500)', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Bottom Sheet',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
          sheetType: SheetType.bottomSheet,
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final titleStyle = appBar.titleTextStyle;
      final expectedStyle = SurgeTypography.fromTextTheme(
        buildSlclashTextTheme(),
      ).sheetTitle;
      expect(titleStyle?.fontSize, expectedStyle.fontSize);
      expect(titleStyle?.fontWeight, expectedStyle.fontWeight);
    });

    testWidgets('side sheet uses sheetTitle (18sp / w500)', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Side Sheet',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
          sheetType: SheetType.sideSheet,
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final titleStyle = appBar.titleTextStyle;
      final expectedStyle = SurgeTypography.fromTextTheme(
        buildSlclashTextTheme(),
      ).sheetTitle;
      expect(titleStyle?.fontSize, expectedStyle.fontSize);
      expect(titleStyle?.fontWeight, expectedStyle.fontWeight);
    });

    testWidgets('page sheet uses sheetTitle (18sp / w500)', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Page Sheet',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
          sheetType: SheetType.page,
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final titleStyle = appBar.titleTextStyle;
      final expectedStyle = SurgeTypography.fromTextTheme(
        buildSlclashTextTheme(),
      ).sheetTitle;
      expect(titleStyle?.fontSize, expectedStyle.fontSize);
      expect(titleStyle?.fontWeight, expectedStyle.fontWeight);
    });
  });
}
