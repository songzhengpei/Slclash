import 'dart:io';

import 'package:fl_clash/services/backup/backup_error.dart';
import 'package:fl_clash/services/backup/backup_file_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
