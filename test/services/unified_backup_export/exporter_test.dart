import 'dart:convert';
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
    final manifestFiles = parsed.manifest.files.keys.toSet();
    expect(manifestFiles, names.difference({'manifest.json'}));
    },
  );

  test('fails explicitly without a trusted Worker baseline', () {
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

List<int> _trustedArchive() {
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
      'url': '$unifiedBackupPublicBaseUrl/config/$slug/fixed-token',
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
    'publicBaseUrl': unifiedBackupPublicBaseUrl,
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
