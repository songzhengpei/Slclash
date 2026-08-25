import 'dart:io';

import 'package:fl_clash/theme/static_theme.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Color> _roles(SurgeColors colors) => [
  colors.background,
  colors.card,
  colors.elevatedCard,
  colors.primary,
  colors.onPrimary,
  colors.green,
  colors.purple,
  colors.orange,
  colors.red,
  colors.textPrimary,
  colors.textSecondary,
  colors.separator,
  colors.fill,
  colors.selectedFill,
  colors.navBar,
  colors.navBorder,
  colors.shadow,
  colors.inactive,
  colors.inactiveVariant,
];

List<Color> _themeRoles(SurgeTheme theme) => [
  theme.background,
  theme.card,
  theme.elevatedCard,
  theme.primary,
  theme.onPrimary,
  theme.green,
  theme.purple,
  theme.orange,
  theme.red,
  theme.textPrimary,
  theme.textSecondary,
  theme.separator,
  theme.fill,
  theme.selectedFill,
  theme.navBar,
  theme.navBorder,
  theme.shadow,
  theme.inactive,
  theme.inactiveVariant,
];

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() >= b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void _expectContrast(Color foreground, Color background, double minimum) {
  expect(
    _contrast(foreground, background),
    greaterThanOrEqualTo(minimum),
    reason:
        '${foreground.toARGB32().toRadixString(16)} on '
        '${background.toARGB32().toRadixString(16)}',
  );
}

void main() {
  const expectedRoleValues = <List<int>>[
    [
      0xFFF2F3F7,
      0xFFFFFFFF,
      0xFFF8F9FC,
      0xFF0065CC,
      0xFFFFFFFF,
      0xFF237A3B,
      0xFF6551A3,
      0xFFA85B00,
      0xFFC9362B,
      0xFF1C1C1E,
      0xFF5F6368,
      0xFFD8DBE0,
      0xFFEDEFF3,
      0xFFE2EEFC,
      0xFFF8FBFF,
      0xFFD3D7DD,
      0x14000000,
      0xFF6B7078,
      0xFF8B9098,
    ],
    [
      0xFF08090B,
      0xFF17191D,
      0xFF202328,
      0xFF67B0FF,
      0xFF071521,
      0xFF51B969,
      0xFFB9A0E8,
      0xFFE49A41,
      0xFFFF6B61,
      0xFFF5F5F7,
      0xFFB7BDC4,
      0xFF34383E,
      0xFF292D32,
      0xFF35414D,
      0xFF17191D,
      0xFF363B42,
      0x66000000,
      0xFF7C8189,
      0xFF9EA3AB,
    ],
    [
      0xFFF9F9F7,
      0xFFFFFFFF,
      0xFFFCFCFA,
      0xFF74665A,
      0xFFFFFFFF,
      0xFF237A3B,
      0xFF6551A3,
      0xFFA85B00,
      0xFFC9362B,
      0xFF1F1F1D,
      0xFF656560,
      0xFFD6D5D0,
      0xFFF0EFEC,
      0xFFE4E3DE,
      0xFFFFFFFF,
      0xFFC8C7C1,
      0x18000000,
      0xFF6F6F6A,
      0xFF92928C,
    ],
    [
      0xFF151515,
      0xFF20201F,
      0xFF2B2B2A,
      0xFFB7A796,
      0xFF151515,
      0xFF51B969,
      0xFFB9A0E8,
      0xFFE49A41,
      0xFFFF6B61,
      0xFFF9F9F7,
      0xFFB7B7B2,
      0xFF454543,
      0xFF313131,
      0xFF3A3A39,
      0xFF20201F,
      0xFF4B4B48,
      0x8A000000,
      0xFF91918C,
      0xFFA6A6A0,
    ],
  ];

  test('four static specs freeze all 19 roles through one resolver', () {
    expect(StaticThemeSpec.values, hasLength(4));
    for (var index = 0; index < StaticThemeSpec.values.length; index++) {
      final spec = StaticThemeSpec.values[index];
      final roles = _roles(spec.colors);
      expect(roles, hasLength(19));
      expect(roles.map((color) => color.toARGB32()), expectedRoleValues[index]);
      expect(StaticThemeSpec.resolve(spec.preset, spec.brightness), same(spec));
      final theme = SurgeTheme.fromColors(
        spec.colors,
        stateColors: spec.stateColors,
      );
      expect(_themeRoles(theme), roles);
      expect(theme.semantic.state, same(spec.stateColors));
    }
  });

  test('static control states freeze four paired mappings', () {
    const expected = <List<int>>[
      [0xFF0065CC, 0xFFFFFFFF, 0xFF34C759, 0xFFFF9500, 0xFFFF3B30, 0xFF1C1C1E],
      [0xFF67B0FF, 0xFF071521, 0xFF30D158, 0xFFFF9F0A, 0xFFFF453A, 0xFF08090B],
      [0xFF74665A, 0xFFFFFFFF, 0xFF34C759, 0xFFFF9500, 0xFFFF3B30, 0xFF1F1F1D],
      [0xFFB7A796, 0xFF151515, 0xFF30D158, 0xFFFF9F0A, 0xFFFF453A, 0xFF151515],
    ];

    for (var index = 0; index < StaticThemeSpec.values.length; index++) {
      final state = StaticThemeSpec.values[index].stateColors;
      final values = [
        state.toggleActive,
        state.onToggleActive,
        state.heroStart,
        state.heroPause,
        state.heroStop,
        state.onHeroAction,
      ];
      expect(values.map((color) => color.toARGB32()), expected[index]);
      _expectContrast(state.onToggleActive, state.toggleActive, 4.5);
      for (final action in [state.heroStart, state.heroPause, state.heroStop]) {
        _expectContrast(state.onHeroAction, action, 4.5);
      }
    }
  });

  test(
    'blue-white large surfaces stay neutral while state roles carry blue',
    () {
      for (final spec in StaticThemeSpec.values.where(
        (spec) => spec.preset == StaticThemePreset.blueWhite,
      )) {
        final colors = spec.colors;
        for (final surface in [
          colors.background,
          colors.card,
          colors.elevatedCard,
          colors.fill,
          colors.navBar,
        ]) {
          final value = surface.toARGB32();
          final red = (value >> 16) & 0xFF;
          final green = (value >> 8) & 0xFF;
          final blue = value & 0xFF;
          final channels = [red, green, blue]..sort();
          expect(channels.last - channels.first, lessThanOrEqualTo(16));
        }
        expect(
          HSVColor.fromColor(colors.primary).saturation,
          greaterThan(0.45),
        );
      }
    },
  );

  test('light and dark surface roles stay distinct and ordered', () {
    for (final spec in StaticThemeSpec.values) {
      final colors = spec.colors;
      final surfaces = [
        colors.background,
        colors.card,
        colors.elevatedCard,
        colors.fill,
        colors.selectedFill,
      ];
      expect(surfaces.toSet(), hasLength(5));
      final luminance = surfaces
          .map((color) => color.computeLuminance())
          .toList();
      if (spec.brightness == Brightness.light) {
        expect(luminance[1], greaterThan(luminance[2]));
        expect(luminance[2], greaterThan(luminance[0]));
        expect(luminance[0], greaterThan(luminance[3]));
        expect(luminance[3], greaterThan(luminance[4]));
      } else {
        expect(luminance[4], greaterThan(luminance[3]));
        expect(luminance[3], greaterThan(luminance[2]));
        expect(luminance[2], greaterThan(luminance[1]));
        expect(luminance[1], greaterThan(luminance[0]));
      }
    }
  });

  test('ordinary text, accents, and semantic colors meet contrast targets', () {
    for (final spec in StaticThemeSpec.values) {
      final colors = spec.colors;
      final surfaces = [
        colors.background,
        colors.card,
        colors.elevatedCard,
        colors.fill,
        colors.selectedFill,
        colors.navBar,
      ];
      for (final surface in surfaces) {
        _expectContrast(colors.textPrimary, surface, 4.5);
        _expectContrast(colors.textSecondary, surface, 4.5);
        _expectContrast(colors.primary, surface, 3);
      }
      _expectContrast(colors.onPrimary, colors.primary, 4.5);
      for (final semantic in [
        colors.green,
        colors.purple,
        colors.orange,
        colors.red,
      ]) {
        _expectContrast(semantic, colors.card, 4.5);
      }
    }
  });

  test('gray-black surfaces stay neutral while primary matches controls', () {
    for (final spec in StaticThemeSpec.values.where(
      (spec) => spec.preset == StaticThemePreset.grayBlack,
    )) {
      final colors = spec.colors;
      final decorativeRoles = [
        colors.background,
        colors.card,
        colors.elevatedCard,
        colors.onPrimary,
        colors.textPrimary,
        colors.textSecondary,
        colors.separator,
        colors.fill,
        colors.selectedFill,
        colors.navBar,
        colors.navBorder,
        colors.shadow,
        colors.inactive,
        colors.inactiveVariant,
      ];
      for (final color in decorativeRoles) {
        expect(HSVColor.fromColor(color).saturation, lessThan(0.08));
        expect(color, isNot(const Color(0xFFD97757)));
      }
      expect(colors.primary, spec.stateColors.toggleActive);
      expect(HSVColor.fromColor(colors.primary).saturation, greaterThan(0.10));
    }
  });

  test('static ColorSchemes explicitly preserve the same semantic roles', () {
    for (final spec in StaticThemeSpec.values) {
      final colors = spec.colors;
      final scheme = spec.colorScheme;
      expect(scheme.brightness, spec.brightness);
      expect(scheme.primary, colors.primary);
      expect(scheme.onPrimary, colors.onPrimary);
      expect(scheme.surface, colors.card);
      expect(scheme.surfaceContainerLow, colors.elevatedCard);
      expect(scheme.surfaceContainer, colors.background);
      expect(scheme.surfaceContainerHigh, colors.fill);
      expect(scheme.surfaceContainerHighest, colors.selectedFill);
      expect(scheme.onSurface, colors.textPrimary);
      expect(scheme.onSurfaceVariant, colors.textSecondary);
      expect(scheme.outline, colors.separator);
      expect(scheme.error, colors.red);
    }
  });

  test('dynamic Surge mapping remains unchanged for all 19 roles', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );
    final colors = SurgeColors.fromColorScheme(scheme);
    expect(_themeRoles(SurgeTheme.fromColorScheme(scheme)), _roles(colors));
    expect(_roles(colors), [
      scheme.surface,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.primary,
      scheme.onPrimary,
      const Color(0xFF30D158),
      const Color(0xFFBF5AF2),
      const Color(0xFFFF9F0A),
      const Color(0xFFFF453A),
      scheme.onSurface,
      scheme.onSurfaceVariant,
      scheme.outlineVariant,
      scheme.surfaceContainerHighest,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainer.withValues(alpha: 0.92),
      scheme.outlineVariant.withValues(alpha: 0.36),
      Colors.black.withValues(alpha: 0.42),
      const Color(0xFF777A7F),
      const Color(0xFF9B9EA3),
    ]);
  });

  test('static presets never enter the seeded monochrome path', () {
    final staticSource = File('lib/theme/static_theme.dart').readAsStringSync();
    final applicationSource = File('lib/application.dart').readAsStringSync();
    final providerSource = File('lib/providers/state.dart').readAsStringSync();

    expect(staticSource, isNot(contains('ColorScheme.fromSeed')));
    expect(staticSource, isNot(contains('DynamicSchemeVariant.monochrome')));
    expect(applicationSource, contains('if (!themeProps.dynamicColor)'));
    expect(applicationSource, contains('StaticThemeSpec.resolve'));
    expect(
      applicationSource,
      isNot(contains('DynamicSchemeVariant.monochrome')),
    );
    expect(providerSource, contains('ColorScheme.fromSeed'));
    expect(providerSource, contains('normalizeDynamicSchemeVariant'));
    expect(providerSource, contains('DynamicSchemeVariant.monochrome'));
  });
}
