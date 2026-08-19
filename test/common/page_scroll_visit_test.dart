import 'package:fl_clash/common/page_scroll_visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collectVerticalScrollPositions finds vertical list positions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          children: List.generate(
            40,
            (index) => SizedBox(height: 48, child: Text('row $index')),
          ),
        ),
      ),
    );

    final element = tester.element(find.byType(ListView));
    final visit = collectVerticalScrollPositions(element);
    expect(visit.elementsVisited, greaterThan(0));
    expect(visit.positionCount, 1);
    expect(visit.positions.first.axis, Axis.vertical);
    expect(scrollToTopTarget(visit.positions.first), 0);
  });

  testWidgets('visit does not count the page root as a child element', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(child: Text('leaf'))),
    );
    final root = tester.element(find.byType(SizedBox));
    final visit = collectVerticalScrollPositions(root);
    expect(visit.positionCount, 0);
    expect(visit.elementsVisited, greaterThanOrEqualTo(1));
  });
}
