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

  group('runtime base selection', () {
    test('falls back to normalized config when source parsing fails', () async {
      final normalized = <String, dynamic>{'mode': 'rule'};
      Object? reportedError;
      final result = await resolveMihomoRuntimeBase(
        normalizedConfig: normalized,
        preserveSource: true,
        loadSourceConfig: () async => parseMihomoSourceConfig('['),
        onPreservationFailure: (error, _) => reportedError = error,
      );
      expect(identical(result, normalized), isTrue);
      expect(reportedError, isA<Object>());
    });

    test('falls back when source YAML root is unusable', () async {
      final normalized = <String, dynamic>{'mode': 'rule'};
      final result = await resolveMihomoRuntimeBase(
        normalizedConfig: normalized,
        preserveSource: true,
        loadSourceConfig: () async => parseMihomoSourceConfig('- invalid-root'),
      );
      expect(identical(result, normalized), isTrue);
    });

    test('Script path does not read or apply the source overlay', () async {
      final normalized = <String, dynamic>{'mode': 'rule'};
      var sourceReads = 0;
      final result = await resolveMihomoRuntimeBase(
        normalizedConfig: normalized,
        preserveSource: false,
        loadSourceConfig: () async {
          sourceReads++;
          return {'x-source-only': true};
        },
      );
      expect(identical(result, normalized), isTrue);
      expect(sourceReads, 0);
      expect(result, isNot(contains('x-source-only')));
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

    test('keeps existing whole-map DNS override behavior', () async {
      final runtimeBase = mergeSourceWithNormalized(
        {
          'dns': {
            'enable': true,
            'future-dns-option': 'removed-by-current-override',
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
      expect(runtime['dns'], isNot(contains('future-dns-option')));
    });
  });
}
