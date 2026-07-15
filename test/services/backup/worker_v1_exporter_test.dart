import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/services/backup/worker_v1_exporter.dart';
import 'package:fl_clash/services/backup/worker_v1_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exporter = WorkerV1Exporter();

  WorkerV1ExportProfile profile(int id, String slug) => WorkerV1ExportProfile(
    id: id,
    name: 'Airport $id',
    url: 'https://vault.example/config/$slug/fixed-token-$id',
    yaml: Uint8List.fromList(utf8.encode('proxies: []\n')),
  );

  test('exports exact minimal compatibility config and manifest metadata', () {
    final package = const WorkerV1Parser().parse(
      exporter.export(
        profiles: [profile(1, 'one')],
        currentProfileId: 1,
        createdAt: DateTime.utc(2026, 7, 15),
      ),
    );
    final bytes = package.files['config.yaml']!;
    final entry = package.manifest.files['config.yaml']!;

    expect(utf8.decode(bytes), workerV1CompatibilityConfig);
    expect(bytes.last, 10);
    expect(sha256.convert(bytes).toString(), workerV1CompatibilityConfigSha256);
    expect(entry.sha256, workerV1CompatibilityConfigSha256);
    expect(entry.contentLength, bytes.length);
    expect(package.manifest.raw['mainConfig'], {
      'configId': 'system-minimal-compat',
      'versionId': 'sha256-451444cc8d6401ec',
      'name': 'Clash Verge compatibility config',
      'sourceSha256': workerV1CompatibilityConfigSha256,
    });
  });

  test('rebuilds profiles from the current subscription list', () {
    final before = const WorkerV1Parser().parse(
      exporter.export(profiles: [profile(1, 'one')], currentProfileId: 1),
    );
    final after = const WorkerV1Parser().parse(
      exporter.export(
        profiles: [profile(2, 'two'), profile(3, 'three')],
        currentProfileId: 3,
      ),
    );

    expect((before.profilesYaml['items'] as List), hasLength(1));
    expect(
      (after.profilesYaml['items'] as List).map((item) => (item as Map)['url']),
      [
        'https://vault.example/config/two/fixed-token-2',
        'https://vault.example/config/three/fixed-token-3',
      ],
    );
    expect(after.profilesYaml['current'], 'R00000003');
    expect(after.files, isNot(contains('profiles/R00000001.yaml')));
  });

  test('Slclash generated Worker archive round trips through the parser', () {
    final first = exporter.export(
      profiles: [profile(0x1234abcd, 'example')],
      currentProfileId: 0x1234abcd,
    );
    final parsed = const WorkerV1Parser().parse(first);
    final item = (parsed.profilesYaml['items'] as List).single as Map;
    final second = exporter.export(
      profiles: [
        WorkerV1ExportProfile(
          id: 0x1234abcd,
          name: item['name'] as String,
          url: item['url'] as String,
          yaml: Uint8List.fromList(parsed.files['profiles/R1234abcd.yaml']!),
        ),
      ],
      currentProfileId: 0x1234abcd,
    );

    expect(
      const WorkerV1Parser().parse(second).profilesYaml,
      parsed.profilesYaml,
    );
  });
}
