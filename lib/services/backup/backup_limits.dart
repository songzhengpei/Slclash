class BackupLimits {
  const BackupLimits({
    this.maxArchiveBytes = 20 * 1024 * 1024,
    this.maxEntries = 512,
    this.maxEntryBytes = 20 * 1024 * 1024,
    this.maxExtractedBytes = 64 * 1024 * 1024,
    this.maxManifestBytes = 1024 * 1024,
    this.maxProfilesBytes = 2 * 1024 * 1024,
  });

  final int maxArchiveBytes;
  final int maxEntries;
  final int maxEntryBytes;
  final int maxExtractedBytes;
  final int maxManifestBytes;
  final int maxProfilesBytes;
}
