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
  double textScaleFactor = 1.0,
  Size surfaceSize = const Size(800, 600),
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
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: child!,
    ),
    home: SheetProvider(
      type: sheetType,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AdaptiveSheetScaffold legacy path', () {
    testWidgets('legacy actions render with SoftOsActionDock', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Legacy',
            body: const SizedBox(height: 200),
            actions: [
              IconButtonData(icon: SurgeIcons.refresh, onPressed: () {}),
              IconButtonData(icon: SurgeIcons.settings, onPressed: () {}),
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
              IconButtonData(icon: SurgeIcons.search, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.search), findsOneWidget);
      expect(find.byType(SlAppBarActionsRenderer), findsNothing);
    });
  });

  group('AdaptiveSheetScaffold semantic path', () {
    testWidgets('root page shows no leading button', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Root',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
        ),
      );
      expect(find.byType(SlAppBarIconButton), findsNothing);
      expect(find.text('Root'), findsOneWidget);
    });

    testWidgets('pushed page shows back button and pops', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: ThemeData(
            textTheme: buildSlclashTextTheme(),
            extensions: [
              SurgeTheme.light(),
              SurgeTypography.fromTextTheme(buildSlclashTextTheme()),
            ],
          ),
          home: const SizedBox(),
          routes: {
            '/detail': (_) => SheetProvider(
                  type: SheetType.page,
                  child: Scaffold(
                    body: AdaptiveSheetScaffold(
                      title: 'Detail',
                      body: const SizedBox(height: 200),
                      appBarActions: const [],
                    ),
                  ),
                ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/detail');
      await tester.pumpAndSettle();
      expect(find.byType(SlAppBarIconButton), findsOneWidget);
      await tester.tap(find.byType(SlAppBarIconButton));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
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

    testWidgets('text action renders and is clickable', (tester) async {
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

    testWidgets('leading button maintains 48dp', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Size',
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
      final size = tester.getSize(find.byType(SlAppBarIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('title centered with no trailing', (tester) async {
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
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((titleCenter.dx - screenWidth / 2).abs(), lessThan(4));
    });

    testWidgets('title centered with icon action', (tester) async {
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
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
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
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
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

    testWidgets('leading tooltip uses MaterialLocalizations', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: 'Tip',
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
      final button = tester.widget<SlAppBarIconButton>(
        find.byType(SlAppBarIconButton),
      );
      expect(button.tooltip, isNotEmpty);
      expect(button.tooltip, isNot(contains('back')));
      expect(button.tooltip, isNot(contains('Back')));
      expect(button.tooltip, isNot(contains('exit')));
      expect(button.tooltip, isNot(contains('Exit')));
    });
  });

  group('AdaptiveSheetScaffold responsive', () {
    testWidgets('320dp width no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: '窄屏标题测试',
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
      expect(tester.takeException(), isNull);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('360dp width no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: '中等宽度标题',
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
      expect(tester.takeException(), isNull);
    });

    testWidgets('384dp width no overflow', (tester) async {
      tester.view.physicalSize = const Size(384, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: '标准宽度标题测试',
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
      expect(tester.takeException(), isNull);
    });
  });

  group('AdaptiveSheetScaffold font scale', () {
    testWidgets('scale 1.0 no overflow', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: '字体缩放',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarTextAction(
                label: '删除',
                tooltip: '删除',
                onPressed: () {},
              ),
            ],
          ),
          textScaleFactor: 1.0,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('scale 1.3 no overflow', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: '字体缩放',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarTextAction(
                label: '删除',
                tooltip: '删除',
                onPressed: () {},
              ),
            ],
          ),
          textScaleFactor: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('scale 2.0 text action overflows — known issue', (
      tester,
    ) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: '字体缩放',
            body: const SizedBox(height: 200),
            appBarActions: [
              SlAppBarTextAction(
                label: '删除',
                tooltip: '删除',
                onPressed: () {},
              ),
            ],
          ),
          textScaleFactor: 2.0,
        ),
      );
      expect(find.text('删除'), findsOneWidget);
      final exception = tester.takeException();
      expect(exception, isA<FlutterError>());
      expect(
        (exception as FlutterError).message,
        contains('overflowed'),
      );
    });

    testWidgets('scale 2.0 title still single line ellipsis', (tester) async {
      await tester.pumpWidget(
        _sheetApp(
          AdaptiveSheetScaffold(
            title: '这是一个很长的标题用于测试省略号',
            body: const SizedBox(height: 200),
            appBarActions: const [],
          ),
          textScaleFactor: 2.0,
        ),
      );
      expect(tester.takeException(), isNull);
      final textWidget = tester.widget<Text>(
        find.text('这是一个很长的标题用于测试省略号'),
      );
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
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
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 48);
    });
  });

  group('AdaptiveSheetScaffold runtime validation', () {
    testWidgets(
      'throws FlutterError when both actions and appBarActions',
      (tester) async {
        await tester.pumpWidget(
          _sheetApp(
            AdaptiveSheetScaffold(
              title: 'Test',
              body: const SizedBox(height: 200),
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
          ),
        );
        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            contains('cannot use both'),
          ),
        );
      },
    );

    testWidgets(
      'throws FlutterError when appBarActions has more than one',
      (tester) async {
        await tester.pumpWidget(
          _sheetApp(
            AdaptiveSheetScaffold(
              title: 'Test',
              body: const SizedBox(height: 200),
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
          ),
        );
        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            contains('at most one'),
          ),
        );
      },
    );
  });
}
