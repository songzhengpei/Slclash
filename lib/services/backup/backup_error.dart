enum BackupErrorCode {
  invalidZip,
  archiveTooLarge,
  tooManyEntries,
  entryTooLarge,
  extractedDataTooLarge,
  unsafePath,
  duplicatePath,
  unsupportedEntry,
  missingManifest,
  invalidManifest,
  unsupportedFormat,
  missingRequiredFile,
  unexpectedFile,
  sizeMismatch,
  hashMismatch,
  invalidProfiles,
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.code, this.message);

  final BackupErrorCode code;
  final String message;

  @override
  String toString() => 'BackupFormatException($code): $message';
}
