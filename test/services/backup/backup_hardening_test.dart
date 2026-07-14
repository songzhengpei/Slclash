import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/backup/backup_config.dart';
import 'package:fl_clash/services/backup/backup_error.dart';
import 'package:fl_clash/services/backup/backup_file_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profiles backup metadata never contains WebDAV credentials', () {
    const password = 'should-never-enter-the-archive';
    const config = Config(
      themeProps: defaultThemeProps,
      davProps: DAVProps(
        uri: 'https://dav.example.test',
        user: 'backup-user',
        password: password,
      ),
    );
    final metadata = ProfilesBackupMetadata(
      backupType: 'profiles_only_v2',
      createdAt: '2026-07-15T00:00:00Z',
      appVersion: 'test',
      currentProfileId: 1,
      profiles: const [],
      config: backupConfigJson(config),
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('metadata.json', jsonEncode(metadata.toJson())),
      );
    final encoded = ZipEncoder().encode(archive);
    final decoded = ZipDecoder().decodeBytes(encoded);
    final text = utf8.decode(decoded.findFile('metadata.json')!.content);

    expect(text, isNot(contains(password)));
    expect(text, isNot(contains('davProps')));
  });

  test('oversized archive is rejected before reading its contents', () async {
    final temp = await File(
      '${Directory.systemTemp.path}/slclash-oversized-${DateTime.now().microsecondsSinceEpoch}.zip',
    ).create();
    addTearDown(() => temp.delete());
    await temp.open(mode: FileMode.write).then((file) async {
      await file.truncate(20 * 1024 * 1024 + 1);
      await file.close();
    });

    await expectLater(
      validateBackupArchiveFile(temp),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.code,
          'code',
          BackupErrorCode.archiveTooLarge,
        ),
      ),
    );
  });
}
