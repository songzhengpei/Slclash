import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/dashboard/widgets/surge_dashboard_hero.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _blue = Color(0xFF1565C0);
const _paused = Color(0xFFFFC107);
const _fillKey = ValueKey('hero-active-fill-box');

Widget _app(Color fill) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return MaterialApp(
    theme: ThemeData(
      textTheme: textTheme,
      extensions: [SurgeTheme.light(), typography],
    ),
    home: Scaffold(
      body: HeroActiveFill(
        activeFill: fill,
        builder: (context, color, child) {
          return ColoredBox(
            key: _fillKey,
            color: color,
            child: child,
          );
        },
        child: const SizedBox(width: 24, height: 24),
      ),
    ),
  );
}

HeroActiveFillState _state(WidgetTester tester) {
  return tester.state<HeroActiveFillState>(find.byType(HeroActiveFill));
}

Color _fillColor(WidgetTester tester) {
  return tester.widget<ColoredBox>(find.byKey(_fillKey)).color;
}

void main() {
  testWidgets('first mount does not start a fill ticker', (tester) async {
    await tester.pumpWidget(_app(_blue));
    expect(_state(tester).debugIsAnimating, isFalse);
    expect(_fillColor(tester), _blue);
  });

  testWidgets('same color rebuild does not start a fill ticker', (tester) async {
    await tester.pumpWidget(_app(_blue));
    await tester.pumpWidget(_app(_blue));
    expect(_state(tester).debugIsAnimating, isFalse);
    expect(_fillColor(tester), _blue);
  });

  testWidgets('real active to paused fill animates then exits', (tester) async {
    await tester.pumpWidget(_app(_blue));
    expect(_state(tester).debugIsAnimating, isFalse);

    await tester.pumpWidget(_app(_paused));
    await tester.pump();
    expect(_state(tester).debugIsAnimating, isTrue);
    expect(_fillColor(tester), isNot(_paused));

    await tester.pump(SurgeMotion.heroFill + const Duration(milliseconds: 100));
    expect(_state(tester).debugIsAnimating, isFalse);
    expect(_fillColor(tester), _paused);

    await tester.pumpWidget(_app(_paused));
    expect(_state(tester).debugIsAnimating, isFalse);
  });

  testWidgets('rapid reverse retargets without overlapping tickers', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_blue));
    await tester.pumpWidget(_app(_paused));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_state(tester).debugIsAnimating, isTrue);

    await tester.pumpWidget(_app(_blue));
    await tester.pump();
    expect(_state(tester).debugIsAnimating, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pump(SurgeMotion.heroFill + const Duration(milliseconds: 100));
    expect(_state(tester).debugIsAnimating, isFalse);
    expect(_fillColor(tester), _blue);
  });
}
