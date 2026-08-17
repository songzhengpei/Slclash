import 'dart:io';

import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/mihomo_config/runtime_config_patch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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

Map<String, dynamic> _fixture(String name) {
  final source = File(
    p.join('test', 'fixtures', 'mihomo', name),
  ).readAsStringSync();
  return Map<String, dynamic>.from(_plainYaml(loadYaml(source)) as Map);
}

Future<Map<String, dynamic>> _materialize(
  Map<String, dynamic> rawConfig, {
  PatchClashConfig patch = const PatchClashConfig(),
  bool overrideDns = false,
  bool appendSystemDns = false,
  String? writeTo,
}) async {
  final output = await makeRealProfileTask(
    MakeRealProfileState(
      profilesPath: p.join('runtime', 'profiles'),
      profileId: 42,
      rawConfig: rawConfig,
      realPatchConfig: patch,
      overrideDns: overrideDns,
      appendSystemDns: appendSystemDns,
      proxyGroups: const [],
      rules: const [],
      addedRules: const [],
      defaultUA: 'Slclash-test-UA',
    ),
  );
  if (writeTo != null) {
    final file = File(writeTo);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(output.a);
  }
  final parsed = _plainYaml(loadYaml(output.a));
  expect(parsed, isA<Map>());
  return Map<String, dynamic>.from(parsed as Map);
}

void main() {
  group('TUN ownership contract', () {
    const patch = PatchClashConfig(
      tun: Tun(
        enable: true,
        device: 'Slclash-device',
        stack: TunStack.system,
        dnsHijack: ['8.8.8.8:53'],
        routeAddress: ['192.0.2.0/24'],
        autoRoute: true,
      ),
    );

    test('owned TUN fields: Slclash wins over source values', () async {
      final input = _fixture('tun_ownership.yaml');
      final output = await _materialize(input, patch: patch);
      expect(output['tun']['enable'], isTrue);
      expect(output['tun']['device'], 'Slclash-device');
      expect(output['tun']['stack'], 'system');
      expect(output['tun']['dns-hijack'], ['8.8.8.8:53']);
      expect(output['tun']['route-address'], ['192.0.2.0/24']);
      expect(output['tun']['auto-route'], isTrue);
    });

    test('kernel-owned TUN fields are preserved', () async {
      final input = _fixture('tun_ownership.yaml');
      final output = await _materialize(input, patch: patch);
      expect(output['tun']['auto-detect-interface'], isTrue);
      expect(output['tun']['mtu'], 9000);
      expect(output['tun']['strict-route'], isTrue);
    });

    test('synthetic future TUN field survives the ownership patch', () async {
      final input = _fixture('tun_ownership.yaml')
        ..['tun']['future-option'] = 'tun-future';
      final output = await _materialize(input, patch: patch);
      expect(output['tun']['future-option'], 'tun-future');
    });

    test('applyOwnedTunPatch applies only owned keys and preserves siblings',
        () {
      final result = applyOwnedTunPatch(
        {
          'tun': {
            'enable': false,
            'mtu': 9000,
            'strict-route': true,
            'future-option': 'kept',
          },
        },
        {
          'enable': true,
          'stack': 'system',
          'mtu': 1400, // not owned: must be ignored
        },
      );
      final tun = result['tun'] as Map;
      expect(tun['enable'], isTrue);
      expect(tun['stack'], 'system');
      expect(tun['mtu'], 9000);
      expect(tun['strict-route'], isTrue);
      expect(tun['future-option'], 'kept');
    });

    test('applyOwnedTunPatch creates the tun map when missing', () {
      final result = applyOwnedTunPatch(
        {'mode': 'rule'},
        {'enable': true, 'stack': 'system'},
      );
      expect(result['tun'], {'enable': true, 'stack': 'system'});
    });

    test('materialized tun_ownership fixture reparses for bundled validity',
        () async {
      // Empty nameserverPolicy keeps the validity fixture free of
      // geosite:cn, which requires a local GeoSite.dat that CI-host
      // config.Parse cannot load.
      const validityPatch = PatchClashConfig(
        dns: Dns(
          nameserverPolicy: {},
          fallbackFilter: FallbackFilter(geoip: false, geosite: []),
        ),
      );
      final output = await _materialize(
        _fixture('tun_ownership.yaml'),
        patch: validityPatch,
        writeTo: p.join('build', 'mihomo-runtime-fixtures', 'tun_ownership.yaml'),
      );
      expect(output['tun']['auto-detect-interface'], isTrue);
      expect(output['tun']['mtu'], 9000);
      expect(output['tun']['strict-route'], isTrue);
    });
  });
}
