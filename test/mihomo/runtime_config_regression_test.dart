import 'dart:io';

import 'package:fl_clash/common/javascript.dart';
import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/services/mihomo_config/source_config.dart';
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
  List<Rule> rules = const [],
  List<Rule> addedRules = const [],
  List<ProxyGroup> proxyGroups = const [],
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
      proxyGroups: proxyGroups,
      rules: rules,
      addedRules: addedRules,
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
  test(
    'materializes supported fixtures for bundled Mihomo validation',
    () async {
      const fixtures = [
        'base.yaml',
        'dns.yaml',
        'dns_override.yaml',
        'tun.yaml',
        'sniffer.yaml',
        'proxy_provider.yaml',
        'rule_provider.yaml',
        'rules.yaml',
        'proxy_groups.yaml',
        'script.yaml',
        'ipv6.yaml',
        'mihomo_current_features.yaml',
        'real_source_preservation.yaml',
      ];
      for (final name in fixtures) {
        await _materialize(
          _fixture(name),
          patch: const PatchClashConfig(
            dns: Dns(
              nameserverPolicy: {},
              fallbackFilter: FallbackFilter(geoip: false, geosite: []),
            ),
          ),
          writeTo: p.join('build', 'mihomo-runtime-fixtures', name),
        );
      }
    },
  );

  group('runtime-owned patch behavior', () {
    test('generates reparsable YAML and preserves existing rules', () async {
      final output = await _materialize(_fixture('base.yaml'));
      expect(output['rules'], ['MATCH,SELECT']);
      expect(output['profile']['store-selected'], isFalse);
    });

    test('applies listener and user-setting runtime values', () async {
      const patch = PatchClashConfig(
        mixedPort: 17890,
        socksPort: 17891,
        port: 17892,
        redirPort: 17893,
        tproxyPort: 17894,
        mode: Mode.global,
        allowLan: true,
        logLevel: LogLevel.warning,
        ipv6: true,
      );
      final output = await _materialize(_fixture('base.yaml'), patch: patch);
      expect(output['mixed-port'], 17890);
      expect(output['socks-port'], 17891);
      expect(output['port'], 17892);
      expect(output['redir-port'], 17893);
      expect(output['tproxy-port'], 17894);
      expect(output['mode'], 'global');
      expect(output['allow-lan'], isTrue);
      expect(output['log-level'], 'warning');
      expect(output['ipv6'], isTrue);
      expect(output['external-ui'], isEmpty);
      expect(output['interface-name'], isEmpty);
    });

    test('patches TUN fields while preserving unrelated siblings', () async {
      final input = _fixture('tun.yaml')
        ..['tun']['future-option'] = 'preserved';
      const patch = PatchClashConfig(
        tun: Tun(
          enable: true,
          device: 'Slclash-test',
          stack: TunStack.system,
          dnsHijack: ['any:53'],
          routeAddress: ['10.0.0.0/8'],
          autoRoute: true,
        ),
      );
      final output = await _materialize(input, patch: patch);
      expect(output['tun']['enable'], isTrue);
      expect(output['tun']['device'], 'Slclash-test');
      expect(output['tun']['future-option'], 'preserved');
    });

    test('normalizes sniffer ports to strings', () async {
      final output = await _materialize(_fixture('sniffer.yaml'));
      expect(output['sniffer']['sniff']['HTTP']['ports'], ['80', '8080-8880']);
    });

    test(
      'rewrites HTTP provider runtime paths and preserves siblings',
      () async {
        final input = _fixture('synthetic_unknown_fields.yaml');
        final output = await _materialize(input);
        final proxy = output['proxy-providers']['sample'] as Map;
        final rule = output['rule-providers']['sample'] as Map;
        expect(
          p.normalize(proxy['path'] as String),
          contains(p.join('42', 'proxies')),
        );
        expect(
          p.normalize(rule['path'] as String),
          contains(p.join('42', 'rules')),
        );
        expect(proxy['future-option'], 'proxy-provider-sibling');
        expect(rule['future-option'], 'rule-provider-sibling');
      },
    );

    test('applies global UA hosts and geox URL settings', () async {
      const patch = PatchClashConfig(
        globalUa: 'Configured-UA',
        hosts: {'patched.example': '192.0.2.1, 192.0.2.2'},
      );
      final output = await _materialize(
        _fixture('mihomo_current_features.yaml'),
        patch: patch,
      );
      expect(output['global-ua'], 'Configured-UA');
      expect(output['hosts']['fixture.example'], '192.0.2.20');
      expect(output['hosts']['patched.example'], ['192.0.2.1', '192.0.2.2']);
      expect(output['geox-url'], isA<Map>());
    });
  });

  group('DNS current behavior', () {
    test('preserves enabled source DNS when override is disabled', () async {
      final input = _fixture('dns.yaml')
        ..['dns']['future-dns-option'] = 'preserved';
      final output = await _materialize(input);
      expect(output['dns']['future-dns-option'], 'preserved');
      expect(output['dns']['nameserver'], ['system://']);
    });

    test('rebuilds DNS using configured override behavior', () async {
      final input = _fixture('dns_override.yaml')
        ..['dns']['future-dns-option'] = 'removed';
      const patch = PatchClashConfig(
        dns: Dns(
          nameserver: ['9.9.9.9'],
          nameserverPolicy: {'example.com': '1.1.1.1,8.8.8.8'},
        ),
      );
      final output = await _materialize(input, patch: patch, overrideDns: true);
      expect(output['dns']['nameserver'], ['9.9.9.9']);
      expect(output['dns']['nameserver-policy']['example.com'], [
        '1.1.1.1',
        '8.8.8.8',
      ]);
      expect(output['dns'], isNot(contains('future-dns-option')));
    });

    test('rebuilds disabled DNS and adds the system resolver', () async {
      final input = _fixture('dns.yaml');
      input['dns']['enable'] = false;
      final output = await _materialize(input);
      expect(output['dns']['enable'], isTrue);
      expect(output['dns']['nameserver'], contains('system://'));
    });

    test('appendSystemDns adds exactly one system resolver', () async {
      final input = _fixture('dns_override.yaml');
      final output = await _materialize(input, appendSystemDns: true);
      expect(output['dns']['nameserver'], ['1.1.1.1', 'system://']);
    });
  });

  group('rule and proxy-group overwrite behavior', () {
    test(
      'prepends standard added rules using current MATCH serialization',
      () async {
        final output = await _materialize(
          _fixture('rules.yaml'),
          addedRules: [
            Rule.parse('DOMAIN,added.example,DIRECT'),
            const Rule(ruleAction: RuleAction.MATCH, ruleTarget: 'MATCH'),
          ],
        );
        expect(output['rules'].first, 'DOMAIN,added.example,DIRECT');
        expect(output['rules'][1], 'MATCH,null,DIRECT');
        expect(output['rules'], contains('DOMAIN,example.com,DIRECT'));
      },
    );

    test('replaces rules when overwrite rules are supplied', () async {
      final output = await _materialize(
        _fixture('rules.yaml'),
        rules: [
          Rule.parse('DOMAIN,replacement.example,REJECT'),
          const Rule(ruleAction: RuleAction.MATCH, ruleTarget: 'DIRECT'),
        ],
      );
      expect(output['rules'], [
        'DOMAIN,replacement.example,REJECT',
        'MATCH,null,DIRECT',
      ]);
    });

    test(
      'replaces proxy groups only when overwrite groups are supplied',
      () async {
        const replacement = ProxyGroup(
          id: 1,
          name: 'OVERRIDE',
          type: GroupType.Selector,
          proxies: ['DIRECT'],
        );
        final output = await _materialize(
          _fixture('proxy_groups.yaml'),
          proxyGroups: [replacement],
        );
        expect(output['proxy-groups'], hasLength(1));
        expect(output['proxy-groups'].first['name'], 'OVERRIDE');
      },
    );
  });

  group('script-stage contract', () {
    test(
      'script receives normalized map and can mutate common value shapes',
      () async {
        final input = _fixture('script.yaml')
          ..['proxy-providers'] = <String, dynamic>{};
        final scripted = await handleEvaluate('''
function main(config) {
  config.mode = 'direct';
  config['script-map'] = {nested: true};
  config['script-list'] = ['a', 'b'];
  delete config.hosts;
  return config;
}
''', input);
        expect(scripted['mode'], 'direct');
        expect(scripted['script-map'], {'nested': true});
        expect(scripted['script-list'], ['a', 'b']);
        expect(scripted, isNot(contains('hosts')));
      },
      skip:
          'Non-blocking audit: flutter_js native QuickJS is unavailable in host-side Flutter tests.',
    );

    test('applies runtime patch after the script result', () async {
      final scripted = _fixture('script.yaml')
        ..['mode'] = 'direct'
        ..['script-added'] = {
          'scalar': true,
          'list': [1, 2],
        }
        ..remove('hosts');
      const patch = PatchClashConfig(mode: Mode.global);
      final output = await _materialize(scripted, patch: patch);
      expect(output['mode'], 'global');
      expect(output['script-added'], {
        'scalar': true,
        'list': [1, 2],
      });
      expect(output['hosts'], isEmpty);
    });
  });

  group('synthetic preservation audit', () {
    test(
      'unknown top-level fields survive RawConfig normalization',
      () {},
      skip:
          'Known limitation: Mihomo RawConfig drops unknown top-level fields before Dart receives the map.',
    );
    test(
      'unknown DNS and TUN siblings survive RawConfig normalization',
      () {},
      skip:
          'Known limitation: typed Mihomo RawDNS and RawTun drop unknown siblings.',
    );
  });

  group('JSON bridge key contract', () {
    test(
      'overlay keeps YAML-canonical keys without Go field-name duplicates',
      () async {
        final source = _fixture('real_source_preservation.yaml');
        // Mirrors what CoreController.getConfig() returns: Go json.Marshal of
        // RawConfig plus the rule -> rules rewrite.
        final normalized = <String, dynamic>{
          'tun': {
            'enable': false,
            'stack': 'mixed',
            'auto-detect-interface': true,
            'auto-route': false,
            'dns-hijack': ['any:53'],
          },
          'experimental': {
            'quic-go-disable-gso': true,
            'quic-go-disable-ecn': true,
            'dialer-ip4p-convert': true,
          },
          'dns': {'enable': true},
          'rules': ['MATCH,DIRECT'],
        };
        final runtimeBase = mergeSourceWithNormalized(source, normalized);
        final output = await _materialize(runtimeBase);

        final tun = output['tun'] as Map;
        expect(tun['auto-detect-interface'], isTrue);
        expect(tun, isNot(contains('AutoDetectInterface')));

        final experimental = output['experimental'] as Map;
        expect(experimental['quic-go-disable-gso'], isTrue);
        expect(experimental['quic-go-disable-ecn'], isTrue);
        expect(experimental['dialer-ip4p-convert'], isTrue);
        expect(experimental, isNot(contains('QUICGoDisableGSO')));
        expect(experimental, isNot(contains('QUICGoDisableECN')));
        expect(experimental, isNot(contains('IP4PEnable')));
      },
    );
  });
}
