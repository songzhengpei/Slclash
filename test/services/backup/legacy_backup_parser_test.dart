import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_clash/services/backup/backup_format_detector.dart';
import 'package:fl_clash/services/backup/legacy_backup_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = BackupFormatDetector();
  const parser = LegacyBackupParser();

  test('detects Worker package by manifest without parsing as legacy', () {
    final bytes = _zip({'manifest.json': '{}'});
    expect(detector.detectBytes(bytes), BackupFormat.workerUnifiedV1);
    expect(
      () => parser.parseBytes(bytes),
      throwsA(isA<BackupFormatException>()),
    );
  });

  for (final type in ['profiles_only_v1', 'profiles_only_v2']) {
    test('parses $type metadata and keeps files in memory', () {
      final bytes = _zip({
        'metadata.json': jsonEncode({
          'backupType': type,
          'currentProfileId': 7,
          'profiles': [
            {'id': 7, 'label': 'legacy'},
          ],
        }),
        'profiles/7.yaml': 'proxies: []',
      });
      final parsed = parser.parseBytes(bytes);
      expect(parsed.currentProfileId, 7);
      expect(parsed.profiles.single['label'], 'legacy');
      expect(utf8.decode(parsed.files['profiles/7.yaml']!), 'proxies: []');
    });
  }

  test('rejects unknown metadata backup type instead of falling back', () {
    final bytes = _zip({
      'metadata.json': '{"backupType":"profiles_only_v99","profiles":[]}',
      'database.sqlite': 'db',
      'config.json': '{}',
    });
    expect(
      () => detector.detectBytes(bytes),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects retired profiles_only_v3 backups explicitly', () {
    final bytes = _zip({
      'metadata.json': '{"backupType":"profiles_only_v3","profiles":[]}',
    });
    expect(
      () => detector.detectBytes(bytes),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.code,
          'code',
          BackupErrorCode.unsupportedFormat,
        ),
      ),
    );
  });

  test('parses v2.0.1 traditional package without opening its database', () {
    final bytes = _zip({
      'database.sqlite': [1, 2, 3],
      'config.json': jsonEncode({'version': 3, 'currentProfileId': 42}),
      'profiles/42.yaml': 'mode: rule',
    });
    final parsed = parser.parseBytes(bytes);
    expect(parsed.format, BackupFormat.traditional);
    expect(parsed.currentProfileId, 42);
    expect(parsed.files['database.sqlite'], Uint8List.fromList([1, 2, 3]));
  });

  test('accepts only explicit version zero config-only legacy shape', () {
    final parsed = parser.parseBytes(
      _zip({
        'config.json': jsonEncode({
          'version': 0,
          'currentProfileId': 1,
          'profiles': [
            {'id': 1},
          ],
          'locale': 'zh_CN',
        }),
      }),
    );
    expect(parsed.format, BackupFormat.legacyConfigOnly);
    expect(parsed.config?['locale'], 'zh_CN');

    final unknown = _zip({
      'config.json': jsonEncode({'version': 9, 'profiles': []}),
    });
    expect(
      () => parser.parseBytes(unknown),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('legacy parsing rejects duplicate normalized ZIP paths', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('config.json', '{"profiles":[]}'))
      ..addFile(ArchiveFile.string('CONFIG.JSON', '{"profiles":[]}'));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    expect(
      () => parser.parseBytes(bytes),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.code,
          'code',
          BackupErrorCode.duplicatePath,
        ),
      ),
    );
  });
}

Uint8List _zip(Map<String, Object> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final value = entry.value;
    archive.addFile(
      ArchiveFile.bytes(
        entry.key,
        value is String ? utf8.encode(value) : value as List<int>,
      ),
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
