import 'package:fl_clash/widgets/app_bar/sl_app_bar.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_action.dart';
import 'package:fl_clash/widgets/app_bar/sl_app_bar_buttons.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return MaterialApp(
    theme: ThemeData(
      textTheme: textTheme,
      extensions: [SurgeTheme.light(), typography],
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('SlAppBarActionsRenderer', () {
    testWidgets('renders empty for empty actions list', (tester) async {
      await tester.pumpWidget(
        _app(const SlAppBarActionsRenderer(actions: [])),
      );
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders single icon action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SlAppBarActionsRenderer(
            actions: [
              SlAppBarIconAction(
                icon: SurgeIcons.search,
                tooltip: '搜索',
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(SlAppBarIconButton), findsOneWidget);
      expect(find.byIcon(SurgeIcons.search), findsOneWidget);
      await tester.tap(find.byType(SlAppBarIconButton));
      expect(taps, 1);
    });

    testWidgets('renders two independent actions side by side', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarActionsRenderer(
            actions: [
              SlAppBarIconAction(
                icon: SurgeIcons.search,
                tooltip: '搜索',
                onPressed: () {},
              ),
              SlAppBarOverflowAction(
                tooltip: '更多',
                popup: Card(child: Text('menu')),
                enabled: true,
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(SurgeIcons.search), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      expect(find.byType(SlAppBarOverflowButton), findsOneWidget);
    });

    testWidgets('renders action group as grouped buttons', (tester) async {
      var listTaps = 0;
      var gridTaps = 0;
      await tester.pumpWidget(
        _app(
          SlAppBarActionsRenderer(
            actions: [
              SlAppBarActionGroup(
                actions: [
                  SlAppBarIconAction(
                    icon: SurgeIcons.list,
                    tooltip: '列表视图',
                    onPressed: () => listTaps++,
                  ),
                  SlAppBarIconAction(
                    icon: SurgeIcons.apps,
                    tooltip: '网格视图',
                    onPressed: () => gridTaps++,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.byType(SlAppBarIconButton), findsNWidgets(2));
      expect(find.byIcon(SurgeIcons.list), findsOneWidget);
      expect(find.byIcon(SurgeIcons.apps), findsOneWidget);
      await tester.tap(find.byIcon(SurgeIcons.list));
      expect(listTaps, 1);
      await tester.tap(find.byIcon(SurgeIcons.apps));
      expect(gridTaps, 1);
    });

    testWidgets('does not render SoftOsActionDock for non-group actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SlAppBarActionsRenderer(
            actions: [
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
      expect(find.byType(SoftOsActionDock), findsNothing);
    });
  });
}
