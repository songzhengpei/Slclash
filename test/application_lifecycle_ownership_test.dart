import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Application dispose owns Flutter resources only', () {
    final source = File('lib/application.dart').readAsStringSync();
    final disposeStart = source.indexOf('  void dispose() {');
    expect(disposeStart, isNonNegative);

    final disposeSource = source.substring(disposeStart);
    expect(disposeSource, isNot(contains('handleExit(')));
    expect(disposeSource, isNot(contains('coreController.destroy(')));
    expect(disposeSource, isNot(contains('stopProxy(')));
  });

  test('SystemAction remains the single core destroy owner', () {
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final destroyOwners = <String>[];

    for (final file in dartSources) {
      final matches = RegExp(
        r'coreController\.destroy\(\)',
      ).allMatches(file.readAsStringSync());
      destroyOwners.addAll(List.filled(matches.length, file.path));
    }

    expect(destroyOwners, hasLength(1));
    expect(
      destroyOwners.single.replaceAll('\\', '/'),
      endsWith('lib/providers/action.dart'),
    );
  });

  test(
    'AppStateManager publishes lifecycle truth without owning stats timer',
    () {
      final source = File('lib/manager/app_manager.dart').readAsStringSync();

      expect(source, contains('appForegroundProvider.notifier).set(true)'));
      expect(source, contains('appForegroundProvider.notifier).set(false)'));
      expect(source, isNot(contains('resumeUiStatsTimerIfNeeded')));
      expect(source, isNot(contains('cancelUiStatsTimer')));
    },
  );
}
