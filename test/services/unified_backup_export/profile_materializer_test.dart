import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/string.dart';
import 'package:fl_clash/services/unified_backup_export/profile_materializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main() {
  test('returns an inline profile unchanged', () async {
    final bytes = Uint8List.fromList(
      utf8.encode('proxies:\n  - {name: inline, type: ss}\n'),
    );
    final result = await materializeProfileForUnifiedExport(
      profileId: 1,
      profileBytes: bytes,
      profilesDirectory: 'unused',
    );
    expect(result, bytes);
  });

  test('materializes complete cached Provider nodes and group uses', () async {
    final directory = await Directory.systemTemp.createTemp('materializer-');
    addTearDown(() => directory.delete(recursive: true));
    const url = 'https://one-time.example/subscription';
    final cache = File(
      p.join(directory.path, 'providers', '7', 'proxies', url.toMd5()),
    );
    await cache.parent.create(recursive: true);
    await cache.writeAsString('''
proxies:
  - name: first
    type: ss
    server: 1.2.3.4
    port: 443
    cipher: aes-128-gcm
    password: secret
  - name: second
    type: trojan
    server: example.com
    port: 443
    password: secret-2
''');
    final source = Uint8List.fromList(
      utf8.encode('''
proxies:
  - name: inline
    type: ss
    server: 127.0.0.1
    port: 443
    cipher: aes-128-gcm
    password: local
proxy-providers:
  airport:
    type: http
    url: $url
proxy-groups:
  - name: Select
    type: select
    use: [airport]
rules: []
'''),
    );

    final result = await materializeProfileForUnifiedExport(
      profileId: 7,
      profileBytes: source,
      profilesDirectory: directory.path,
    );
    final yaml = loadYaml(utf8.decode(result)) as YamlMap;
    expect(yaml.containsKey('proxy-providers'), isFalse);
    expect(yaml['proxies'], hasLength(3));
    expect(yaml['proxies'][1]['server'], '1.2.3.4');
    expect(yaml['proxy-groups'][0].containsKey('use'), isFalse);
    expect(yaml['proxy-groups'][0]['proxies'], ['first', 'second']);
    expect(utf8.decode(result), isNot(contains(url)));
  });

  test('fails explicitly when declared Provider cache is unavailable', () {
    final source = Uint8List.fromList(
      utf8.encode('''
proxy-providers:
  burned:
    type: http
    url: https://expired.example/subscription
'''),
    );

    expect(
      () => materializeProfileForUnifiedExport(
        profileId: 9,
        profileBytes: source,
        profilesDirectory: 'missing',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('burned'),
        ),
      ),
    );
  });
}
