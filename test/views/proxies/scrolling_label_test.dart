import 'package:fl_clash/views/proxies/scrolling_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required Widget child, bool disableAnimations = false}) {
  return MaterialApp(
    builder: (context, appChild) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(disableAnimations: disableAnimations),
        child: appChild!,
      );
    },
    home: Scaffold(body: child),
  );
}

Widget _label(
  ProxyLabelPlaybackCoordinator coordinator, {
  required String text,
  required Object replayToken,
}) {
  return SizedBox(
    width: 90,
    child: ScrollingProxyLabel(
      text: text,
      style: const TextStyle(fontSize: 14),
      coordinator: coordinator,
      replayToken: replayToken,
    ),
  );
}

Future<void> _finishPlayback(WidgetTester tester) async {
  // Advance each async phase separately. A single large pump can start the
  // next Future at the end of that pump rather than consuming its duration.
  for (var phase = 0; phase < 5; phase++) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
  }
}

void main() {
  testWidgets('short labels stay static and never claim playback', (
    tester,
  ) async {
    final coordinator = ProxyLabelPlaybackCoordinator()..setPageActive(true);
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      _app(child: _label(coordinator, text: 'HK 01', replayToken: false)),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey('scrolling-proxy-label-active')),
      findsNothing,
    );
    expect(coordinator.hasActivePlayback, isFalse);
  });

  testWidgets('only the first overflowing label autoplays and then stops', (
    tester,
  ) async {
    final coordinator = ProxyLabelPlaybackCoordinator()..setPageActive(true);
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      _app(
        child: Column(
          children: [
            _label(
              coordinator,
              text: 'Hong Kong premium streaming node number one',
              replayToken: false,
            ),
            _label(
              coordinator,
              text: 'Singapore premium streaming node number two',
              replayToken: false,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('scrolling-proxy-label-active')),
      findsOneWidget,
    );
    expect(coordinator.hasActivePlayback, isTrue);

    await _finishPlayback(tester);

    expect(
      find.byKey(const ValueKey('scrolling-proxy-label-active')),
      findsNothing,
    );
    expect(coordinator.hasActivePlayback, isFalse);
  });

  testWidgets('changing expansion token replays an overflowing label', (
    tester,
  ) async {
    final coordinator = ProxyLabelPlaybackCoordinator()..setPageActive(true);
    addTearDown(coordinator.dispose);
    var expanded = false;
    late StateSetter update;

    await tester.pumpWidget(
      _app(
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return _label(
              coordinator,
              text: 'Japan premium streaming node with a long name',
              replayToken: expanded,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pump();
    await _finishPlayback(tester);

    update(() => expanded = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('scrolling-proxy-label-active')),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion keeps overflowing labels static', (tester) async {
    final coordinator = ProxyLabelPlaybackCoordinator()..setPageActive(true);
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      _app(
        disableAnimations: true,
        child: _label(
          coordinator,
          text: 'United States premium streaming node with a long name',
          replayToken: false,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey('scrolling-proxy-label-active')),
      findsNothing,
    );
    expect(coordinator.hasActivePlayback, isFalse);
  });
}
