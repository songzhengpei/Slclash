import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [SurgeTheme.light()]),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('motion tokens keep the agreed interaction rhythm', () {
    expect(SurgeMotion.press, const Duration(milliseconds: 110));
    expect(SurgeMotion.state, const Duration(milliseconds: 160));
    expect(SurgeMotion.reveal, const Duration(milliseconds: 180));
    expect(SurgeMotion.container, const Duration(milliseconds: 220));
    expect(SurgeMotion.pageEnter, const Duration(milliseconds: 280));
    expect(SurgeMotion.pageExit, const Duration(milliseconds: 210));
    expect(SurgeMotion.sheetEnter, const Duration(milliseconds: 300));
    expect(SurgeMotion.sheetExit, const Duration(milliseconds: 200));
    expect(SurgeMotion.pressedScale, 0.98);
  });

  testWidgets('press feedback starts immediately and resets after cancel', (
    tester,
  ) async {
    await tester.pumpWidget(_app(SurgePressable(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: const SizedBox(width: 100, height: 48),
    )));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SurgePressable)),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.98);
    await gesture.cancel();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('disabled pressable neither animates nor invokes tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_app(SurgePressable(
      enabled: false,
      onTap: () => taps++,
      child: const SizedBox(width: 100, height: 48),
    )));
    await tester.tap(find.byType(SurgePressable));
    await tester.pump();
    expect(taps, 0);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('animated reveal preserves child while changing visibility', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SurgeAnimatedReveal(
      visible: false,
      child: Text('advanced option'),
    )));
    expect(find.text('advanced option'), findsNothing);
    await tester.pumpWidget(_app(const SurgeAnimatedReveal(
      visible: true,
      child: Text('advanced option'),
    )));
    await tester.pump(SurgeMotion.container);
    expect(find.text('advanced option'), findsOneWidget);
  });
}
