import 'dart:io';

import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/surge/soft_os_control_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bottom navigation uses the rounded icon dictionary', () {
    expect(
      SurgeIcons.bottomNavigation(PageLabel.dashboard),
      SurgeIcons.dashboard,
    );
    expect(SurgeIcons.bottomNavigation(PageLabel.proxies), SurgeIcons.proxies);
    expect(
      SurgeIcons.bottomNavigation(PageLabel.profiles),
      SurgeIcons.profiles,
    );
    expect(SurgeIcons.bottomNavigation(PageLabel.tools), SurgeIcons.tools);
  });

  testWidgets('Soft OS action buttons render the supplied rounded icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoftOsActionButton(icon: SurgeIcons.close, onPressed: () {}),
        ),
      ),
    );

    expect(find.byIcon(SurgeIcons.close), findsOneWidget);
  });

  test('provider action has a dedicated outlined cloud-download icon', () {
    expect(SurgeIcons.providerDownload, Icons.cloud_download_outlined);
  });

  test('only the Surge icon dictionary selects Material icon glyphs', () {
    final directMaterialIcon = RegExp(r'\bIcons\.');
    final cupertinoIcon = RegExp(r'\bCupertinoIcons\.');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.replaceAll('\\', '/').contains('/app_bar/')) {
        continue;
      }

      final source = entity.readAsStringSync();
      final isIconDictionary =
          entity.path.replaceAll('\\', '/') == 'lib/common/icons.dart';
      if (!isIconDictionary) {
        expect(
          directMaterialIcon.hasMatch(source),
          isFalse,
          reason: '${entity.path} bypasses SurgeIcons.',
        );
      }
      expect(
        cupertinoIcon.hasMatch(source),
        isFalse,
        reason: '${entity.path} uses a Cupertino icon.',
      );
    }
  });
}
