import 'dart:io';
import 'dart:ui' show Tristate;
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme(SurgeTheme surge) => ThemeData(extensions: [surge]);

Widget _host(Widget child, {SurgeTheme? surge}) {
  return MaterialApp(
    theme: _theme(surge ?? SurgeTheme.light()),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('SurgeTheme semantic tokens', () {
    test('retain the established dashboard palette in the light theme', () {
      final surge = SurgeTheme.light();

      expect(surge.semantic.dashboardDynamicActive, const Color(0xFFA06B3B));
      expect(surge.semantic.dashboardActiveGreen, const Color(0xFF5BA66A));
      expect(surge.semantic.paused, const Color(0xFFDC851B));
      expect(surge.semantic.latencyGood, const Color(0xFFADDFAD));
      expect(surge.semantic.latencyMedium, const Color(0xFFF1C892));
      expect(surge.semantic.latencyBad, const Color(0xFFFFBBBD));
      expect(surge.typography.dashboardMicro.fontSize, 8);
      expect(surge.typography.dashboardTiny.fontSize, 10);
      expect(surge.typography.dashboardValue.fontSize, 12);
      expect(surge.typography.dashboardValue.fontWeight, FontWeight.w700);
      expect(surge.typography.dashboardLabel.fontWeight, FontWeight.w500);
      expect(surge.typography.dashboardLoading.fontSize, 10);
      expect(surge.typography.fieldInput.fontSize, 14);
      expect(surge.typography.fieldHint.color, surge.textSecondary);
      expect(surge.typography.emptyState.color, surge.textSecondary);
      expect(surge.controls.minimumTapExtent, 44);
      expect(surge.opacity.selectedSurface, 0.045);
      expect(surge.radii.menuRow, 12);
      expect(surge.radii.input, 10);
      expect(surge.radii.metric, 10);
      expect(surge.radii.chart, 4);
    });

    testWidgets('text compatibility facade reads the active theme', (
      tester,
    ) async {
      late TextStyle style;
      final surge = SurgeTheme.dark();

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: _theme(surge),
            child: Builder(
              builder: (context) {
                style = SurgeTextStyles.title(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(style.color, surge.textPrimary);
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('retain dark and dynamic-color mappings without changing tokens', () {
      final dark = SurgeTheme.dark();
      final dynamicScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      );
      final dynamic = SurgeTheme.fromColorScheme(dynamicScheme);

      expect(dark.background, const Color(0xFF08090B));
      expect(dark.primary, const Color(0xFF4DA3FF));
      expect(dark.typography.title.color, dark.textPrimary);
      expect(dynamic.background, dynamicScheme.surface);
      expect(dynamic.card, dynamicScheme.surfaceContainerLow);
      expect(dynamic.primary, dynamicScheme.primary);
      expect(dynamic.textPrimary, dynamicScheme.onSurface);
      expect(dynamic.semantic.error, const Color(0xFFFF453A));
      expect(dynamic.controls.minimumTapExtent, 44);
      expect(SurgeMotion.press, const Duration(milliseconds: 110));
      expect(SurgeMotion.container, const Duration(milliseconds: 220));
    });
  });

  group('Surge reusable controls', () {
    testWidgets('selectable rows preserve selected semantics and callbacks', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 280,
            child: SurgeSelectableRow(
              selected: true,
              presentation: SurgeSelectionPresentation.list,
              onTap: () => taps += 1,
              child: const SizedBox(
                height: 44,
                child: Center(child: Text('节点 A')),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(SurgeSelectableRow)).height, 44);
      final semanticsData = tester
          .getSemantics(find.byType(SurgeSelectableRow))
          .getSemanticsData();
      expect(semanticsData.label, '节点 A');
      expect(semanticsData.flagsCollection.isButton, isTrue);
      expect(semanticsData.flagsCollection.isSelected, Tristate.isTrue);
      expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.text('节点 A'));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('dual selector preserves its targets and disabled state', (
      tester,
    ) async {
      var secondTaps = 0;

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: SurgeDualSelectBar(
              firstLabel: '规则模式',
              secondLabel: '当前节点',
              onFirstTap: null,
              onSecondTap: () => secondTaps += 1,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              radius: 22,
              itemRadius: 18,
              dividerHeight: 20,
              dividerMargin: 4,
              labelStyle: SurgeTheme.light().typography.rowTitle,
              iconSize: 16,
              labelGap: 4,
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(SurgeDualSelectBar)).height, 44);
      await tester.tap(find.text('规则模式'));
      await tester.tap(find.text('当前节点'));
      expect(secondTaps, 1);
    });

    testWidgets(
      'status pill publishes its label and blocks taps while loading',
      (tester) async {
        var taps = 0;

        await tester.pumpWidget(
          _host(
            SoftOsStatusPill(
              accentColor: SurgeTheme.light().primary,
              loading: true,
              semanticLabel: '同步状态',
              onPressed: () => taps += 1,
              child: const Text('正在切换'),
            ),
          ),
        );

        expect(find.bySemanticsLabel(RegExp('同步状态')), findsOneWidget);
        await tester.tap(find.text('正在切换'));
        expect(taps, 0);

        await tester.pumpWidget(
          _host(
            SoftOsStatusPill(
              accentColor: SurgeTheme.light().primary,
              semanticLabel: '同步状态',
              onPressed: () => taps += 1,
              child: const Text('已就绪'),
            ),
          ),
        );
        await tester.tap(find.text('已就绪'));
        expect(taps, 1);
      },
    );

    testWidgets('delay pill retains test, loading, value, and timeout states', (
      tester,
    ) async {
      var taps = 0;

      Future<void> pumpDelay(int? delay) {
        return tester.pumpWidget(
          _host(SurgeDelayPill(delay: delay, onTap: () => taps += 1)),
        );
      }

      await pumpDelay(null);
      expect(find.text('Test'), findsOneWidget);
      await tester.tap(find.byType(SurgeDelayPill));
      expect(taps, 1);

      await pumpDelay(0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpDelay(124);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('124 ms'), findsOneWidget);

      await pumpDelay(-1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Timeout'), findsOneWidget);
    });

    testWidgets('sliding segmented control reports the selected item', (
      tester,
    ) async {
      var selected = 'rule';
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(SurgeTheme.light()),
          themeMode: ThemeMode.light,
          home: StatefulBuilder(
            builder: (context, setState) {
              final surge = SurgeTheme.of(context);
              return SurgeSlidingSegmentedControl<String>(
                value: selected,
                items: const [
                  SurgeSegmentedItem(value: 'rule', label: '规则'),
                  SurgeSegmentedItem(value: 'global', label: '全局'),
                ],
                onChanged: (value) => setState(() => selected = value),
                height: 34,
                padding: const EdgeInsets.all(3),
                backgroundColor: surge.fill,
                selectedSurfaceColor: surge.elevatedCard,
                selectedColor: surge.primary,
                unselectedColor: surge.textSecondary,
                outerRadius: 26,
                selectedRadius: 24,
                labelStyle: surge.typography.rowTitle,
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('全局'));
      await tester.pumpAndSettle();
      expect(selected, 'global');
    });
  });

  test(
    'design-system source contract keeps icons and dashboard palette central',
    () {
      final sourceFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final directIcons = RegExp(r'(?<!Surge)Icons\.');

      for (final file in sourceFiles) {
        if (file.path.replaceAll('\\', '/').endsWith('/common/icons.dart')) {
          continue;
        }
        expect(
          directIcons.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: '${file.path} must use SurgeIcons',
        );
      }

      expect(
        File('lib/views/dashboard/widgets/dashboard_palette.dart').existsSync(),
        isFalse,
      );
      final dashboard = File(
        'lib/views/dashboard/widgets/surge_dashboard_hero.dart',
      ).readAsStringSync();
      expect(dashboard.contains('dashboard_palette'), isFalse);

      final themeSource = File(
        'lib/widgets/surge/surge_theme_extension.dart',
      ).readAsStringSync();
      final compatibilityFacade = themeSource.substring(
        themeSource.indexOf('class SurgeTextStyles'),
      );
      expect(compatibilityFacade, isNot(contains('SurgeColors.light')));
    },
  );
}
