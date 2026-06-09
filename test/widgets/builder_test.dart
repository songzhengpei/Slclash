import 'package:fl_clash/widgets/builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TickBuilder rebuilds on the configured interval', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TickBuilder(
          duration: const Duration(seconds: 1),
          builder: (_, tick) => Text('tick: $tick'),
        ),
      ),
    );

    expect(find.text('tick: 0'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('tick: 1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('tick: 2'), findsOneWidget);
  });
}
