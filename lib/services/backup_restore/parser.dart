import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:path/path.dart' as p;

import 'legacy_parser.dart';
import 'models.dart';
import 'parse_utils.dart';
import 'worker_parser.dart';

const unifiedSubscriptionWorkerBaseUrl =
    'https://mihomo-subscription-vault.nudymanu.workers.dev';

class BackupArchiveParser {
  const BackupArchiveParser({
    this.limits = const BackupArchiveLimits(),
    this.workerBaseUrl = unifiedSubscriptionWorkerBaseUrl,
  });

  final BackupArchiveLimits limits;
  final String workerBaseUrl;

  Future<UnifiedRestoreModel> parse(
    File source, {
    required Directory stagingDirectory,
  }) async {
    if (!await source.exists()) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidArchive,
        '备份文件不存在',
      );
    }
    final archiveLength = await source.length();
    if (archiveLength <= 0 || archiveLength > limits.maxArchiveBytes) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.archiveLimitExceeded,
        '备份 ZIP 大小超限（最大 ${limits.maxArchiveBytes ~/ (1024 * 1024)} MiB）',
      );
    }

    await _resetDirectory(stagingDirectory);
    final staged = await _stageArchive(source, stagingDirectory);
    try {
      if (staged.files.containsKey('manifest.json')) {
        return WorkerUnifiedBackupParser(
          limits: limits,
          workerBaseUrl: workerBaseUrl,
        ).parse(staged);
      }
      if (staged.files.containsKey(profilesBackupMetadataName)) {
        return LegacyBackupParser(limits: limits).parseProfilesBackup(staged);
      }
      if (staged.files.containsKey(backupDatabaseName)) {
        return LegacyBackupParser(limits: limits).parseDatabaseBackup(staged);
      }
      if (staged.files.containsKey(configJsonName)) {
        return LegacyBackupParser(limits: limits).parseConfigBackup(staged);
      }
      throw const BackupRestoreException(
        BackupRestoreErrorCode.unsupportedFormat,
        '无法识别备份格式',
      );
    } on BackupRestoreException {
      rethrow;
    } catch (error) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.invalidArchive,
        '备份解析失败',
        error,
      );
    }
  }

  Future<StagedBackupArchive> _stageArchive(
    File source,
    Directory stagingDirectory,
  ) async {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(
        await source.readAsBytes(),
        verify: true,
      );
    } catch (error) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.invalidArchive,
        'ZIP 结构或 CRC 校验失败',
        error,
      );
    }

    if (archive.files.length > limits.maxEntryCount) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.archiveLimitExceeded,
        'ZIP 条目数量超限（最大 ${limits.maxEntryCount}）',
      );
    }

    const utils = BackupParseUtils();
    final canonicalNames = <String>{};
    final foldedNames = <String>{};
    final entries = <({ArchiveFile entry, String path})>[];
    var expandedBytes = 0;

    for (final entry in archive.files) {
      final path = utils.canonicalArchivePath(entry.name);
      if (!canonicalNames.add(path) ||
          !foldedNames.add(path.toLowerCase())) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.duplicatePath,
          'ZIP 包含重复路径：$path',
        );
      }
      if (entry.isSymbolicLink) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.unsafePath,
          'ZIP 不允许包含符号链接：$path',
        );
      }
      if (entry.isDirectory) continue;
      if (!entry.isFile || entry.size < 0 || entry.size > limits.maxEntryBytes) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.archiveLimitExceeded,
          'ZIP 条目大小或类型无效：$path',
        );
      }
      expandedBytes += entry.size;
      if (expandedBytes > limits.maxExpandedBytes) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.archiveLimitExceeded,
          'ZIP 解压后总体积超限（最大 ${limits.maxExpandedBytes ~/ (1024 * 1024)} MiB）',
        );
      }
      entries.add((entry: entry, path: path));
    }

    final files = <String, File>{};
    for (final item in entries) {
      final bytes = item.entry.readBytes();
      if (bytes == null || bytes.length != item.entry.size) {
        throw BackupRestoreException(
          BackupRestoreErrorCode.invalidArchive,
          'ZIP 条目读取失败：${item.path}',
        );
      }
      final target = File(
        p.joinAll([stagingDirectory.path, ...item.path.split('/')]),
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      files[item.path] = target;
    }
    return StagedBackupArchive(stagingDirectory, files);
  }

  Future<void> _resetDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }
}
