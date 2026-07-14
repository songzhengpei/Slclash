import 'dart:io';

import 'backup_error.dart';
import 'backup_limits.dart';

Future<void> validateBackupArchiveFile(
  File file, {
  BackupLimits limits = const BackupLimits(),
}) async {
  final length = await file.length();
  if (length > limits.maxArchiveBytes) {
    throw BackupFormatException(
      BackupErrorCode.archiveTooLarge,
      'Backup archive exceeds the ${limits.maxArchiveBytes ~/ (1024 * 1024)} MiB limit',
    );
  }
}

void validateBackupArchiveLength(
  int? length, {
  BackupLimits limits = const BackupLimits(),
}) {
  if (length != null && length > limits.maxArchiveBytes) {
    throw BackupFormatException(
      BackupErrorCode.archiveTooLarge,
      'Backup archive exceeds the ${limits.maxArchiveBytes ~/ (1024 * 1024)} MiB limit',
    );
  }
}
