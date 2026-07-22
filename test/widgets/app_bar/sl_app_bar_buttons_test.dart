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
  group('SlAppBarIconButton', () {
    testWidgets('triggers onPressed when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(SlAppBarIconButton));
      expect(taps, 1);
    });

    testWidgets('does not trigger onPressed when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
            enabled: false,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(SlAppBarIconButton));
      expect(taps, 0);
    });

    testWidgets('does not trigger onPressed when onPressed is null', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
            onPressed: null,
          ),
        ),
      );
      await tester.tap(find.byType(SlAppBarIconButton));
      expect(taps, 0);
    });

    testWidgets('displays tooltip', (tester) async {
      await tester.pumpWidget(
        _app(
          const SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == '搜索',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has 48dp tap target', (tester) async {
      await tester.pumpWidget(
        _app(
          const SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
          ),
        ),
      );
      final size = tester.getSize(find.byType(SlAppBarIconButton));
      expect(size, const Size(48, 48));
    });

    testWidgets('icon visual size is 24dp', (tester) async {
      await tester.pumpWidget(
        _app(
          const SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(SlAppBarIconButton),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.size, 24);
    });

    testWidgets('semantics disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
            onPressed: null,
          ),
        ),
      );
      // Button should not be tappable when onPressed is null
      final finder = find.byType(SlAppBarIconButton);
      expect(finder, findsOneWidget);
      // The IconButton inside should have onPressed: null
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('semantics disabled when enabled is false', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
            enabled: false,
            onPressed: () {},
          ),
        ),
      );
      // The IconButton inside should have onPressed: null when disabled
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('uses onSurfaceVariant for normal tone', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
            tone: SlAppBarActionTone.normal,
            onPressed: () {},
          ),
        ),
      );
      final context = tester.element(find.byType(SlAppBarIconButton));
      final colorScheme = Theme.of(context).colorScheme;
      final iconButton = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(iconButton.color, colorScheme.onSurfaceVariant);
    });

    testWidgets('uses primary color for primary tone', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.search,
            tooltip: '搜索',
            tone: SlAppBarActionTone.primary,
            onPressed: () {},
          ),
        ),
      );
      final context = tester.element(find.byType(SlAppBarIconButton));
      final colorScheme = Theme.of(context).colorScheme;
      final iconButton = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(iconButton.color, colorScheme.primary);
    });

    testWidgets('uses error color for destructive tone', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarIconButton(
            icon: SurgeIcons.delete,
            tooltip: '删除',
            tone: SlAppBarActionTone.destructive,
            onPressed: () {},
          ),
        ),
      );
      final context = tester.element(find.byType(SlAppBarIconButton));
      final colorScheme = Theme.of(context).colorScheme;
      final iconButton = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(iconButton.color, colorScheme.error);
    });
  });

  group('SlAppBarTextButton', () {
    testWidgets('triggers onPressed when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SlAppBarTextButton(
            label: '保存',
            tooltip: '保存',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('保存'));
      expect(taps, 1);
    });

    testWidgets('does not trigger onPressed when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SlAppBarTextButton(
            label: '保存',
            tooltip: '保存',
            enabled: false,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('保存'));
      expect(taps, 0);
    });

    testWidgets('has minimum 48dp height', (tester) async {
      await tester.pumpWidget(
        _app(
          const SlAppBarTextButton(
            label: '保存',
            tooltip: '保存',
          ),
        ),
      );
      final size = tester.getSize(find.byType(SlAppBarTextButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('displays tooltip', (tester) async {
      await tester.pumpWidget(
        _app(
          const SlAppBarTextButton(
            label: '保存',
            tooltip: '保存更改',
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == '保存更改',
        ),
        findsOneWidget,
      );
    });
  });

  group('SlAppBarOverflowButton', () {
    testWidgets('opens popup on tap when enabled', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarOverflowButton(
            tooltip: '更多',
            popup: const Card(child: Text('menu items')),
          ),
        ),
      );
      await tester.tap(find.byType(SlAppBarOverflowButton));
      await tester.pumpAndSettle();
      expect(find.text('menu items'), findsOneWidget);
    });

    testWidgets('does not open popup when disabled', (tester) async {
      await tester.pumpWidget(
        _app(
          const SlAppBarOverflowButton(
            tooltip: '更多',
            enabled: false,
            popup: Card(child: Text('menu items')),
          ),
        ),
      );
      await tester.tap(find.byType(SlAppBarOverflowButton));
      await tester.pumpAndSettle();
      expect(find.text('menu items'), findsNothing);
    });

    testWidgets('disposes without exception', (tester) async {
      await tester.pumpWidget(
        _app(
          SlAppBarOverflowButton(
            tooltip: '更多',
            popup: const Card(child: Text('menu items')),
          ),
        ),
      );
      await tester.pumpWidget(_app(const SizedBox()));
    });
  });
}
