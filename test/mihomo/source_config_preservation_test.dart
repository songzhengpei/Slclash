import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/mihomo_config/source_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('source-preserving normalized overlay', () {
    test('preserves source-only top-level field after normalization', () {
      final result = mergeSourceWithNormalized(
        {'x-future-option': 'kept'},
        {'mode': 'rule'},
      );
      expect(result['x-future-option'], 'kept');
      expect(result['mode'], 'rule');
    });

    test('preserves unknown nested DNS and TUN siblings', () {
      final result = mergeSourceWithNormalized(
        {
          'dns': {'future-dns-option': 'kept', 'enable': false},
          'tun': {'future-tun-option': 'kept', 'enable': true},
        },
        {
          'dns': {'enable': true},
          'tun': {'enable': false},
        },
      );
      expect(result['dns']['future-dns-option'], 'kept');
      expect(result['tun']['future-tun-option'], 'kept');
    });

    test('normalized scalar and nested values win over source', () {
      final result = mergeSourceWithNormalized(
        {
          'mode': 'direct',
          'dns': {'enable': false, 'listen': '127.0.0.1:53'},
        },
        {
          'mode': 'rule',
          'dns': {'enable': true},
        },
      );
      expect(result['mode'], 'rule');
      expect(result['dns']['enable'], isTrue);
      expect(result['dns']['listen'], '127.0.0.1:53');
    });

    test('retains normalized default-populated fields', () {
      final result = mergeSourceWithNormalized(
        {'mode': 'direct'},
        {
          'mode': 'rule',
          'ipv6': false,
          'allow-lan': false,
          'dns': {'enable': true},
        },
      );
      expect(result['ipv6'], isFalse);
      expect(result['allow-lan'], isFalse);
      expect(result['dns']['enable'], isTrue);
    });

    test('normalized null explicitly replaces source value', () {
      final result = mergeSourceWithNormalized(
        {'global-ua': 'source-UA'},
        {'global-ua': null},
      );
      expect(result, containsPair('global-ua', null));
    });

    test('normalized list replaces the complete source list', () {
      final result = mergeSourceWithNormalized(
        {
          'rules': ['DOMAIN,source.example,DIRECT'],
        },
        {
          'rules': ['MATCH,DIRECT'],
        },
      );
      expect(result['rules'], ['MATCH,DIRECT']);
    });

    test('source-only list survives when normalized omits its key', () {
      final result = mergeSourceWithNormalized({
        'future-list': [
          'one',
          {'nested': 'two'},
        ],
      }, const {});
      expect(result['future-list'], [
        'one',
        {'nested': 'two'},
      ]);
    });

    test('does not mutate either input map or nested collection', () {
      final source = {
        'dns': {
          'future': 'kept',
          'nameserver': ['source'],
        },
      };
      final normalized = {
        'dns': {
          'nameserver': ['normalized'],
        },
      };
      final result = mergeSourceWithNormalized(source, normalized);
      (result['dns']['nameserver'] as List).add('result-only');
      result['dns']['future'] = 'changed-result';

      expect(source['dns'], {
        'future': 'kept',
        'nameserver': ['source'],
      });
      expect(normalized['dns'], {
        'nameserver': ['normalized'],
      });
    });
  });

  group('source YAML parsing', () {
    test('converts YamlMap and YamlList to plain Dart structures', () {
      final result = parseMihomoSourceConfig('''
future-map:
  enabled: true
  values:
    - one
    - nested: 2
nullable: null
''');
      expect(result, isA<Map<String, dynamic>>());
      expect(result['future-map'], isA<Map<String, dynamic>>());
      expect(result['future-map']['values'], isA<List<dynamic>>());
      expect(result['future-map']['values'][1], isA<Map<String, dynamic>>());
      expect(result['nullable'], isNull);
    });

    test('rejects a non-map YAML root', () {
      expect(
        () => parseMihomoSourceConfig('- not\n- a\n- config'),
        throwsFormatException,
      );
    });
  });

  group('single snapshot runtime base', () {
    test('source parse and normalization consume the exact same bytes', () async {
      final snapshot = utf8.encode('''
mode: rule
dns:
  enable: true
  nameserver: [system://]
''');
      List<int>? normalizedBytes;
      final result = await resolveSnapshotRuntimeBase(
        loadSnapshot: () async => snapshot,
        normalizeSnapshot: (bytes) async {
          normalizedBytes = bytes;
          return {'mode': 'rule', 'dns': {'enable': true}};
        },
        fallbackNormalized: () async => {'mode': 'direct'},
      );
      expect(normalizedBytes, snapshot);
      expect(result['mode'], 'rule');
      expect(result['dns']['nameserver'], ['system://']);
    });

    test(
      'uses only the captured snapshot even if the file changes later',
      () async {
        // Simulates: snapshot read at T1, profile file replaced at T2. The
        // runtime result must come entirely from the T1 snapshot; the
        // normalized side must never trigger a second file read.
        final snapshot = utf8.encode('''
mode: rule
x-snapshot-marker: version-A
''');
        var reads = 0;
        final result = await resolveSnapshotRuntimeBase(
          loadSnapshot: () async {
            reads++;
            return snapshot;
          },
          normalizeSnapshot: (bytes) async {
            expect(bytes, snapshot);
            return {'mode': 'rule'};
          },
          fallbackNormalized: () async => {'mode': 'direct'},
        );
        expect(reads, 1);
        expect(result['x-snapshot-marker'], 'version-A');
        expect(result['mode'], 'rule');
      },
    );

    test('falls back to normalized-only when the snapshot read fails', () async {
      Object? reportedError;
      final result = await resolveSnapshotRuntimeBase(
        loadSnapshot: () async => throw const FileSystemException('read'),
        normalizeSnapshot: (_) async => {'mode': 'rule'},
        fallbackNormalized: () async => {'mode': 'direct'},
        onPreservationFailure: (error, _) => reportedError = error,
      );
      expect(result, {'mode': 'direct'});
      expect(reportedError, isA<Object>());
    });

    test('falls back to normalized-only when source YAML is unparsable',
        () async {
      final result = await resolveSnapshotRuntimeBase(
        loadSnapshot: () async => utf8.encode('['),
        normalizeSnapshot: (_) async => {'mode': 'rule'},
        fallbackNormalized: () async => {'mode': 'direct'},
      );
      expect(result, {'mode': 'direct'});
    });

    test(
      'falls back to normalized-only when Core normalization fails '
      'without overlaying stale source',
      () async {
        final snapshot = utf8.encode('''
x-stale-source-field: version-B
''');
        Object? reportedError;
        final result = await resolveSnapshotRuntimeBase(
          loadSnapshot: () async => snapshot,
          normalizeSnapshot: (_) async =>
              throw StateError('core normalization failed'),
          fallbackNormalized: () async => {'mode': 'direct'},
          onPreservationFailure: (error, _) => reportedError = error,
        );
        expect(result, {'mode': 'direct'});
        expect(result, isNot(contains('x-stale-source-field')));
        expect(reportedError, isA<StateError>());
      },
    );

    test('normalizes a large-ish snapshot end to end', () async {
      final snapshot = utf8.encode('''
mode: rule
ipv6: true
proxies:
  - name: p1
    type: ss
    server: 1.1.1.1
    port: 8388
    cipher: aes-128-gcm
    password: secret1
  - name: p2
    type: ss
    server: 2.2.2.2
    port: 8388
    cipher: aes-128-gcm
    password: secret2
proxy-groups:
  - name: PROXY
    type: select
    proxies: [p1, p2]
rules:
  - DOMAIN,example.com,PROXY
  - MATCH,DIRECT
''');
      final result = await resolveSnapshotRuntimeBase(
        loadSnapshot: () async => snapshot,
        normalizeSnapshot: (bytes) async {
          final source = parseMihomoSourceConfig(utf8.decode(bytes));
          return {
            'mode': source['mode'],
            'rules': source['rules'],
          };
        },
        fallbackNormalized: () async => {'mode': 'direct'},
      );
      expect(result['mode'], 'rule');
      expect(result['rules'], ['DOMAIN,example.com,PROXY', 'MATCH,DIRECT']);
      expect(result['proxies'], hasLength(2));
      expect(result['proxy-groups'], hasLength(1));
    });
  });

  group('runtime materialization boundary', () {
    test(
      'restores source-only fields before current runtime patches',
      () async {
        final source = parseMihomoSourceConfig(
          File(
            p.join(
              'test',
              'fixtures',
              'mihomo',
              'synthetic_unknown_fields.yaml',
            ),
          ).readAsStringSync(),
        );
        final normalized = <String, dynamic>{
          'dns': {
            'enable': true,
            'nameserver': ['system://'],
          },
          'tun': {'enable': false, 'stack': 'mixed'},
          'rules': ['MATCH,DIRECT'],
        };
        final runtimeBase = mergeSourceWithNormalized(source, normalized);
        final output = await makeRealProfileTask(
          MakeRealProfileState(
            profilesPath: p.join('runtime', 'profiles'),
            profileId: 42,
            rawConfig: runtimeBase,
            realPatchConfig: const PatchClashConfig(),
            overrideDns: false,
            appendSystemDns: false,
            proxyGroups: const [],
            rules: const [],
            addedRules: const [],
            defaultUA: 'Slclash-test-UA',
          ),
        );
        final runtime = parseMihomoSourceConfig(output.a);
        expect(runtime['x-slclash-test-field'], 'top-level');
        expect(runtime['dns']['future-dns-option'], 'dns-sibling');
        expect(runtime['tun']['future-option'], 'tun-sibling');
        expect(runtime['tun']['enable'], isFalse);
      },
    );

    test('DNS override keeps unowned DNS siblings', () async {
      final runtimeBase = mergeSourceWithNormalized(
        {
          'dns': {
            'enable': true,
            'future-dns-option': 'kept-by-owned-patch',
          },
          'rules': ['MATCH,DIRECT'],
        },
        {
          'dns': {'enable': true},
          'rules': ['MATCH,DIRECT'],
        },
      );
      final output = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: p.join('runtime', 'profiles'),
          profileId: 42,
          rawConfig: runtimeBase,
          realPatchConfig: const PatchClashConfig(),
          overrideDns: true,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'Slclash-test-UA',
        ),
      );
      final runtime = parseMihomoSourceConfig(output.a);
      // Phase 2B: the Slclash DNS patch is ownership-aware; unowned siblings
      // are no longer dropped by a whole-map replacement.
      expect(runtime['dns']['future-dns-option'], 'kept-by-owned-patch');
    });
  });
}
