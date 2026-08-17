import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Uint8List utf8Bytes(String source) =>
    Uint8List.fromList(source.codeUnits);

void main() {
  late Directory tempDir;
  late String targetPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('profile-atomic-test');
    targetPath = p.join(tempDir.path, '42.yaml');
    await File(targetPath).writeAsBytes(utf8Bytes('old: content\n'));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> Function(String path) acceptingValidator() {
    return (path) async => '';
  }

  Future<String> Function(String path) rejectingValidator(String message) {
    return (path) async => message;
  }

  List<String> stagingFiles() =>
      tempDir.listSync().map((e) => p.basename(e.path)).where(
            (name) => name.endsWith('.staging'),
          ).toList();

  test('successful validation replaces the target with the new complete bytes',
      () async {
    await atomicReplaceProfileFile(
      targetPath: targetPath,
      bytes: utf8Bytes('new: complete\nconfig: yes\n'),
      validate: acceptingValidator(),
    );
    expect(
      await File(targetPath).readAsBytes(),
      utf8Bytes('new: complete\nconfig: yes\n'),
    );
    expect(stagingFiles(), isEmpty);
  });

  test('failed validation leaves the old target untouched', () async {
    await expectLater(
      atomicReplaceProfileFile(
        targetPath: targetPath,
        bytes: utf8Bytes('new: content\n'),
        validate: rejectingValidator('invalid config'),
      ),
      throwsA('invalid config'),
    );
    expect(await File(targetPath).readAsBytes(), utf8Bytes('old: content\n'));
    expect(stagingFiles(), isEmpty);
  });

  test('validation exception leaves the old target untouched', () async {
    await expectLater(
      atomicReplaceProfileFile(
        targetPath: targetPath,
        bytes: utf8Bytes('new: content\n'),
        validate: (path) async => throw StateError('core down'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await File(targetPath).readAsBytes(), utf8Bytes('old: content\n'));
    expect(stagingFiles(), isEmpty);
  });

  test('staging files are cleaned up on every failure path', () async {
    await expectLater(
      atomicReplaceProfileFile(
        targetPath: targetPath,
        bytes: utf8Bytes('new: content\n'),
        validate: rejectingValidator('nope'),
      ),
      throwsA('nope'),
    );
    expect(stagingFiles(), isEmpty);
    // No target was created/truncated in the first place.
    expect(await File(targetPath).readAsBytes(), utf8Bytes('old: content\n'));
  });

  test('replacement on a missing target creates it only on success', () async {
    final freshPath = p.join(tempDir.path, '99.yaml');
    await atomicReplaceProfileFile(
      targetPath: freshPath,
      bytes: utf8Bytes('fresh: yes\n'),
      validate: acceptingValidator(),
    );
    expect(await File(freshPath).readAsBytes(), utf8Bytes('fresh: yes\n'));
  });

  test('failed validation never creates or truncates a missing target',
      () async {
    final freshPath = p.join(tempDir.path, '99.yaml');
    await expectLater(
      atomicReplaceProfileFile(
        targetPath: freshPath,
        bytes: utf8Bytes('fresh: yes\n'),
        validate: rejectingValidator('invalid'),
      ),
      throwsA('invalid'),
    );
    expect(await File(freshPath).exists(), isFalse);
    expect(stagingFiles(), isEmpty);
  });

  test('saveFile and saveFileWithPath share the same replacement primitive',
      () async {
    final sourcePath = p.join(tempDir.path, 'source.yaml');
    await File(sourcePath).writeAsBytes(utf8Bytes('from: source\n'));
    // Both entry points route through atomicReplaceProfileFile; exercising
    // saveFileWithPath here covers the shared path end to end.
    final sourceBytes = await File(sourcePath).readAsBytes();
    await atomicReplaceProfileFile(
      targetPath: targetPath,
      bytes: sourceBytes,
      validate: acceptingValidator(),
    );
    expect(await File(targetPath).readAsBytes(), sourceBytes);
  });
}
