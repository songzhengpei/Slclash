import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_action.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_buttons.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/sheet.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _sheetApp(
  Widget child, {
  SheetType sheetType = SheetType.page,
  SurgeTheme? surge,
}) {
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
      extensions: [surge ?? SurgeTheme.light(), typography],
    ),
    home: SheetProvider(
      type: sheetType,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AdaptiveSheetScaffold legacy path', () {
    testWidgets('legacy actions render with SoftOsActionDock', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Legacy',
            body: const SizedBox(height: 200),
            actions: [
              IconButtonData(
                icon: SurgeIcons.refresh,
                onPressed: () {},
              ),
              IconButtonData(
                icon: SurgeIcons.settings,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.refresh), findsOneWidget);
      expect(find.byIcon(SurgeIcons.settings), findsOneWidget);
      expect(find.byType(SoftOsActionDock), findsOneWidget);
      expect(find.byType(SlAppBarActionsRenderer), findsNothing);
    });

    testWidgets('legacy single action renders SoftOsActionButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Legacy',
            body: const SizedBox(height: 200),
            actions: [
              IconButtonData(
                icon: SurgeIcons.search,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.search), findsOneWidget);
      expect(find.byType(SoftOsActionButton), findsWidgets);
      expect(find.byType(SlAppBarActionsRenderer), findsNothing);
    });
  });

  group('AdaptiveSheetScaffold semantic path', () {
    testWidgets('empty appBarActions shows leading and no trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Semantic',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
        ),
      );
      expect(find.byType(SlAppBarIconButton), findsOneWidget);
      expect(find.byType(SlAppBarActionsRenderer), findsNothing);
      expect(find.text('Semantic'), findsOneWidget);
    });

    testWidgets('icon action renders and triggers callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Icon Test',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarIconAction(
                icon: SurgeIcons.delete,
                tooltip: '删除',
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.delete), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.delete));
      expect(taps, 1);
      expect(find.byType(SoftOsActionDock), findsNothing);
    });

    testWidgets('text action renders with correct color', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Text Test',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarTextAction(
                label: '删除',
                tooltip: '删除',
                tone: SlAppBarActionTone.destructive,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('删除'), findsOneWidget);
      await tester.tap(find.text('删除'));
      expect(taps, 1);
    });

    testWidgets('overflow action opens popup', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Overflow',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarOverflowAction(
                tooltip: '更多',
                popup: const Card(child: Text('popup content')),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('popup content'), findsOneWidget);
    });

    testWidgets('leading button maintains 48dp inside sheet', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Size Test',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
        ),
      );
      final size = tester.getSize(find.byType(SlAppBarIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('title is centered between symmetric slots', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Centered',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
        ),
      );
      final titleCenter = tester.getCenter(find.text('Centered'));
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((titleCenter.dx - screenWidth / 2).abs(), lessThan(4));
    });

    testWidgets('title centered with right action', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Centered',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarIconAction(
                icon: SurgeIcons.delete,
                tooltip: '删除',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final titleCenter = tester.getCenter(find.text('Centered'));
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((titleCenter.dx - screenWidth / 2).abs(), lessThan(4));
    });

    testWidgets('title centered with text action', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Centered',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarTextAction(
                label: '删除',
                tooltip: '删除',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final titleCenter = tester.getCenter(find.text('Centered'));
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((titleCenter.dx - screenWidth / 2).abs(), lessThan(4));
    });

    testWidgets('does not use SoftOsActionDock', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'No Dock',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarIconAction(
                icon: SurgeIcons.delete,
                tooltip: '删除',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byType(SoftOsActionDock), findsNothing);
      expect(find.byType(SlAppBarActionsRenderer), findsOneWidget);
    });
  });

  group('AdaptiveSheetScaffold validation', () {
    test('throws FlutterError when both actions and appBarActions', () {
      expect(
        () => AdaptiveSheetScaffold(
          title: 'Test',
          body: const SizedBox(),
          actions: [
            IconButtonData(icon: SurgeIcons.search, onPressed: () {}),
          ],
          appBarActions: [
            const SlAppBarIconAction(
              icon: SurgeIcons.delete,
              tooltip: '删除',
            ),
          ],
        ),
        throwsAssertionError,
      );
    });

    test('throws FlutterError when appBarActions has more than one', () {
      expect(
        () => AdaptiveSheetScaffold(
          title: 'Test',
          body: const SizedBox(),
          appBarActions: [
            const SlAppBarIconAction(
              icon: SurgeIcons.delete,
              tooltip: '删除',
            ),
            const SlAppBarIconAction(
              icon: SurgeIcons.settings,
              tooltip: '设置',
            ),
          ],
        ),
        throwsAssertionError,
      );
    });
  });

  group('AdaptiveSheetScaffold bottom sheet', () {
    testWidgets('bottom sheet has drag handle and 48dp toolbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Bottom',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
          sheetType: SheetType.bottomSheet,
        ),
      );
      expect(find.text('Bottom'), findsOneWidget);
      expect(find.byType(SlAppBarIconButton), findsOneWidget);
    });
  });
}
