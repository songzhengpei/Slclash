import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all Material text slots match the frozen mapping', () {
    final theme = buildSlclashTextTheme();
    final cases = <(TextStyle?, double, double, FontWeight)>[
      (theme.displayLarge, 32, 1.25, FontWeight.w600),
      (theme.displayMedium, 28, 1.2857, FontWeight.w600),
      (theme.displaySmall, 24, 1.25, FontWeight.w600),
      (theme.headlineLarge, 24, 1.25, FontWeight.w600),
      (theme.headlineMedium, 19, 1.4737, FontWeight.w500),
      (theme.headlineSmall, 19, 1.4737, FontWeight.w500),
      (theme.titleLarge, 19, 1.3, FontWeight.w500),
      (theme.titleMedium, 16, 1.125, FontWeight.w500),
      (theme.titleSmall, 15, 1.4667, FontWeight.w500),
      (theme.bodyLarge, 15, 1.4667, FontWeight.w400),
      (theme.bodyMedium, 13, 1.2308, FontWeight.w400),
      (theme.bodySmall, 11, 1.4545, FontWeight.w400),
      (theme.labelLarge, 14, 1.4286, FontWeight.w600),
      (theme.labelMedium, 11, 1.0, FontWeight.w500),
      (theme.labelSmall, 11, 1.0, FontWeight.w500),
    ];

    expect(cases, hasLength(15));
    for (final (nullableStyle, size, height, weight) in cases) {
      final style = nullableStyle!;
      expect(style.fontSize, size);
      expect(style.height, closeTo(height, 0.00001));
      expect(style.fontWeight, weight);
      expect(style.fontFamily, isNull);
      expect(style.letterSpacing, 0);
      expect(style.color, isNull);
      expect(style.backgroundColor, isNull);
      expect(style.fontWeight, isNot(anyOf(FontWeight.w700, FontWeight.w800)));
    }
    expect(
      cases
          .map((entry) => entry.$1!.fontSize)
          .reduce((a, b) => a! < b! ? a : b),
      11,
    );
  });
}
