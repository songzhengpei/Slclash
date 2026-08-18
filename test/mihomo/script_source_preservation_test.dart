import 'dart:convert';

import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/mihomo_config/source_config.dart';
import 'package:fl_clash/services/mihomo_config/structural_config_diff.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates the Script evaluator contract: receives the normalized input map
/// and returns the transformed map. Production always routes through
/// handleEvaluate (lib/common/javascript.dart); host tests inject this
/// deterministic stand-in because QuickJS is not available on the test host.
typedef ScriptEvaluator = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> scriptInput,
);

class _ScriptHarness {
  _ScriptHarness({
    required this.source,
    required this.normalized,
    required this.script,
  });

  final Map<String, dynamic> source;
  final Map<String, dynamic> normalized;
  final ScriptEvaluator script;

  int evaluations = 0;
  Map<String, dynamic>? lastScriptInput;

  Future<Map<String, dynamic>> resolve() async {
    // JSON is a valid YAML subset, so the injected source travels through the
    // real snapshot -> parseMihomoSourceConfig path.
    final snapshot = utf8.encode(json.encode(source));
    return resolveScriptSnapshotRuntimeBase(
      loadSnapshot: () async => snapshot,
      normalizeSnapshot: (_) async => Map<String, dynamic>.from(normalized),
      fallbackNormalized: () async => Map<String, dynamic>.from(normalized),
      evaluateScript: (input) {
        evaluations++;
        lastScriptInput = input;
        return script(input);
      },
    );
  }
}

void main() {
  group('Script source preservation', () {
    test('1. source-only top-level field survives unrelated Script edits',
        () async {
      final harness = _ScriptHarness(
        source: {'x-source-only': 'kept', 'mode': 'rule'},
        normalized: {'mode': 'rule'},
        script: (input) async {
          input['mode'] = 'global';
          return input;
        },
      );
      final result = await harness.resolve();
      expect(result['x-source-only'], 'kept');
      expect(result['mode'], 'global');
    });

    test('2. source-only nested sibling survives known sibling edits',
        () async {
      final harness = _ScriptHarness(
        source: {
          'dns': {
            'enable': true,
            'nameserver': ['1.1.1.1'],
            'future-field': 'preserved',
          },
        },
        normalized: {
          'dns': {'enable': true, 'nameserver': ['1.1.1.1']},
        },
        script: (input) async {
          input['dns']['cache-algorithm'] = 'lru';
          return input;
        },
      );
      final result = await harness.resolve();
      expect(result['dns']['future-field'], 'preserved');
      expect(result['dns']['cache-algorithm'], 'lru');
      expect(result['dns']['nameserver'], ['1.1.1.1']);
    });

    test('3. Script delete removes known field, keeps unknown sibling',
        () async {
      final harness = _ScriptHarness(
        source: {
          'dns': {
            'enable': true,
            'nameserver': ['1.1.1.1'],
            'future-field': 'preserved',
          },
        },
        normalized: {
          'dns': {'enable': true, 'nameserver': ['1.1.1.1']},
        },
        script: (input) async {
          (input['dns'] as Map).remove('nameserver');
          return input;
        },
      );
      final result = await harness.resolve();
      expect(result['dns'], {
        'enable': true,
        'future-field': 'preserved',
      });
      expect((result['dns'] as Map).containsKey('nameserver'), isFalse);
    });

    test('4. Script delete of whole root map removes source-only descendants',
        () async {
      final harness = _ScriptHarness(
        source: {
          'dns': {
            'enable': true,
            'nameserver': ['1.1.1.1'],
            'future-field': 'preserved',
          },
        },
        normalized: {
          'dns': {'enable': true, 'nameserver': ['1.1.1.1']},
        },
        script: (input) async {
          input.remove('dns');
          return input;
        },
      );
      final result = await harness.resolve();
      expect(result.containsKey('dns'), isFalse);
    });

    test('5. Script explicit null wins', () async {
      final harness = _ScriptHarness(
        source: {'global-ua': 'source-UA'},
        normalized: {'global-ua': 'normalized-UA'},
        script: (input) async {
          input['global-ua'] = null;
          return input;
        },
      );
      final result = await harness.resolve();
      expect(result, containsPair('global-ua', null));
      expect(result.containsKey('global-ua'), isTrue);
    });

    test('6. Script list replacement wins', () async {
      final harness = _ScriptHarness(
        source: {
          'rules': ['DOMAIN,source.example,DIRECT'],
        },
        normalized: {
          'rules': ['MATCH,DIRECT'],
        },
        script: (input) async {
          input['rules'] = ['DOMAIN,new.example,PROXY'];
          return input;
        },
      );
      final result = await harness.resolve();
      expect(result['rules'], ['DOMAIN,new.example,PROXY']);
    });

    test('7. Script new map key survives into the runtime base', () async {
      final harness = _ScriptHarness(
        source: {'x-source-only': 'kept'},
        normalized: {'mode': 'rule'},
        script: (input) async {
          input['profile'] = {'store-selected': true};
          return input;
        },
      );
      final result = await harness.resolve();
      expect(result['profile'], {'store-selected': true});
      expect(result['x-source-only'], 'kept');
    });

    test('8. empty Script preserves source-only fields', () async {
      final harness = _ScriptHarness(
        source: {'x-source-only': 'kept', 'mode': 'rule'},
        normalized: {'mode': 'rule'},
        script: (input) async => input,
      );
      final result = await harness.resolve();
      expect(result['x-source-only'], 'kept');
      expect(result['mode'], 'rule');
    });

    test('9. DNS/TUN ownership still runs after the Script result', () async {
      final harness = _ScriptHarness(
        source: {
          'tun': {'enable': false, 'future-option': 'tun-future'},
        },
        normalized: {
          'tun': {'enable': false},
        },
        script: (input) async {
          (input['tun'] as Map)['enable'] = false;
          return input;
        },
      );
      final preserved = await harness.resolve();
      final output = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: 'runtime/profiles',
          profileId: 42,
          rawConfig: preserved,
          realPatchConfig: const PatchClashConfig(
            tun: Tun(
              enable: true,
              device: 'Slclash-device',
              stack: TunStack.system,
              dnsHijack: ['8.8.8.8:53'],
              routeAddress: ['192.0.2.0/24'],
              autoRoute: true,
            ),
          ),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'Slclash-test-UA',
        ),
      );
      final runtime = parseMihomoSourceConfig(output.a);
      // Slclash runtime ownership wins over both source and Script values.
      expect(runtime['tun']['enable'], isTrue);
      expect(runtime['tun']['future-option'], 'tun-future');
    });

    test('10. source parse failure falls back to old normalized Script path',
        () async {
      var fallbackUsed = false;
      var preservationReported = false;
      final result = await resolveScriptSnapshotRuntimeBase(
        loadSnapshot: () async => utf8.encode('['), // unparsable YAML
        normalizeSnapshot: (_) async => {'mode': 'rule'},
        fallbackNormalized: () async {
          fallbackUsed = true;
          return {'mode': 'direct'};
        },
        evaluateScript: (input) async {
          input['mode'] = 'global';
          return input;
        },
        onPreservationFailure: (_, _) => preservationReported = true,
      );
      expect(fallbackUsed, isTrue);
      expect(preservationReported, isTrue);
      expect(result, {'mode': 'direct'});
    });

    test('11. snapshot normalization failure falls back to old Script path',
        () async {
      final result = await resolveScriptSnapshotRuntimeBase(
        loadSnapshot: () async => utf8.encode('mode: rule'),
        normalizeSnapshot: (_) async => throw StateError('core failed'),
        fallbackNormalized: () async => {'mode': 'direct'},
        evaluateScript: (input) async => input,
      );
      expect(result, {'mode': 'direct'});
    });

    test('12. Script error propagates', () async {
      final harness = _ScriptHarness(
        source: {'x-source-only': 'kept'},
        normalized: {'mode': 'rule'},
        script: (_) async => throw StateError('script crashed'),
      );
      await expectLater(harness.resolve(), throwsStateError);
    });

    test('13. evaluator called exactly once on success', () async {
      final harness = _ScriptHarness(
        source: {'x-source-only': 'kept'},
        normalized: {'mode': 'rule'},
        script: (input) async => input,
      );
      await harness.resolve();
      expect(harness.evaluations, 1);
    });

    test('14. evaluator not re-run when post-Script apply falls back',
        () async {
      // A non-plain value inside the normalized map makes
      // mergeSourceWithNormalized reject the preservation base AFTER the
      // Script already produced a result. The resolver must reuse the first
      // evaluation instead of re-running the Script.
      var evaluations = 0;
      Object? applyError;
      final result = await resolveScriptSnapshotRuntimeBase(
        loadSnapshot: () async => utf8.encode('mode: rule'),
        normalizeSnapshot: (_) async => {
          'mode': 'rule',
          'weird': DateTime(2020),
        },
        fallbackNormalized: () async => {'mode': 'direct'},
        evaluateScript: (input) async {
          evaluations++;
          input['mode'] = 'global';
          return input;
        },
        onScriptApplyFailure: (error, _) => applyError = error,
      );
      expect(evaluations, 1);
      expect(applyError, isA<FormatException>());
      // The first Script result wins; no second evaluation happened.
      expect(result['mode'], 'global');
    });

    test('Script input is a deep copy; mutating it never corrupts the base',
        () async {
      Map<String, dynamic>? observedInput;
      final normalized = {
        'mode': 'rule',
        'dns': {'enable': true, 'nameserver': ['1.1.1.1']},
      };
      final harness = _ScriptHarness(
        source: {'x-source-only': 'kept'},
        normalized: normalized,
        script: (input) async {
          observedInput = input;
          (input['dns'] as Map).remove('nameserver');
          input['mode'] = 'global';
          return input;
        },
      );
      final result = await harness.resolve();
      // The Script received its own deep copy, not the diff base itself.
      expect(observedInput, isNot(same(normalized)));
      // Mutating the input never corrupted the preserved normalized base.
      expect(normalized['dns'], {
        'enable': true,
        'nameserver': ['1.1.1.1'],
      });
      // The diff still observes the Script's visible-field delete.
      expect(result['dns'], {'enable': true});
      expect(result['mode'], 'global');
      expect(result['x-source-only'], 'kept');
    });
  });

  group('diff/apply round trip through Script', () {
    test('preserved base applies a mixed change set', () async {
      final before = {
        'mode': 'rule',
        'dns': {'enable': true, 'nameserver': ['1.1.1.1']},
        'tun': {'enable': false},
        'rules': ['MATCH,DIRECT'],
      };
      final after = {
        'mode': 'global',
        'dns': {'enable': true},
        'tun': {'enable': true},
        'rules': ['DOMAIN,example.com,PROXY'],
        'ipv6': false,
      };
      final changes = diffStructuralChanges(before, after);
      final base = mergeSourceWithNormalized(
        {
          'mode': 'rule',
          'dns': {
            'enable': true,
            'nameserver': ['1.1.1.1'],
            'future-field': 'preserved',
          },
        },
        before,
      );
      final result = applyStructuralChanges(base, changes);
      expect(result['mode'], 'global');
      expect(result['dns'], {
        'enable': true,
        'future-field': 'preserved',
      });
      expect(result['tun'], {'enable': true});
      expect(result['rules'], ['DOMAIN,example.com,PROXY']);
      expect(result['ipv6'], isFalse);
    });

    test('empty diff preserves the full source overlay', () async {
      final base = mergeSourceWithNormalized(
        {'x-source-only': 'kept', 'mode': 'rule'},
        {'mode': 'rule'},
      );
      final result = applyStructuralChanges(base, const []);
      expect(result, {
        'x-source-only': 'kept',
        'mode': 'rule',
      });
    });
  });
}
