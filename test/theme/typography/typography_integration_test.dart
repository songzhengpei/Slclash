import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/theme/typography/surge_typography.dart';
import 'package:fl_clash/widgets/surge/surge_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme(Brightness brightness) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  final surge = brightness == Brightness.light
      ? SurgeTheme.light()
      : SurgeTheme.dark();
  return ThemeData(
    brightness: brightness,
    textTheme: textTheme,
    extensions: [surge, typography],
  );
}

void main() {
  testWidgets('semantic typography is exposed independently from color theme', (
    tester,
  ) async {
    late TextTheme textTheme;
    late SurgeTypography current;
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: Builder(
          builder: (context) {
            textTheme = Theme.of(context).textTheme;
            current = context.typography;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(current.appBarTitle.fontSize, textTheme.titleLarge!.fontSize);
    expect(current.appBarTitle.height, textTheme.titleLarge!.height);
    expect(current.appBarTitle.fontWeight, textTheme.titleLarge!.fontWeight);
    expect(current.technical.fontFamily, isNotNull);
    expect(SurgeTheme.light(), isA<SurgeTheme>());
  });

  test('light and dark themes use identical color-free typography', () {
    final light = _theme(Brightness.light).extension<SurgeTypography>()!;
    final dark = _theme(Brightness.dark).extension<SurgeTypography>()!;
    expect(light.screenTitle, dark.screenTitle);
    expect(light.chartLabel, dark.chartLabel);
    expect(light.screenTitle.color, isNull);
    expect(light.technical.color, isNull);
  });
}
