import 'package:fl_clash/widgets/changelog_dialog.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders one card per release with a confirmation action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(360, 720)),
        ],
        child: const MaterialApp(home: Scaffold(body: AppChangelogDialog())),
      ),
    );

    expect(find.text('更新日志'), findsOneWidget);
    expect(find.text('v2.0.5'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
