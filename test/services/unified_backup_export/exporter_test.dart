import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/services/backup/worker_v1_parser.dart';
import 'package:fl_clash/services/unified_backup_export/exporter.dart';
import 'package:fl_clash/services/unified_backup_export/identity.dart';
import 'package:fl_clash/services/unified_backup_export/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'builds one native V1 snapshot for four Worker and one local profile',
    () {
      final trusted = Uint8List.fromList(_trustedArchive());
      final profiles = List.generate(5, (index) {
        final id = index < 4 ? 0x10000000 + index : 999999999;
        return UnifiedExportProfile(
          androidId: id,
          name: index == 4 ? '备用' : 'Worker $index',
          yaml: Uint8List.fromList(utf8.encode(_profileYaml(index))),
          updated: 1700000000 + index,
          autoUpdate: true,
          updateIntervalMinutes: 120,
          subscriptionInfo: const {
            'upload': 1,
            'download': 2,
            'total': 3,
            'expire': 4,
          },
          localFile: index == 4,
        );
      });
      final input = UnifiedExportInput(
        profiles: profiles,
        currentAndroidId: profiles.last.androidId,
        trustedArchive: trusted,
        generatorVersion: '1.0.0',
        createdAt: DateTime.utc(2026, 7, 17),
      );
      final first = const UnifiedV1Exporter().build(input);
      final second = const UnifiedV1Exporter().build(input);
      expect(first, second);

      final parsed = const WorkerV1Parser().parse(first);
      final names = parsed.files.keys.toSet();
      expect(parsed.manifest.raw['generator'], 'slclash');
      expect(parsed.manifest.airports, hasLength(5));
      expect(parsed.profilesYaml['items'], hasLength(5));
      expect(
        parsed.profilesYaml['current'],
        deriveUnifiedIdentity(999999999).profileUid,
      );
      expect(names, isNot(contains('metadata.json')));
      expect(
        names.any((name) => name.startsWith('subscription-center/')),
        false,
      );
      expect(
        names.any((name) => name.startsWith('profiles/providers/')),
        false,
      );
      expect(
        utf8.decode(first, allowMalformed: true),
        isNot(contains('airport.example')),
      );

      final local = parsed.manifest.airports.last;
      final slug = local['slug'] as String;
      final uid = local['profileUid'] as String;
      expect(
        parsed.files['profiles/$uid.yaml'],
        parsed.files['providers/$slug/profile.yaml'],
      );
      expect(
        utf8.decode(parsed.files['providers/$slug/provider.yaml']!),
        contains('node-4'),
      );
      final localMeta =
          jsonDecode(utf8.decode(parsed.files['providers/$slug/meta.json']!))
              as Map<String, dynamic>;
      expect(localMeta['distribution']['clientUpdatePolicy'], {
        'allowAutoUpdate': true,
        'updateIntervalMinutes': 120,
      });
      expect(localMeta['distribution']['sourceType'], 'local');
      expect(
        localMeta['distribution'],
        isNot(contains('profileUpdateInterval')),
      );
      final manifestFiles = parsed.manifest.files.keys.toSet();
      expect(manifestFiles, names.difference({'manifest.json'}));
    },
  );

  test('builds a standalone V1 snapshot without a Worker baseline', () {
    final profile = UnifiedExportProfile(
      androidId: 1,
      name: 'Standalone',
      yaml: Uint8List.fromList(utf8.encode(_profileYaml(0))),
      updated: 0,
      autoUpdate: true,
      updateIntervalMinutes: 60,
    );
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: [profile],
        currentAndroidId: profile.androidId,
        generatorVersion: '1.0.0',
        createdAt: DateTime.utc(2026, 7, 19),
      ),
    );
    final parsed = const WorkerV1Parser().parse(bytes);
    expect(
      parsed.manifest.raw['publicBaseUrl'],
      standaloneUnifiedBackupBaseUrl,
    );
    final item = (parsed.profilesYaml['items'] as List).single as Map;
    expect(item['type'], 'remote');
    expect(item['url'], startsWith('$standaloneUnifiedBackupBaseUrl/config/'));
    expect(item['option'], {'allow_auto_update': false, 'update_interval': 60});
    expect(parsed.manifest.raw['mainConfig'], {
      'configId': 'slclash-standalone',
      'versionId': startsWith('sha256-'),
      'name': 'Slclash standalone snapshot',
      'sourceSha256': matches(RegExp(r'^[0-9a-f]{64}$')),
    });
  });

  test('rejects an invalid non-empty trusted baseline', () {
    expect(
      () => const UnifiedV1Exporter().build(
        UnifiedExportInput(
          profiles: [
            UnifiedExportProfile(
              androidId: 1,
              name: 'x',
              yaml: Uint8List.fromList(utf8.encode(_profileYaml(0))),
              updated: 0,
              autoUpdate: true,
              updateIntervalMinutes: 60,
            ),
          ],
          currentAndroidId: 1,
          trustedArchive: Uint8List(0),
          generatorVersion: '1.0.0',
        ),
      ),
      throwsA(anything),
    );
  });

  test('preserves disabled auto update and rejects invalid intervals', () {
    final profile = UnifiedExportProfile(
      androidId: 999999999,
      name: '备用',
      yaml: Uint8List.fromList(utf8.encode(_profileYaml(4))),
      updated: 1700000000,
      autoUpdate: false,
      updateIntervalMinutes: 1440,
    );
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: [profile],
        currentAndroidId: profile.androidId,
        trustedArchive: Uint8List.fromList(_trustedArchive()),
        generatorVersion: '1.0.0',
        createdAt: DateTime.utc(2026, 7, 17),
      ),
    );
    final parsed = const WorkerV1Parser().parse(bytes);
    final item = (parsed.profilesYaml['items'] as List).single as Map;
    expect(item['option'], {
      'allow_auto_update': false,
      'update_interval': 1440,
    });

    expect(
      () => const UnifiedV1Exporter().build(
        UnifiedExportInput(
          profiles: [
            UnifiedExportProfile(
              androidId: 1,
              name: 'invalid',
              yaml: Uint8List(1),
              updated: 0,
              autoUpdate: false,
              updateIntervalMinutes: 0,
            ),
          ],
          currentAndroidId: 1,
          trustedArchive: Uint8List(0),
          generatorVersion: '1.0.0',
        ),
      ),
      throwsRangeError,
    );
  });

  test('generates the client policy cross-repository fixture', () {
    final profiles = [
      UnifiedExportProfile(
        androidId: 0x10000000,
        name: 'Worker Profile',
        yaml: Uint8List.fromList(utf8.encode(_profileYaml(0))),
        updated: 1700000000,
        autoUpdate: false,
        updateIntervalMinutes: 60,
      ),
      UnifiedExportProfile(
        androidId: 0x10000001,
        name: 'Slclash Remote',
        yaml: Uint8List.fromList(utf8.encode(_profileYaml(1))),
        updated: 1700000001,
        autoUpdate: true,
        updateIntervalMinutes: 1440,
      ),
      UnifiedExportProfile(
        androidId: 999999999,
        name: '备用',
        yaml: Uint8List.fromList(utf8.encode(_profileYaml(2))),
        updated: 1700000002,
        autoUpdate: false,
        updateIntervalMinutes: 1440,
      ),
    ];
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: profiles,
        currentAndroidId: profiles[1].androidId,
        trustedArchive: Uint8List.fromList(_trustedArchive()),
        generatorVersion: '1.0.0',
        createdAt: DateTime.utc(2026, 7, 17),
      ),
    );
    final output = Platform.environment['SLCLASH_CROSS_FIXTURE_OUT'];
    if (output != null && output.isNotEmpty) {
      File(output).writeAsBytesSync(bytes, flush: true);
    }
    final parsed = const WorkerV1Parser().parse(bytes);
    final items = parsed.profilesYaml['items'] as List;
    expect(items.map((item) => (item as Map)['option']).toList(), [
      {'allow_auto_update': false, 'update_interval': 60},
      {'allow_auto_update': true, 'update_interval': 1440},
      {'allow_auto_update': false, 'update_interval': 1440},
    ]);
  });

  test('accepts the custom domain as the same trusted Worker', () {
    final profile = UnifiedExportProfile(
      androidId: 0x10000000,
      name: 'Worker Profile',
      yaml: Uint8List.fromList(utf8.encode(_profileYaml(0))),
      updated: 1700000000,
      autoUpdate: false,
      updateIntervalMinutes: 60,
    );
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: [profile],
        currentAndroidId: profile.androidId,
        trustedArchive: Uint8List.fromList(
          _trustedArchive(publicBaseUrl: unifiedBackupCustomBaseUrl),
        ),
        generatorVersion: '1.0.0',
      ),
    );
    final parsed = const WorkerV1Parser().parse(bytes);
    expect(parsed.manifest.raw['publicBaseUrl'], unifiedBackupCustomBaseUrl);
    expect(
      ((parsed.profilesYaml['items'] as List).single as Map)['url'],
      startsWith('$unifiedBackupCustomBaseUrl/config/'),
    );
  });

  test(
    'reuses trusted identity by profile SHA after Verge import changes ID',
    () {
      final profile = UnifiedExportProfile(
        androidId: 987654321,
        name: 'Imported Worker 0',
        yaml: Uint8List.fromList(utf8.encode(_profileYaml(0))),
        updated: 1700000000,
        autoUpdate: true,
        updateIntervalMinutes: 60,
      );
      final bytes = const UnifiedV1Exporter().build(
        UnifiedExportInput(
          profiles: [profile],
          currentAndroidId: profile.androidId,
          trustedArchive: Uint8List.fromList(_trustedArchive()),
          generatorVersion: '1.0.0',
        ),
      );
      final parsed = const WorkerV1Parser().parse(bytes);
      final airport = parsed.manifest.airports.single;
      expect(airport['slug'], 'worker-0');
      expect(airport['subscriptionId'], 'subscription-0');
      expect(airport['profileUid'], 'R10000000');
      expect(parsed.profilesYaml['current'], 'R10000000');
    },
  );

  test('claims a SHA-matched trusted identity only once', () {
    final profiles = [
      for (final id in [987654321, 987654322])
        UnifiedExportProfile(
          androidId: id,
          name: 'Duplicate $id',
          yaml: Uint8List.fromList(utf8.encode(_profileYaml(0))),
          updated: 1700000000,
          autoUpdate: true,
          updateIntervalMinutes: 60,
        ),
    ];
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: profiles,
        currentAndroidId: profiles.first.androidId,
        trustedArchive: Uint8List.fromList(_trustedArchive()),
        generatorVersion: '1.0.0',
      ),
    );
    final parsed = const WorkerV1Parser().parse(bytes);
    expect(parsed.manifest.airports, hasLength(2));
    expect(parsed.manifest.airports.first['slug'], 'worker-0');
    expect(
      parsed.manifest.airports.last['slug'],
      deriveUnifiedIdentity(987654322).slug,
    );
  });

  test('reuses trusted identity by stable Verge UID after content changes', () {
    final profile = UnifiedExportProfile(
      androidId: deriveClashVergeProfileId('R10000000'),
      name: 'Updated Worker 0',
      yaml: Uint8List.fromList(utf8.encode(_profileYaml(99))),
      updated: 1700000000,
      autoUpdate: true,
      updateIntervalMinutes: 60,
    );
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: [profile],
        currentAndroidId: profile.androidId,
        trustedArchive: Uint8List.fromList(_trustedArchive()),
        generatorVersion: '1.0.0',
      ),
    );
    final airport = const WorkerV1Parser()
        .parse(bytes)
        .manifest
        .airports
        .single;
    expect(airport['slug'], 'worker-0');
    expect(airport['profileUid'], 'R10000000');
  });

  test('preserves visible dependency statistics and rewrites versions', () {
    final profiles = List.generate(3, (index) {
      return UnifiedExportProfile(
        androidId: 0x10000000 + index,
        name: 'Worker $index',
        yaml: Uint8List.fromList(utf8.encode(_profileYaml(index))),
        updated: 1700000000 + index,
        autoUpdate: false,
        updateIntervalMinutes: 60,
      );
    });
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: profiles,
        currentAndroidId: profiles.first.androidId,
        trustedArchive: Uint8List.fromList(
          _trustedArchive(includeDependencyStats: true),
        ),
        generatorVersion: '1.0.0',
      ),
    );
    final parsed = const WorkerV1Parser().parse(bytes);
    final parentMeta =
        jsonDecode(utf8.decode(parsed.files['providers/worker-0/meta.json']!))
            as Map<String, dynamic>;
    expect(parentMeta['schemaVersion'], 2);
    expect(parentMeta['nodeCount'], 3);
    expect(parentMeta['nodeStats'], {
      'dependencyRaw': 2,
      'effective': 3,
      'excluded': 0,
      'inline': 1,
    });
    final dependencies = parentMeta['internalDependencies'] as List;
    expect(dependencies, hasLength(2));
    for (final raw in dependencies.cast<Map>()) {
      final slug = raw['slug'] as String;
      final airport = parsed.manifest.airports.singleWhere(
        (value) => value['slug'] == slug,
      );
      expect(raw['versionId'], airport['versionId']);
      expect(raw['providerSha256'], airport['providerSha256']);
      expect(raw['profileSha256'], airport['profileSha256']);
    }
    expect(
      parsed.manifest.airports.singleWhere(
        (value) => value['slug'] == 'worker-0',
      )['nodeCount'],
      3,
    );
  });

  test('drops stale dependency statistics after Provider flattening', () {
    final flattened = UnifiedExportProfile(
      androidId: 0x10000000,
      name: 'Worker 0',
      yaml: Uint8List.fromList(
        utf8.encode('''proxies:
  - {name: inline, type: direct}
  - {name: dependency-1, type: direct}
  - {name: dependency-2, type: direct}
'''),
      ),
      updated: 1700000000,
      autoUpdate: false,
      updateIntervalMinutes: 60,
      externalProvidersFlattened: true,
    );
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: [flattened],
        currentAndroidId: flattened.androidId,
        trustedArchive: Uint8List.fromList(
          _trustedArchive(includeDependencyStats: true),
        ),
        generatorVersion: '1.0.0',
      ),
    );
    final parsed = const WorkerV1Parser().parse(bytes);
    final meta =
        jsonDecode(utf8.decode(parsed.files['providers/worker-0/meta.json']!))
            as Map<String, dynamic>;
    expect(meta['schemaVersion'], 1);
    expect(meta['nodeCount'], 3);
    expect(meta, isNot(contains('nodeStats')));
    expect(meta, isNot(contains('internalDependencies')));
  });
}

String _profileYaml(int index) =>
    '''proxies:
  - name: node-$index
    type: direct
proxy-groups:
  - name: select
    type: select
    proxies: [node-$index]
''';

List<int> _trustedArchive({
  String publicBaseUrl = unifiedBackupPublicBaseUrl,
  bool includeDependencyStats = false,
}) {
  final files = <String, List<int>>{
    'config.yaml': utf8.encode('mixed-port: 7890\nproxy-providers: {}\n'),
    'verge.yaml': utf8.encode('{}\n'),
  };
  final items = <Map<String, Object?>>[];
  final airports = <Map<String, Object?>>[];
  for (var i = 0; i < 4; i++) {
    final uid = 'R${(0x10000000 + i).toRadixString(16)}';
    final slug = 'worker-$i';
    final profile = utf8.encode(_profileYaml(i));
    final provider = utf8.encode(
      'proxies:\n  - name: node-$i\n    type: direct\n',
    );
    final profileHash = sha256.convert(profile).toString();
    final providerHash = sha256.convert(provider).toString();
    final version = 'sha256-${profileHash.substring(0, 16)}';
    items.add({
      'uid': uid,
      'type': 'remote',
      'name': 'Worker $i',
      'file': '$uid.yaml',
      'url': '$publicBaseUrl/config/$slug/fixed-token',
    });
    airports.add({
      'slug': slug,
      'subscriptionId': 'subscription-$i',
      'name': 'Worker $i',
      'profileUid': uid,
      'versionId': version,
      'nodeCount': 1,
      'providerSha256': providerHash,
      'profileSha256': profileHash,
    });
    files['profiles/$uid.yaml'] = profile;
    files['providers/$slug/provider.yaml'] = provider;
    files['providers/$slug/profile.yaml'] = profile;
    files['providers/$slug/meta.json'] = utf8.encode('{}');
  }
  if (includeDependencyStats) {
    final parent = airports[0];
    final dependencies = [
      for (final index in [1, 2])
        {
          'slug': airports[index]['slug'],
          'subscriptionId': airports[index]['subscriptionId'],
          'uid': airports[index]['profileUid'],
          'versionId': airports[index]['versionId'],
          'nodeCount': 1,
          'effectiveCount': 1,
          'excludedCount': 0,
          'providerSha256': airports[index]['providerSha256'],
          'profileSha256': airports[index]['profileSha256'],
        },
    ];
    files['providers/${parent['slug']}/meta.json'] = utf8.encode(
      jsonEncode({
        'schemaVersion': 2,
        'nodeStats': {
          'dependencyRaw': 2,
          'effective': 3,
          'excluded': 0,
          'inline': 1,
        },
        'internalDependencies': dependencies,
      }),
    );
  }
  files['profiles.yaml'] = utf8.encode('''current: R10000000
items:
${items.map((item) => '''  - uid: ${item['uid']}
    type: remote
    name: ${item['name']}
    file: ${item['file']}
    url: ${item['url']}
''').join()}''');
  final manifest = {
    'format': 'mihomo-unified-backup',
    'formatVersion': 1,
    'archiveType': 'unified-subscription-archive',
    'createdAt': '2026-07-17T00:00:00Z',
    'generator': 'worker',
    'generatorVersion': '1.0.0',
    'publicBaseUrl': publicBaseUrl,
    'mainConfig': {
      'configId': 'main',
      'versionId': 'v1',
      'name': 'main',
      'sourceSha256': '1' * 64,
    },
    'airports': airports,
    'files': {
      for (final entry in files.entries)
        entry.key: {
          'sha256': sha256.convert(entry.value).toString(),
          'contentLength': entry.value.length,
          'required':
              entry.key.startsWith('profiles/') ||
              const {
                'config.yaml',
                'profiles.yaml',
                'verge.yaml',
              }.contains(entry.key),
        },
    },
  };
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
  return ZipEncoder().encode(archive, level: 0);
}
