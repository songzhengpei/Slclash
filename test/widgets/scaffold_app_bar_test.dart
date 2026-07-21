import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_action.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_buttons.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {SurgeTheme? surge}) {
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
    home: child,
  );
}

void main() {
  group('CommonScaffold with appBarActions', () {
    testWidgets('renders single icon action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            appBarActions: [
              SlAppBarIconAction(
                icon: SurgeIcons.refresh,
                tooltip: '刷新',
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.refresh), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.refresh));
      expect(taps, 1);
    });

    testWidgets('renders two independent actions without SoftOsActionDock', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            appBarActions: [
              SlAppBarIconAction(
                icon: SurgeIcons.search,
                tooltip: '搜索',
                onPressed: () {},
              ),
              SlAppBarOverflowAction(
                tooltip: '更多',
                popup: const Card(child: Text('menu')),
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.search), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      expect(find.byType(SoftOsActionDock), findsNothing);
    });

    testWidgets('renders text action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            appBarActions: [
              SlAppBarTextAction(
                label: '保存',
                tooltip: '保存',
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('保存'), findsOneWidget);
      await tester.tap(find.text('保存'));
      expect(taps, 1);
    });

    testWidgets('renders overflow action with popup', (tester) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
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
  });

  group('CommonScaffold leading button', () {
    testWidgets('no leading button on root route without edit/search', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
          ),
        ),
      );
      expect(find.byType(SlAppBarIconButton), findsNothing);
    });

    testWidgets('leading button maintains 48dp inside AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            appBarActions: [
              SlAppBarIconAction(
                icon: SurgeIcons.refresh,
                tooltip: '刷新',
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
  });

  group('CommonScaffold legacy actions', () {
    testWidgets('legacy actions still render', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            actions: [
              IconButton(
                icon: const Icon(SurgeIcons.settings),
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.settings), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.settings));
      expect(taps, 1);
    });

    testWidgets('legacy auto-add search button works', (tester) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            searchState: AppBarSearchState(
              onSearch: (_) {},
              autoAddSearch: true,
            ),
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.search), findsOneWidget);
    });

    testWidgets('legacy double actions preserve SoftOsActionDock', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            actions: [
              IconButton(
                icon: const Icon(SurgeIcons.refresh),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(SurgeIcons.settings),
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byType(SoftOsActionDock), findsOneWidget);
    });
  });

  group('CommonScaffold assert', () {
    test('throws when both appBarActions and actions provided', () {
      expect(
        () => CommonScaffold(
          title: 'Test',
          body: const SizedBox(),
          appBarActions: [
            const SlAppBarIconAction(
              icon: SurgeIcons.search,
              tooltip: '搜索',
            ),
          ],
          actions: [const SizedBox()],
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'throws FlutterError when auto-search plus two page actions',
      (tester) async {
        await tester.pumpWidget(
          _app(
            CommonScaffold(
              title: 'Test',
              body: const SizedBox(),
              searchState: AppBarSearchState(
                onSearch: (_) {},
                autoAddSearch: true,
              ),
              appBarActions: [
                SlAppBarIconAction(
                  icon: SurgeIcons.refresh,
                  tooltip: '刷新',
                  onPressed: () {},
                ),
                SlAppBarIconAction(
                  icon: SurgeIcons.settings,
                  tooltip: '设置',
                  onPressed: () {},
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
            contains('at most 2'),
          ),
        );
      },
    );
  });
}
