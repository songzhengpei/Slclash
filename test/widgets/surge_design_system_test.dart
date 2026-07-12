import 'dart:io';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme(SurgeTheme surge) => ThemeData(extensions: [surge]);

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
      expect(surge.controls.minimumTapExtent, 44);
      expect(surge.opacity.selectedSurface, 0.045);
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
  });

  group('Surge reusable controls', () {
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
    },
  );
}
