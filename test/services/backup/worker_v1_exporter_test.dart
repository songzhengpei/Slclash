import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/services/backup/backup_error.dart';
import 'package:fl_clash/services/backup/worker_v1_exporter.dart';
import 'package:fl_clash/services/backup/worker_v1_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exporter = WorkerV1Exporter();

  test('exports exact minimal config while preserving trusted identity', () {
    final trusted = const WorkerV1Parser().parse(_capsule());
    final package = const WorkerV1Parser().parse(
      exporter.export(
        profiles: const [
          WorkerV1ExportProfile(
            name: 'Renamed',
            url: 'https://vault.example/config/example/fixed-token',
          ),
        ],
        currentProfileUrl: 'https://vault.example/config/example/fixed-token',
        trustedPackages: [trusted],
        createdAt: DateTime.utc(2026, 7, 15),
      ),
    );
    final bytes = package.files['config.yaml']!;
    final entry = package.manifest.files['config.yaml']!;

    expect(utf8.decode(bytes), workerV1CompatibilityConfig);
    expect(bytes.last, 10);
    expect(entry.sha256, workerV1CompatibilityConfigSha256);
    expect(entry.contentLength, bytes.length);
    expect(package.manifest.airports.single['subscriptionId'], 'sub-real');
    expect(package.manifest.airports.single['profileUid'], 'R1234abcd');
    expect(package.manifest.airports.single['versionId'], 'version-real');
    expect(
      package.files['providers/example/meta.json'],
      trusted.files['providers/example/meta.json'],
    );
  });

  test('copies provider and profile raw artifacts without synthesis', () {
    final trusted = const WorkerV1Parser().parse(_capsule());
    final package = const WorkerV1Parser().parse(
      exporter.export(
        profiles: const [
          WorkerV1ExportProfile(
            name: 'Example',
            url: 'https://vault.example/config/example/fixed-token',
          ),
        ],
        currentProfileUrl: null,
        trustedPackages: [trusted],
      ),
    );

    for (final path in [
      'providers/example/provider.yaml',
      'providers/example/profile.yaml',
      'providers/example/meta.json',
      'profiles/R1234abcd.yaml',
    ]) {
      expect(package.files[path], trusted.files[path]);
      final manifest = package.manifest.files[path]!;
      expect(manifest.contentLength, package.files[path]!.length);
      expect(manifest.sha256, sha256.convert(package.files[path]!).toString());
    }
    expect(
      utf8.decode(package.files['providers/example/provider.yaml']!),
      'proxies:\n  - {name: node, type: direct}\n',
    );
    expect(
      utf8.decode(package.files['providers/example/profile.yaml']!),
      contains('proxy-groups:'),
    );
    expect(
      jsonDecode(utf8.decode(package.files['providers/example/meta.json']!)),
      isNot(isEmpty),
    );
  });

  test('refuses a fixed URL without Worker-issued metadata', () {
    expect(
      () => exporter.export(
        profiles: const [
          WorkerV1ExportProfile(
            name: 'Untrusted',
            url: 'https://vault.example/config/example/fixed-token',
          ),
        ],
        currentProfileUrl: null,
        trustedPackages: const [],
      ),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.code,
          'code',
          BackupErrorCode.missingTrustedMetadata,
        ),
      ),
    );
  });
}

List<int> _capsule() {
  final files = <String, List<int>>{
    'config.yaml': utf8.encode('mixed-port: 7890\n'),
    'verge.yaml': utf8.encode('{}\n'),
    'profiles.yaml': utf8.encode('''
current: R1234abcd
items:
  - uid: R1234abcd
    type: remote
    name: Example
    file: R1234abcd.yaml
    url: https://vault.example/config/example/fixed-token
'''),
    'profiles/R1234abcd.yaml': utf8.encode('''
proxies:
  - {name: node, type: direct}
proxy-groups:
  - {name: select, type: select, proxies: [node]}
'''),
    'providers/example/provider.yaml': utf8.encode(
      'proxies:\n  - {name: node, type: direct}\n',
    ),
    'providers/example/profile.yaml': utf8.encode('''
proxies:
  - {name: node, type: direct}
proxy-groups:
  - {name: select, type: select, proxies: [node]}
'''),
    'providers/example/meta.json': utf8.encode(
      '{"formatVersion":1,"subscriptionId":"sub-real","versionId":"version-real"}\n',
    ),
  };
  final manifest = {
    'format': 'mihomo-unified-backup',
    'formatVersion': 1,
    'archiveType': 'unified-subscription-archive',
    'createdAt': '2026-07-15T00:00:00Z',
    'generator': 'worker',
    'generatorVersion': '1.0.0',
    'publicBaseUrl': 'https://vault.example',
    'mainConfig': {
      'configId': 'legacy',
      'versionId': 'legacy',
      'name': 'Legacy',
      'sourceSha256': '1' * 64,
    },
    'airports': [
      {
        'slug': 'example',
        'subscriptionId': 'sub-real',
        'name': 'Example',
        'profileUid': 'R1234abcd',
        'versionId': 'version-real',
        'nodeCount': 1,
        'providerSha256': sha256
            .convert(files['providers/example/provider.yaml']!)
            .toString(),
        'profileSha256': sha256
            .convert(files['providers/example/profile.yaml']!)
            .toString(),
      },
    ],
    'files': {
      for (final entry in files.entries)
        entry.key: {
          'sha256': sha256.convert(entry.value).toString(),
          'contentLength': entry.value.length,
          'required':
              entry.key == 'config.yaml' ||
              entry.key == 'verge.yaml' ||
              entry.key == 'profiles.yaml' ||
              entry.key.startsWith('profiles/'),
        },
    },
  };
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
  return ZipEncoder().encode(archive);
}
