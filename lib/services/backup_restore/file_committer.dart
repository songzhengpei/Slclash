import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

class RestoreFileCommitter {
  RestoreFileCommitter({
    required this.profilesDirectory,
    required this.scriptsDirectory,
    required this.providersDirectory,
    required this.rollbackDirectory,
  });

  final Directory profilesDirectory;
  final Directory scriptsDirectory;
  final Directory providersDirectory;
  final Directory rollbackDirectory;

  final List<_FileMutation> _mutations = [];
  bool _providersRootBackedUp = false;
  bool _applied = false;

  Future<void> apply(
    UnifiedRestoreModel model, {
    required bool replaceExisting,
  }) async {
    if (_applied) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.fileCommitFailure,
        '恢复文件事务不能重复执行',
      );
    }
    _applied = true;
    await _resetDirectory(rollbackDirectory);
    await profilesDirectory.create(recursive: true);
    await scriptsDirectory.create(recursive: true);

    try {
      final replaceProviders =
          model.invalidateProviderCaches || replaceExisting;
      if (replaceProviders) {
        await _backupAndClearProvidersRoot();
      } else {
        await providersDirectory.create(recursive: true);
      }

      if (replaceExisting) {
        final retainedProfiles =
            model.profileFiles.map((item) => item.relativeTarget).toSet();
        final retainedScripts =
            model.scriptFiles.map((item) => item.relativeTarget).toSet();
        await _removeStaleFiles(
          profilesDirectory,
          retainedProfiles,
          extension: '.yaml',
          skipDirectoryNames: const {'providers'},
        );
        await _removeStaleFiles(
          scriptsDirectory,
          retainedScripts,
          extension: '.js',
        );
      }

      await _writeAll(model.profileFiles, profilesDirectory);
      await _writeAll(model.scriptFiles, scriptsDirectory);
      await _writeAll(model.providerFiles, providersDirectory);
    } catch (error) {
      await rollback();
      if (error is BackupRestoreException) rethrow;
      throw BackupRestoreException(
        BackupRestoreErrorCode.fileCommitFailure,
        '恢复文件提交失败',
        error,
      );
    }
  }

  Future<void> complete() async {
    try {
      if (await rollbackDirectory.exists()) {
        await rollbackDirectory.delete(recursive: true);
      }
    } finally {
      _mutations.clear();
      _providersRootBackedUp = false;
    }
  }

  Future<void> rollback() async {
    for (final mutation in _mutations.reversed) {
      try {
        if (mutation.hadOriginal) {
          await mutation.target.parent.create(recursive: true);
          if (await mutation.target.exists()) {
            await mutation.target.delete();
          }
          await mutation.backup.copy(mutation.target.path);
        } else if (await mutation.target.exists()) {
          await mutation.target.delete();
        }
      } catch (_) {
        // Continue restoring every recorded path.
      }
    }
    _mutations.clear();

    if (_providersRootBackedUp) {
      try {
        if (await providersDirectory.exists()) {
          await providersDirectory.delete(recursive: true);
        }
        final backup = Directory(
          p.join(rollbackDirectory.path, 'providers-root'),
        );
        if (await backup.exists()) {
          await _copyDirectory(backup, providersDirectory);
        }
      } catch (_) {
        // Database rollback still proceeds; caller reports the original error.
      }
    }
    _providersRootBackedUp = false;
  }

  Future<void> _backupAndClearProvidersRoot() async {
    final backup = Directory(
      p.join(rollbackDirectory.path, 'providers-root'),
    );
    if (await providersDirectory.exists()) {
      await _copyDirectory(providersDirectory, backup);
      _providersRootBackedUp = true;
      await providersDirectory.delete(recursive: true);
    } else {
      _providersRootBackedUp = true;
    }
    await providersDirectory.create(recursive: true);
  }

  Future<void> _writeAll(
    Iterable<RestoreSourceFile> files,
    Directory root,
  ) async {
    for (final item in files) {
      final target = _resolveTarget(root, item.relativeTarget);
      await _backupTarget(target);
      await target.parent.create(recursive: true);
      final temporary = File(
        '${target.path}.restore-${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        await item.source.copy(temporary.path);
        if (await target.exists()) {
          await target.delete();
        }
        await temporary.rename(target.path);
      } finally {
        if (await temporary.exists()) {
          await temporary.delete();
        }
      }
    }
  }

  Future<void> _removeStaleFiles(
    Directory root,
    Set<String> retained, {
    required String extension,
    Set<String> skipDirectoryNames = const {},
  }) async {
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          skipDirectoryNames.contains(p.basename(entity.path))) {
        continue;
      }
      if (entity is! File || !entity.path.endsWith(extension)) {
        continue;
      }
      final relative = p.relative(entity.path, from: root.path);
      if (retained.contains(relative)) continue;
      await _backupTarget(entity);
      await entity.delete();
    }
  }

  Future<void> _backupTarget(File target) async {
    final key = shaPath(target.path);
    final backup = File(p.join(rollbackDirectory.path, 'files', key));
    final hadOriginal = await target.exists();
    if (hadOriginal) {
      await backup.parent.create(recursive: true);
      await target.copy(backup.path);
    }
    _mutations.add(
      _FileMutation(
        target: target,
        backup: backup,
        hadOriginal: hadOriginal,
      ),
    );
  }

  File _resolveTarget(Directory root, String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
        normalized.split('/').any(
              (segment) =>
                  segment.isEmpty || segment == '.' || segment == '..',
            )) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.unsafePath,
        '恢复目标路径无效：$relativePath',
      );
    }
    final rootPath = p.absolute(p.normalize(root.path));
    final targetPath = p.absolute(
      p.normalize(p.join(rootPath, ...normalized.split('/'))),
    );
    if (!p.equals(rootPath, targetPath) &&
        !p.isWithin(rootPath, targetPath)) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.unsafePath,
        '恢复目标路径越界：$relativePath',
      );
    }
    return File(targetPath);
  }

  String shaPath(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  Future<void> _copyDirectory(
    Directory source,
    Directory target,
  ) async {
    await target.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Link) {
        throw const BackupRestoreException(
          BackupRestoreErrorCode.fileCommitFailure,
          'Provider 缓存目录包含符号链接',
        );
      }
      final relative = p.relative(entity.path, from: source.path);
      final destination = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(destination).create(recursive: true);
      } else if (entity is File) {
        await File(destination).parent.create(recursive: true);
        await entity.copy(destination);
      }
    }
  }

  Future<void> _resetDirectory(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }
}

class _FileMutation {
  const _FileMutation({
    required this.target,
    required this.backup,
    required this.hadOriginal,
  });

  final File target;
  final File backup;
  final bool hadOriginal;
}
