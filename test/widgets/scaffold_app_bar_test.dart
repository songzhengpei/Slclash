import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_action.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_buttons.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {SurgeTheme? surge, Map<String, WidgetBuilder>? routes}) {
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
    home: home,
    routes: routes ?? {},
  );
}

void _initGlobalState() {
  globalState.container = ProviderContainer();
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
    testWidgets('no leading button on root route', (tester) async {
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

    testWidgets('back button appears on nested route and pops', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(),
          routes: {
            '/detail': (_) => const CommonScaffold(
                  title: 'Detail',
                  body: SizedBox(),
                ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/detail');
      await tester.pumpAndSettle();

      final backButton = find.byWidgetPredicate(
        (w) => w is SlAppBarIconButton && w.icon == SurgeIcons.back,
      );
      expect(backButton, findsOneWidget);

      final size = tester.getSize(backButton);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
    });

    testWidgets('leading tooltip is localized', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(),
          routes: {
            '/detail': (_) => const CommonScaffold(
                  title: 'Detail',
                  body: SizedBox(),
                ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/detail');
      await tester.pumpAndSettle();

      final backButton = find.byWidgetPredicate(
        (w) => w is SlAppBarIconButton && w.icon == SurgeIcons.back,
      );
      expect(backButton, findsOneWidget);
      final button = tester.widget<SlAppBarIconButton>(backButton);
      expect(button.tooltip, isNotEmpty);
      expect(button.tooltip, isNot(contains('back')));
      expect(button.tooltip, isNot(contains('Back')));
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

  group('CommonScaffold validation', () {
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

  group('CommonScaffold search state', () {
    setUp(_initGlobalState);

    testWidgets('search leading exits search mode', (tester) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            searchState: AppBarSearchState(
              query: 'test',
              onSearch: (_) {},
              autoAddSearch: true,
            ),
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.back), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.back));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('search trailing clears non-empty query without exiting', (
      tester,
    ) async {
      String lastQuery = '';
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            searchState: AppBarSearchState(
              query: '',
              onSearch: (value) => lastQuery = value,
              autoAddSearch: true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(find.byIcon(SurgeIcons.close), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.close));
      await tester.pump();
      expect(lastQuery, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search trailing exits when query is empty', (tester) async {
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            searchState: AppBarSearchState(
              query: '',
              onSearch: (_) {},
              autoAddSearch: true,
            ),
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.close), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.close));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('CommonScaffold edit state', () {
    setUp(_initGlobalState);

    testWidgets('edit leading invokes onExit', (tester) async {
      var exited = false;
      await tester.pumpWidget(
        _app(
          CommonScaffold(
            title: 'Test',
            body: const SizedBox(),
            editState: AppBarEditState(
              editCount: 1,
              onExit: () => exited = true,
            ),
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.close), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.close));
      await tester.pump();
      expect(exited, isTrue);
    });
  });
}
