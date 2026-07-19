import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'backup_error.dart';
import 'worker_v1_models.dart';
import 'worker_v1_parser.dart';

typedef WorkerV1CapsuleFetcher = Future<Uint8List> Function(String url);

class WorkerV1CapsuleStore {
  const WorkerV1CapsuleStore({
    required this.directory,
    required this.fetch,
    this.parser = const WorkerV1Parser(),
  });

  final String directory;
  final WorkerV1CapsuleFetcher fetch;
  final WorkerV1Parser parser;

  Future<List<WorkerV1Package>> resolve({
    required List<String> urls,
    Uint8List? importedArchive,
  }) async {
    final packages = <WorkerV1Package>[];
    if (importedArchive != null) packages.add(parser.parse(importedArchive));
    final known = _urls(packages);
    final cache = Directory(directory);
    if (await cache.exists()) {
      await for (final entity in cache.list()) {
        if (entity is! File || p.extension(entity.path) != '.zip') continue;
        try {
          final package = parser.parse(await entity.readAsBytes());
          packages.add(package);
          known.addAll(_urls([package]));
        } catch (_) {
          await entity.delete();
        }
      }
    }
    for (final url in urls.toSet()) {
      if (known.contains(url)) continue;
      final bytes = await fetch(url);
      final package = parser.parse(bytes);
      final packageUrls = _urls([package]);
      if (packageUrls.length != 1 || packageUrls.single != url) {
        throw const BackupFormatException(
          BackupErrorCode.missingTrustedMetadata,
          'Worker capsule does not identify the requested subscription',
        );
      }
      _validateProviderMetadata(package);
      await cache.create(recursive: true);
      final name = sha256.convert(url.codeUnits).toString();
      final target = File(p.join(cache.path, '$name.zip'));
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
      packages.add(package);
      known.add(url);
    }
    return packages;
  }

  Set<String> _urls(List<WorkerV1Package> packages) => {
    for (final package in packages)
      for (final raw in package.profilesYaml['items'] as List)
        (raw as Map)['url'] as String,
  };

  void _validateProviderMetadata(WorkerV1Package package) {
    for (final airport in package.manifest.airports) {
      final slug = airport['slug'] as String;
      final bytes = package.files['providers/$slug/meta.json'];
      try {
        final value = jsonDecode(utf8.decode(bytes!, allowMalformed: false));
        if (value is Map && value.isNotEmpty) continue;
      } catch (_) {}
      throw const BackupFormatException(
        BackupErrorCode.missingTrustedMetadata,
        'Worker ProviderVersionMeta is empty or invalid',
      );
    }
  }
}
