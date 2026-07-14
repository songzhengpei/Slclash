import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/services/backup/backup_error.dart';
import 'package:fl_clash/services/backup/backup_limits.dart';
import 'package:fl_clash/services/backup/worker_v1_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkerV1Parser', () {
    test('parses and verifies a valid Worker unified archive', () {
      final package = const WorkerV1Parser().parse(_validArchive());

      expect(package.manifest.raw['formatVersion'], 1);
      expect(package.manifest.airports.single['profileUid'], 'R1234abcd');
      expect(package.profilesYaml['current'], 'R1234abcd');
      expect(package.files, contains('profiles/R1234abcd.yaml'));
    });

    test('rejects a missing manifest', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('config.yaml', 'x'));
      _expectCode(_encode(archive), BackupErrorCode.missingManifest);
    });

    test('rejects an unsupported version', () {
      final manifest = _manifest(_payloadFiles())..['formatVersion'] = 2;
      _expectCode(
        _archive(_payloadFiles(), manifest: manifest),
        BackupErrorCode.unsupportedFormat,
      );
    });

    test('rejects a content hash mismatch', () {
      final files = _payloadFiles();
      final manifest = _manifest(files);
      (manifest['files'] as Map<String, Object?>)['config.yaml'] = {
        'sha256': '0' * 64,
        'contentLength': files['config.yaml']!.length,
        'required': true,
      };
      _expectCode(
        _archive(files, manifest: manifest),
        BackupErrorCode.hashMismatch,
      );
    });

    test('rejects ZIP path traversal', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('../manifest.json', '{}'));
      _expectCode(_encode(archive), BackupErrorCode.unsafePath);
    });

    test('rejects duplicate normalized paths', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('manifest.json', '{}'))
        ..addFile(ArchiveFile.string('MANIFEST.JSON', '{}'));
      _expectCode(_encode(archive), BackupErrorCode.duplicatePath);
    });

    test('rejects an archive over the compressed size limit', () {
      final bytes = _validArchive();
      final parser = WorkerV1Parser(
        limits: BackupLimits(maxArchiveBytes: bytes.length - 1),
      );
      expect(
        () => parser.parse(bytes),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.code,
            'code',
            BackupErrorCode.archiveTooLarge,
          ),
        ),
      );
    });

    test('rejects an entry over the extracted entry limit', () {
      _expectCode(
        _validArchive(),
        BackupErrorCode.entryTooLarge,
        parser: const WorkerV1Parser(limits: BackupLimits(maxEntryBytes: 10)),
      );
    });

    test('rejects a missing required profile', () {
      final files = _payloadFiles()..remove('profiles/R1234abcd.yaml');
      _expectCode(
        _archive(files, manifest: _manifest(files)),
        BackupErrorCode.missingRequiredFile,
      );
    });
  });
}

Map<String, List<int>> _payloadFiles() => {
  'config.yaml': utf8.encode('proxy-providers: {}\n'),
  'verge.yaml': utf8.encode('{}\n'),
  'profiles.yaml': utf8.encode('''
current: R1234abcd
items:
  - uid: R1234abcd
    type: remote
    name: Example
    file: R1234abcd.yaml
    url: https://vault.example/config/example/fixed-token
    updated: 1
    option:
      allow_auto_update: true
'''),
  'profiles/R1234abcd.yaml': utf8.encode('proxies: []\n'),
  'providers/example/provider.yaml': utf8.encode('proxies: []\n'),
  'providers/example/profile.yaml': utf8.encode('proxies: []\n'),
  'providers/example/meta.json': utf8.encode('{}\n'),
};

Map<String, Object?> _manifest(Map<String, List<int>> files) {
  final entries = <String, Object?>{};
  for (final entry in files.entries) {
    entries[entry.key] = {
      'sha256': sha256.convert(entry.value).toString(),
      'contentLength': entry.value.length,
      'required':
          entry.key == 'config.yaml' ||
          entry.key == 'verge.yaml' ||
          entry.key == 'profiles.yaml' ||
          entry.key.startsWith('profiles/'),
    };
  }
  return {
    'format': 'mihomo-unified-backup',
    'formatVersion': 1,
    'archiveType': 'unified-subscription-archive',
    'createdAt': '2026-07-15T00:00:00.000Z',
    'generator': 'worker',
    'generatorVersion': '1.0.0',
    'publicBaseUrl': 'https://vault.example',
    'mainConfig': {
      'configId': 'config-id',
      'versionId': 'version-id',
      'name': 'Main',
      'sourceSha256': '1' * 64,
    },
    'airports': [
      {
        'slug': 'example',
        'subscriptionId': 'subscription-id',
        'name': 'Example',
        'profileUid': 'R1234abcd',
        'versionId': 'provider-version',
        'nodeCount': 0,
        'providerSha256': sha256
            .convert(files['providers/example/provider.yaml']!)
            .toString(),
        'profileSha256': sha256
            .convert(files['providers/example/profile.yaml']!)
            .toString(),
      },
    ],
    'files': entries,
  };
}

List<int> _validArchive() {
  final files = _payloadFiles();
  return _archive(files, manifest: _manifest(files));
}

List<int> _archive(
  Map<String, List<int>> files, {
  required Map<String, Object?> manifest,
}) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
  return _encode(archive);
}

List<int> _encode(Archive archive) => ZipEncoder().encode(archive);

void _expectCode(
  List<int> bytes,
  BackupErrorCode code, {
  WorkerV1Parser parser = const WorkerV1Parser(),
}) {
  expect(
    () => parser.parse(bytes),
    throwsA(
      isA<BackupFormatException>().having((error) => error.code, 'code', code),
    ),
  );
}
