import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/backup_restore/backup_restore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupArchiveParser worker unified v1', () {
    test('imports a valid unified package and preserves Worker URL', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final entries = _buildWorkerEntries();
      final source = await fixture.writeZip(entries);
      final model = await const BackupArchiveParser().parse(
        source,
        stagingDirectory: fixture.staging,
      );
      addTearDown(model.dispose);

      expect(model.format, BackupArchiveFormat.workerUnifiedV1);
      expect(model.profiles, hasLength(1));
      expect(
        model.profiles.single.url,
        '$unifiedSubscriptionWorkerBaseUrl/config/airport-a/download-token',
      );
      expect(model.invalidateProviderCaches, isTrue);
      expect(model.profileFiles.single.source.existsSync(), isTrue);
    });

    test('rejects a missing manifest', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final entries = _buildWorkerEntries()..remove('manifest.json');
      final source = await fixture.writeZip(entries);

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.unsupportedFormat,
          ),
        ),
      );
    });

    test('rejects an unsupported format version', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final entries = _buildWorkerEntries(formatVersion: 2);
      final source = await fixture.writeZip(entries);

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.unsupportedVersion,
          ),
        ),
      );
    });

    test('rejects a file hash mismatch', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final entries = _buildWorkerEntries();
      entries['config.yaml'] = utf8.encode('proxies: []\n');
      final source = await fixture.writeZip(entries);

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.hashMismatch,
          ),
        ),
      );
    });

    test('rejects a missing required profile file', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final entries = _buildWorkerEntries()
        ..remove('profiles/0123456789abcdef.yaml');
      final source = await fixture.writeZip(entries);

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.missingRequiredFile,
          ),
        ),
      );
    });

    test('rejects a non-fixed subscription URL', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final entries = _buildWorkerEntries(
        profileUrl: 'https://example.com/config/airport-a/token',
      );
      final source = await fixture.writeZip(entries);

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.invalidWorkerUrl,
          ),
        ),
      );
    });
  });

  group('ZIP safety', () {
    test('rejects path traversal', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final source = await fixture.writeArchive(
        Archive()
          ..addFile(ArchiveFile.string('../escape.txt', 'escape')),
      );

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.unsafePath,
          ),
        ),
      );
    });

    test('rejects duplicate entries', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final archive = Archive()
        ..addFile(ArchiveFile.string('config.json', '{}'))
        ..addFile(ArchiveFile.string('config.json', '{}'));
      final source = await fixture.writeArchive(archive);

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.duplicatePath,
          ),
        ),
      );
    });

    test('rejects entry-count limits before extraction', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final archive = Archive()
        ..addFile(ArchiveFile.string('a.txt', 'a'))
        ..addFile(ArchiveFile.string('b.txt', 'b'));
      final source = await fixture.writeArchive(archive);

      await expectLater(
        () => const BackupArchiveParser(
          limits: BackupArchiveLimits(maxEntryCount: 1),
        ).parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.archiveLimitExceeded,
          ),
        ),
      );
    });
  });

  group('traditional Slclash adapters', () {
    test('imports profiles_only_v2 used by v2.0.1', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final profile = Profile(
        id: 1001,
        label: 'v2 profile',
        url: 'https://subscription.example/config',
        autoUpdateDuration: defaultUpdateDuration,
      );
      final metadata = <String, Object?>{
        'backupType': profilesBackupTypeV2,
        'createdAt': DateTime.utc(2026, 7, 15).toIso8601String(),
        'appVersion': '2.0.1',
        'currentProfileId': profile.id,
        'profiles': [profile.toJson()],
        'scripts': <Object?>[],
        'rules': <Object?>[],
        'links': <Object?>[],
      };
      final source = await fixture.writeZip({
        profilesBackupMetadataName: utf8.encode(json.encode(metadata)),
        'profiles/${profile.id}.yaml': utf8.encode(
          'proxies: []\nproxy-groups: []\nrules: []\n',
        ),
      });

      final model = await const BackupArchiveParser().parse(
        source,
        stagingDirectory: fixture.staging,
      );
      addTearDown(model.dispose);

      expect(model.format, BackupArchiveFormat.profilesV2);
      expect(model.currentProfileId, profile.id);
      expect(model.profiles.single.label, profile.label);
    });

    test('imports profiles_only_v1 with stable defaults', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final metadata = <String, Object?>{
        'backupType': profilesBackupType,
        'createdAt': DateTime.utc(2025).toIso8601String(),
        'appVersion': '1.9.0',
        'currentProfileId': 7,
        'profiles': [
          <String, Object?>{
            'id': 7,
            'label': 'legacy',
            'url': '',
          },
        ],
      };
      final source = await fixture.writeZip({
        profilesBackupMetadataName: utf8.encode(json.encode(metadata)),
        'profiles/7.yaml': utf8.encode(
          'proxies: []\nproxy-groups: []\nrules: []\n',
        ),
      });

      final model = await const BackupArchiveParser().parse(
        source,
        stagingDirectory: fixture.staging,
      );
      addTearDown(model.dispose);

      expect(model.format, BackupArchiveFormat.profilesV1);
      expect(
        model.profiles.single.autoUpdateDuration,
        defaultUpdateDuration,
      );
      expect(model.profiles.single.overwriteType, OverwriteType.standard);
    });

    test('rejects unknown traditional backup versions', () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final source = await fixture.writeZip({
        profilesBackupMetadataName: utf8.encode(
          json.encode({
            'backupType': 'profiles_only_v99',
            'profiles': <Object?>[],
          }),
        ),
      });

      await expectLater(
        () => const BackupArchiveParser().parse(
          source,
          stagingDirectory: fixture.staging,
        ),
        throwsA(
          isA<BackupRestoreException>().having(
            (error) => error.code,
            'code',
            BackupRestoreErrorCode.unsupportedVersion,
          ),
        ),
      );
    });
  });
}

Map<String, List<int>> _buildWorkerEntries({
  int formatVersion = 1,
  String? profileUrl,
}) {
  const uid = '0123456789abcdef';
  const slug = 'airport-a';
  final url = profileUrl ??
      '$unifiedSubscriptionWorkerBaseUrl/config/$slug/download-token';
  final config = utf8.encode('''
proxy-providers:
  $slug:
    type: http
    url: $unifiedSubscriptionWorkerBaseUrl/provider/$slug/download-token
''');
  final verge = utf8.encode('{}\n');
  final profiles = utf8.encode('''
current: $uid
items:
  - uid: $uid
    type: remote
    name: Airport A
    file: $uid.yaml
    url: $url
    updated: 1784073600
    option:
      allow_auto_update: true
      update_interval: 1440
    extra:
      upload: 1
      download: 2
      total: 3
      expire: 0
''');
  final profile = utf8.encode(
    'proxies: []\nproxy-groups: []\nrules: []\n',
  );
  final provider = utf8.encode('proxies: []\n');
  final meta = utf8.encode('{}');

  final files = <String, List<int>>{
    'config.yaml': config,
    'verge.yaml': verge,
    'profiles.yaml': profiles,
    'profiles/$uid.yaml': profile,
    'providers/$slug/provider.yaml': provider,
    'providers/$slug/profile.yaml': profile,
    'providers/$slug/meta.json': meta,
  };
  final manifestFiles = <String, Object?>{
    for (final entry in files.entries)
      entry.key: <String, Object?>{
        'sha256': sha256.convert(entry.value).toString(),
        'contentLength': entry.value.length,
        'required': entry.key == 'config.yaml' ||
            entry.key == 'verge.yaml' ||
            entry.key == 'profiles.yaml' ||
            entry.key.startsWith('profiles/'),
      },
  };
  final manifest = <String, Object?>{
    'format': 'mihomo-unified-backup',
    'formatVersion': formatVersion,
    'archiveType': 'unified-subscription-archive',
    'createdAt': DateTime.utc(2026, 7, 15).toIso8601String(),
    'generator': 'worker',
    'generatorVersion': '1.0.0',
    'publicBaseUrl': unifiedSubscriptionWorkerBaseUrl,
    'mainConfig': <String, Object?>{
      'configId': 'main',
      'versionId': 'v1',
      'name': 'main',
      'sourceSha256': sha256.convert(config).toString(),
    },
    'airports': [
      <String, Object?>{
        'slug': slug,
        'subscriptionId': 'redacted-test-id',
        'name': 'Airport A',
        'profileUid': uid,
        'versionId': 'v1',
        'nodeCount': 0,
        'providerSha256': sha256.convert(provider).toString(),
        'profileSha256': sha256.convert(profile).toString(),
      },
    ],
    'files': manifestFiles,
  };
  files['manifest.json'] = utf8.encode(json.encode(manifest));
  return files;
}

class _Fixture {
  _Fixture(this.root);

  final Directory root;

  Directory get staging => Directory('${root.path}/staging');

  static Future<_Fixture> create() async {
    return _Fixture(
      await Directory.systemTemp.createTemp('slclash-backup-test-'),
    );
  }

  Future<File> writeZip(Map<String, List<int>> entries) async {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(
        ArchiveFile.bytes(entry.key, entry.value),
      );
    }
    return writeArchive(archive);
  }

  Future<File> writeArchive(Archive archive) async {
    final bytes = ZipEncoder().encode(archive);
    final file = File('${root.path}/backup.zip');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
