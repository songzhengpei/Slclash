import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('profile-read-test');
    AppPath.useDirectoryForTesting(tempDir);
  });

  tearDown(() async {
    AppPath.resetForTesting();
    await tempDir.delete(recursive: true);
  });

  test('Profile.file and common guarded reads never create source', () async {
    const profile = Profile(
      id: 42,
      label: 'remote',
      url: 'https://example.com/profile',
      autoUpdateDuration: Duration(hours: 1),
    );

    final file = await profile.file;
    expect(await file.exists(), isFalse);

    // Edit file-info and export paths first guard on exists before reading.
    if (await file.exists()) {
      await file.length();
      await file.readAsBytes();
    }

    expect(await profile.sourceExists, isFalse);
    expect(await file.exists(), isFalse);
  });
}
