import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/backup/restore_bundle.dart';
import 'package:path/path.dart' as p;

import 'backup_config.dart';

typedef ProfileYamlValidator =
    Future<void> Function(int profileId, Uint8List bytes);
typedef RestoreConfigReader = Future<Config?> Function();
typedef RestoreConfigWriter = Future<bool> Function(Config config);
typedef RestoreProgressCallback =
    void Function(String stage, int? profileCount);

class RestorePaths {
  final String profilesDirectory;
  final String scriptsDirectory;
  final String? workerUnifiedArchivePath;

  const RestorePaths({
    required this.profilesDirectory,
    required this.scriptsDirectory,
    this.workerUnifiedArchivePath,
  });

  String get providersDirectory => p.join(profilesDirectory, 'providers');
}

class RestoreService {
  final Database database;
  final RestorePaths paths;
  final ProfileYamlValidator? validateProfileYaml;
  final RestoreConfigReader? readConfig;
  final RestoreConfigWriter? writeConfig;
  final RestoreProgressCallback? onProgress;

  const RestoreService({
    required this.database,
    required this.paths,
    this.validateProfileYaml,
    this.readConfig,
    this.writeConfig,
    this.onProgress,
  });

  Future<RestoreCommitResult> restore(
    RestoreBundle bundle, {
    bool override = true,
  }) async {
    await _validate(bundle);
    onProgress?.call('validated', bundle.profiles.length);

    final oldProfiles = await database.profilesDao.query().get();
    final profilesOnly = bundle.scope == RestoreScope.profilesOnly;
    final oldScripts = profilesOnly
        ? const <Script>[]
        : await database.scriptsDao.query().get();
    final profileIds = bundle.profiles.map((e) => e.id).toSet();
    final selected =
        bundle.currentProfileId != null &&
            profileIds.contains(bundle.currentProfileId)
        ? bundle.currentProfileId
        : (bundle.profiles.isEmpty ? null : bundle.profiles.first.id);
    final touched = <String>{
      ...bundle.files.map((e) => _targetFor(e.relativePath)),
      if (bundle.replaceWorkerUnifiedArchive &&
          paths.workerUnifiedArchivePath != null)
        paths.workerUnifiedArchivePath!,
      if (bundle.providerCachePolicy ==
          ProviderCachePolicy.invalidateRestoredProfiles)
        ...profileIds.map((id) => p.join(paths.providersDirectory, '$id')),
      if (override)
        ...oldProfiles.map(
          (e) => p.join(paths.profilesDirectory, '${e.id}.yaml'),
        ),
      if (override && !profilesOnly)
        ...oldScripts.map((e) => p.join(paths.scriptsDirectory, '${e.id}.js')),
      if (override &&
          bundle.providerCachePolicy ==
              ProviderCachePolicy.invalidateRestoredProfiles)
        ...oldProfiles.map((e) => p.join(paths.providersDirectory, '${e.id}')),
    };
    final snapshot = await _FileSnapshot.capture(touched);
    final previousConfig = bundle.config == null
        ? null
        : await readConfig?.call();
    final restoredConfig = bundle.config == null
        ? null
        : preserveLocalBackupSecrets(
            bundle.config!.copyWith(currentProfileId: selected),
            previousConfig,
          );
    var configWritten = false;

    try {
      await database.transaction(() async {
        if (profilesOnly) {
          await database.restoreProfilesOnly(
            bundle.profiles,
            isOverride: override,
          );
          await database.proxyGroupsSnapshotsDao.deleteSnapshots({
            ...profileIds,
            if (override) ...oldProfiles.map((profile) => profile.id),
          });
        } else {
          await database.restore(
            bundle.profiles,
            bundle.scripts,
            bundle.rules,
            bundle.links,
            bundle.proxyGroups,
            isOverride: override,
          );
        }
        onProgress?.call('database-restored', bundle.profiles.length);
        try {
          await _commitFiles(
            bundle,
            override: override,
            oldProfiles: oldProfiles,
            oldScripts: oldScripts,
            replaceScripts: !profilesOnly,
          );
          onProgress?.call('files-committed', bundle.profiles.length);
          await _commitWorkerArchive(bundle);
          onProgress?.call('archive-committed', bundle.profiles.length);
          if (restoredConfig case final config?) {
            final writer = writeConfig;
            configWritten = writer != null;
            if (writer != null && !await writer(config)) {
              throw const RestoreValidationException(
                'failed to persist backup settings',
              );
            }
          }
        } catch (_) {
          await snapshot.restore();
          rethrow;
        }
      });
    } catch (_) {
      // Also covers the unlikely case where committing the SQLite transaction
      // fails after the filesystem switch completed.
      await snapshot.restore();
      if (configWritten && previousConfig != null) {
        await writeConfig?.call(previousConfig);
      }
      rethrow;
    }

    onProgress?.call('committed', bundle.profiles.length);

    return RestoreCommitResult(
      currentProfileId: selected,
      restoredProfileIds: profileIds,
      config: restoredConfig,
    );
  }

  Future<void> _validate(RestoreBundle bundle) async {
    if (bundle.profiles.isEmpty) {
      throw const RestoreValidationException('backup contains no profiles');
    }
    _requireUnique(bundle.profiles.map((e) => e.id), 'profile id');
    _requireUnique(bundle.scripts.map((e) => e.id), 'script id');
    _requireUnique(bundle.rules.map((e) => e.id), 'rule id');
    _requireUnique(bundle.files.map((e) => e.relativePath), 'file path');
    if (bundle.workerUnifiedArchive != null &&
        paths.workerUnifiedArchivePath == null) {
      throw const RestoreValidationException(
        'Worker unified archive storage is not configured',
      );
    }

    final profileIds = bundle.profiles.map((e) => e.id).toSet();
    final scriptIds = bundle.scripts.map((e) => e.id).toSet();
    if (bundle.scope == RestoreScope.profilesOnly) {
      scriptIds.addAll(
        (await database.scriptsDao.query().get()).map((script) => script.id),
      );
    }
    final ruleIds = bundle.rules.map((e) => e.id).toSet();
    if (bundle.currentProfileId != null &&
        !profileIds.contains(bundle.currentProfileId)) {
      throw const RestoreValidationException(
        'current profile does not exist in the backup',
      );
    }
    for (final profile in bundle.profiles) {
      if (profile.scriptId != null && !scriptIds.contains(profile.scriptId)) {
        throw RestoreValidationException(
          'profile ${profile.id} references missing script ${profile.scriptId}',
        );
      }
      StagedRestoreFile? file;
      for (final candidate in bundle.files) {
        if (candidate.relativePath == 'profiles/${profile.id}.yaml') {
          file = candidate;
          break;
        }
      }
      if (file == null || file.bytes.isEmpty) {
        throw RestoreValidationException(
          'profile ${profile.id} has no non-empty yaml file',
        );
      }
      await validateProfileYaml?.call(profile.id, file.bytes);
    }
    final scriptsById = {
      for (final script in bundle.scripts) script.id: script,
    };
    final scriptFiles = <int, StagedRestoreFile>{};
    for (final file in bundle.files) {
      final match = RegExp(
        r'^scripts/(\d+)\.js$',
      ).firstMatch(file.relativePath);
      if (match != null) {
        scriptFiles[int.parse(match.group(1)!)] = file;
      }
    }
    for (final script in scriptsById.values) {
      final file = scriptFiles[script.id];
      if (file == null || file.bytes.isEmpty) {
        throw RestoreValidationException(
          'script ${script.id} has no non-empty JavaScript file',
        );
      }
    }
    for (final scriptId in scriptFiles.keys) {
      if (!scriptsById.containsKey(scriptId)) {
        throw RestoreValidationException(
          'JavaScript file references missing script $scriptId',
        );
      }
    }
    for (final link in bundle.links) {
      if (!ruleIds.contains(link.ruleId)) {
        throw RestoreValidationException(
          'rule link references missing rule ${link.ruleId}',
        );
      }
      if (link.profileId != null && !profileIds.contains(link.profileId)) {
        throw RestoreValidationException(
          'rule link references missing profile ${link.profileId}',
        );
      }
    }
    for (final group in bundle.proxyGroups) {
      if (group.profileId != null && !profileIds.contains(group.profileId)) {
        throw RestoreValidationException(
          'proxy group references missing profile ${group.profileId}',
        );
      }
    }
    for (final file in bundle.files) {
      _targetFor(file.relativePath);
    }
  }

  void _requireUnique(Iterable<Object> values, String label) {
    final seen = <Object>{};
    for (final value in values) {
      if (!seen.add(value)) {
        throw RestoreValidationException('duplicate $label: $value');
      }
    }
  }

  String _targetFor(String relativePath) {
    final normalized = p.posix.normalize(relativePath.replaceAll('\\', '/'));
    if (normalized.startsWith('/') ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw RestoreValidationException('unsafe restore path: $relativePath');
    }
    final segments = p.posix.split(normalized);
    if (segments.length != 2 ||
        (segments.first != 'profiles' && segments.first != 'scripts')) {
      throw RestoreValidationException(
        'unsupported restore path: $relativePath',
      );
    }
    final root = segments.first == 'profiles'
        ? paths.profilesDirectory
        : paths.scriptsDirectory;
    return p.join(root, segments.last);
  }

  Future<void> _commitFiles(
    RestoreBundle bundle, {
    required bool override,
    required List<Profile> oldProfiles,
    required List<Script> oldScripts,
    required bool replaceScripts,
  }) async {
    if (override) {
      final wantedProfiles = bundle.profiles.map((e) => e.id).toSet();
      final wantedScripts = bundle.scripts.map((e) => e.id).toSet();
      for (final profile in oldProfiles) {
        if (!wantedProfiles.contains(profile.id)) {
          await File(
            p.join(paths.profilesDirectory, '${profile.id}.yaml'),
          ).deleteIfExists();
        }
      }
      if (replaceScripts) {
        for (final script in oldScripts) {
          if (!wantedScripts.contains(script.id)) {
            await File(
              p.join(paths.scriptsDirectory, '${script.id}.js'),
            ).deleteIfExists();
          }
        }
      }
    }
    for (final staged in bundle.files) {
      final target = File(_targetFor(staged.relativePath));
      await target.parent.create(recursive: true);
      final temporary = File('${target.path}.restore-tmp');
      await temporary.writeAsBytes(staged.bytes, flush: true);
      await target.deleteIfExists();
      await temporary.rename(target.path);
    }
    if (bundle.providerCachePolicy ==
        ProviderCachePolicy.invalidateRestoredProfiles) {
      final invalidatedIds = <int>{
        ...bundle.profiles.map((e) => e.id),
        if (override) ...oldProfiles.map((e) => e.id),
      };
      for (final profileId in invalidatedIds) {
        final dir = Directory(p.join(paths.providersDirectory, '$profileId'));
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    }
  }

  Future<void> _commitWorkerArchive(RestoreBundle bundle) async {
    if (!bundle.replaceWorkerUnifiedArchive) return;
    final archivePath = paths.workerUnifiedArchivePath;
    if (archivePath == null) return;
    final target = File(archivePath);
    final bytes = bundle.workerUnifiedArchive;
    if (bytes == null) {
      await target.deleteIfExists();
      return;
    }
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.restore-tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await target.deleteIfExists();
    await temporary.rename(target.path);
  }
}

extension on File {
  Future<void> deleteIfExists() async {
    if (await exists()) await delete();
  }
}

class _FileSnapshot {
  final Map<String, Uint8List> files;
  final Set<String> absentRoots;
  final Set<String> roots;

  const _FileSnapshot(this.files, this.absentRoots, this.roots);

  static Future<_FileSnapshot> capture(Set<String> paths) async {
    final files = <String, Uint8List>{};
    final absent = <String>{};
    for (final path in paths) {
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.notFound) {
        absent.add(path);
      } else if (type == FileSystemEntityType.file) {
        files[path] = await File(path).readAsBytes();
      } else if (type == FileSystemEntityType.directory) {
        await for (final entity in Directory(path).list(recursive: true)) {
          if (entity is File) files[entity.path] = await entity.readAsBytes();
        }
      }
    }
    return _FileSnapshot(files, absent, paths);
  }

  Future<void> restore() async {
    for (final root in roots) {
      final type = await FileSystemEntity.type(root);
      if (type == FileSystemEntityType.file) await File(root).delete();
      if (type == FileSystemEntityType.directory) {
        await Directory(root).delete(recursive: true);
      }
    }
    for (final entry in files.entries) {
      final file = File(entry.key);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
    // Kept explicitly as documentation of roots that must remain absent.
    for (final path in absentRoots) {
      if (await FileSystemEntity.type(path) == FileSystemEntityType.file) {
        await File(path).delete();
      }
    }
  }
}
