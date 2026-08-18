import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/mihomo_config/source_config.dart';
import 'package:fl_clash/services/mihomo_config/structural_config_diff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Reads a checked-in E2E fixture pair.
Map<String, dynamic> _readRawConfigJson(String fixture) {
  final raw = File(
    p.join('test', 'fixtures', 'mihomo', 'e2e', fixture, 'rawconfig.json'),
  ).readAsStringSync();
  return Map<String, dynamic>.from(json.decode(raw) as Map);
}

Map<String, dynamic> _readSourceYaml(String fixture) {
  final source = File(
    p.join('test', 'fixtures', 'mihomo', 'e2e', fixture, 'source.yaml'),
  ).readAsStringSync();
  return parseMihomoSourceConfig(source);
}

/// Simulates the exact Go JSON bridge map reaching Dart: the checked-in
/// rawconfig.json. The only canonicalization is the established rule -> rules
/// contract (CoreController._normalizeConfigResult); no extra normalization.
Map<String, dynamic> _bridgeToDart(Map<String, dynamic> bridge) {
  final map = Map<String, dynamic>.from(bridge);
  map['rules'] = map['rule'];
  map.remove('rule');
  return map;
}

Future<Map<String, dynamic>> _materialize(
  Map<String, dynamic> rawConfig, {
  PatchClashConfig patch = const PatchClashConfig(),
  bool overrideDns = false,
  String? writeTo,
}) async {
  final output = await makeRealProfileTask(
    MakeRealProfileState(
      profilesPath: p.join('runtime', 'profiles'),
      profileId: 42,
      rawConfig: rawConfig,
      realPatchConfig: patch,
      overrideDns: overrideDns,
      appendSystemDns: false,
      proxyGroups: const [],
      rules: const [],
      addedRules: const [],
      defaultUA: 'Slclash-e2e-UA',
    ),
  );
  if (writeTo != null) {
    final file = File(writeTo);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(output.a);
  }
  final parsed = loadYaml(output.a);
  expect(parsed, isA<Map>());
  return Map<String, dynamic>.from(
    _plainYaml(parsed) as Map,
  );
}

dynamic _plainYaml(dynamic value) {
  if (value is YamlMap) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _plainYaml(entry.value),
    };
  }
  if (value is YamlList) return value.map(_plainYaml).toList();
  return value;
}

void main() {
  group('standard E2E (source -> RawConfig -> JSON -> Dart -> runtime)', () {
    test('full pipeline preserves real fields and canonicalizes rule -> rules',
        () async {
      final source = _readSourceYaml('standard_real_fields');
      final bridge = _readRawConfigJson('standard_real_fields');
      final normalized = _bridgeToDart(bridge);

      // The bridge key is 'rule'; Dart canonicalization must produce 'rules'.
      expect(bridge.containsKey('rule'), isTrue);
      expect(normalized.containsKey('rules'), isTrue);
      expect(normalized.containsKey('rule'), isFalse);

      final runtimeBase = mergeSourceWithNormalized(source, normalized);

      // Real top-level fields survive the overlay.
      expect(runtimeBase['mode'], 'rule');
      expect(runtimeBase['ipv6'], isTrue);
      expect(runtimeBase['global-ua'], 'Slclash-e2e-standard');
      expect(runtimeBase['profile'], {
        'store-selected': true,
        'store-fake-ip': false,
      });

      // Real DNS fields survive; source and bridge agree.
      final dns = runtimeBase['dns'] as Map;
      expect(dns['enable'], isTrue);
      expect(dns['nameserver'], ['1.1.1.1']);
      expect(dns['cache-algorithm'], 'arc');
      expect(dns['direct-nameserver'], ['223.5.5.5']);
      expect(dns['direct-nameserver-follow-policy'], isTrue);

      // Real TUN kernel-owned fields survive.
      final tun = runtimeBase['tun'] as Map;
      expect(tun['enable'], isTrue);
      expect(tun['auto-detect-interface'], isTrue);
      expect(tun['mtu'], 9000);
      expect(tun['strict-route'], isTrue);

      // Experimental keys survive with YAML-canonical spellings.
      final experimental = runtimeBase['experimental'] as Map;
      expect(experimental['quic-go-disable-gso'], isTrue);
      expect(experimental['quic-go-disable-ecn'], isTrue);
      expect(experimental['dialer-ip4p-convert'], isTrue);

      // Rules arrive from the bridge 'rule' key.
      expect(runtimeBase['rules'], [
        'DOMAIN,example.com,PROXY',
        'MATCH,DIRECT',
      ]);
    });

    test('materialized runtime YAML reparses and keeps real fields', () async {
      final source = _readSourceYaml('standard_real_fields');
      final bridge = _readRawConfigJson('standard_real_fields');
      final runtimeBase = mergeSourceWithNormalized(
        source,
        _bridgeToDart(bridge),
      );
      final runtime = await _materialize(
        runtimeBase,
        writeTo: p.join('build', 'mihomo-runtime-fixtures', 'e2e_standard.yaml'),
      );
      // Slclash-owned top-level values win (PatchClashConfig defaults).
      expect(runtime['mode'], 'rule');
      expect(runtime['global-ua'], 'Slclash-e2e-UA');
      // Kernel-owned fields are preserved through the runtime patch.
      final dns = runtime['dns'] as Map;
      expect(dns['cache-algorithm'], 'arc');
      expect(dns['direct-nameserver'], ['223.5.5.5']);
      final tun = runtime['tun'] as Map;
      expect(tun['auto-detect-interface'], isTrue);
      expect(tun['mtu'], 9000);
      expect(tun['strict-route'], isTrue);
      expect(runtime['rules'], [
        'DOMAIN,example.com,PROXY',
        'MATCH,DIRECT',
      ]);
    });
  });

  group('script E2E (source -> RawConfig -> JSON -> diff -> runtime)', () {
    test('script transform diff applies onto the source-preserved base',
        () async {
      final source = _readSourceYaml('script_real_fields');
      final bridge = _readRawConfigJson('script_real_fields');
      final normalized = _bridgeToDart(bridge);

      // Simulated Script transform (no QuickJS on the host): mode update,
      // known nested delete, rules list replacement, explicit null.
      final before = Map<String, dynamic>.from(
        deepCopyConfigValue(normalized) as Map<String, dynamic>,
      );
      final after = Map<String, dynamic>.from(
        deepCopyConfigValue(normalized) as Map<String, dynamic>,
      );
      after['mode'] = 'global';
      (after['dns'] as Map).remove('nameserver');
      after['rules'] = ['DOMAIN,script.example,PROXY', 'MATCH,DIRECT'];
      after['global-ua'] = null;

      final changes = diffStructuralChanges(before, after);
      final preservationBase = mergeSourceWithNormalized(source, normalized);
      final result = applyStructuralChanges(preservationBase, changes);

      // Script edits win for the visible fields.
      expect(result['mode'], 'global');
      expect(result['rules'], ['DOMAIN,script.example,PROXY', 'MATCH,DIRECT']);
      expect(result, containsPair('global-ua', null));
      expect((result['dns'] as Map).containsKey('nameserver'), isFalse);

      // Source-only siblings the Script never saw are preserved.
      final dns = result['dns'] as Map;
      expect(dns['cache-algorithm'], 'arc');
      expect(dns['direct-nameserver'], ['223.5.5.5']);
      final tun = result['tun'] as Map;
      expect(tun['mtu'], 1400);
      expect(tun['auto-detect-interface'], isTrue);
    });

    test('whole-map delete removes source-only descendants', () async {
      final source = _readSourceYaml('script_real_fields');
      final bridge = _readRawConfigJson('script_real_fields');
      final normalized = _bridgeToDart(bridge);

      final before = Map<String, dynamic>.from(
        deepCopyConfigValue(normalized) as Map<String, dynamic>,
      );
      final after = Map<String, dynamic>.from(
        deepCopyConfigValue(normalized) as Map<String, dynamic>,
      );
      after.remove('dns');

      final changes = diffStructuralChanges(before, after);
      final result = applyStructuralChanges(
        mergeSourceWithNormalized(source, normalized),
        changes,
      );
      expect(result.containsKey('dns'), isFalse);
    });

    test('materialized script runtime YAML reparses and keeps real fields',
        () async {
      final source = _readSourceYaml('script_real_fields');
      final bridge = _readRawConfigJson('script_real_fields');
      final normalized = _bridgeToDart(bridge);

      final before = Map<String, dynamic>.from(
        deepCopyConfigValue(normalized) as Map<String, dynamic>,
      );
      final after = Map<String, dynamic>.from(
        deepCopyConfigValue(normalized) as Map<String, dynamic>,
      );
      after['mode'] = 'global';
      (after['dns'] as Map).remove('nameserver');
      after['rules'] = ['DOMAIN,script.example,PROXY', 'MATCH,DIRECT'];

      final changes = diffStructuralChanges(before, after);
      final result = applyStructuralChanges(
        mergeSourceWithNormalized(source, normalized),
        changes,
      );
      final runtime = await _materialize(
        result,
        writeTo: p.join('build', 'mihomo-runtime-fixtures', 'e2e_script.yaml'),
      );
      // Slclash ownership still runs after the Script result.
      expect(runtime['mode'], 'rule');
      final dns = runtime['dns'] as Map;
      expect(dns['cache-algorithm'], 'arc');
      expect(dns['direct-nameserver'], ['223.5.5.5']);
      expect(dns.containsKey('nameserver'), isFalse);
      expect(runtime['rules'], ['DOMAIN,script.example,PROXY', 'MATCH,DIRECT']);
    });

    test('bridge contract fixture canonicalizes rule -> rules mechanically',
        () async {
      final bridge = _readRawConfigJson('bridge_contract');
      expect(bridge.containsKey('rule'), isTrue);
      expect(bridge['tun']['auto-detect-interface'], isTrue);
      expect(bridge['experimental']['quic-go-disable-gso'], isTrue);
      final normalized = _bridgeToDart(bridge);
      expect(normalized['rules'], ['MATCH,DIRECT']);
      expect(normalized.containsKey('rule'), isFalse);
    });
  });

  group('synthetic preservation separation', () {
    test('RawConfig drops synthetic fields and source preservation restores '
        'them without entering the blocking parse path', () async {
      final source = _readSourceYaml('standard_real_fields')
        ..['x-slclash-future-field'] = 'top-level'
        ..['dns']['future-field'] = 'dns-sibling';
      final bridge = _readRawConfigJson('standard_real_fields');
      // The real bridge output has no trace of the synthetic keys.
      expect(bridge.containsKey('x-slclash-future-field'), isFalse);
      expect((bridge['dns'] as Map).containsKey('future-field'), isFalse);

      final runtimeBase = mergeSourceWithNormalized(
        source,
        _bridgeToDart(bridge),
      );
      expect(runtimeBase['x-slclash-future-field'], 'top-level');
      expect(runtimeBase['dns']['future-field'], 'dns-sibling');

      // The materialized synthetic output must NOT be added to the blocking
      // config.Parse fixture list; it is validated by the Dart overlay tests.
      final runtime = await _materialize(runtimeBase);
      expect(runtime['x-slclash-future-field'], 'top-level');
      expect(runtime['dns']['future-field'], 'dns-sibling');
    });
  });
}
