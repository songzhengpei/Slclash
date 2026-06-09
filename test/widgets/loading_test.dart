import 'package:fl_clash/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CommonCircleLoading shrink-wraps when constraints are loose', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100, maxHeight: 32),
            child: const CommonCircleLoading(),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CommonCircleLoading)),
      const Size.square(32),
    );
  });

  testWidgets('CommonCircleLoading paints within the shortest constraint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            child: SizedBox.square(dimension: 32, child: CommonCircleLoading()),
          ),
        ),
      ),
    );

    final customPaint = find.descendant(
      of: find.byType(CommonCircleLoading),
      matching: find.byType(CustomPaint),
    );

    expect(tester.getSize(customPaint), const Size.square(32));
  });
}
