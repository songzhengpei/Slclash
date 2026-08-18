import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rule.rawValue serialization', () {
    test('MATCH emits only action and target', () {
      expect(Rule.parse('MATCH,DIRECT').rawValue, 'MATCH,DIRECT');
      expect(Rule.parse('MATCH,REJECT').rawValue, 'MATCH,REJECT');
    });

    test('UI-created MATCH with null content emits MATCH,target', () {
      const rule = Rule(ruleAction: RuleAction.MATCH, ruleTarget: 'DIRECT');
      expect(rule.rawValue, 'MATCH,DIRECT');
    });

    test('MATCH never leaks null content into the payload slot', () {
      const rule = Rule(
        ruleAction: RuleAction.MATCH,
        content: null,
        ruleTarget: 'DIRECT',
      );
      expect(rule.rawValue, isNot(contains('null')));
      expect(rule.rawValue, 'MATCH,DIRECT');
    });

    test('round-trips representative actions', () {
      const cases = [
        'DOMAIN,example.com,PROXY',
        'DOMAIN-SUFFIX,example.com,PROXY',
        'DOMAIN-KEYWORD,ads,DIRECT',
        r'DOMAIN-REGEX,^ads\.example\.com$,REJECT',
        'GEOSITE,cn,DIRECT',
        'GEOIP,CN,DIRECT',
        'GEOIP,CN,DIRECT,no-resolve',
        'IP-CIDR,1.1.1.1/32,DIRECT,no-resolve',
        'IP-CIDR6,2001:db8::/32,PROXY',
        'IP-ASN,13335,DIRECT',
        'SRC-IP-CIDR,192.168.1.0/24,DIRECT',
        'SRC-GEOIP,CN,DIRECT',
        'DST-PORT,80,PROXY',
        'SRC-PORT,443,REJECT',
        'IN-PORT,7890,PROXY',
        'IN-TYPE,TUN,DIRECT',
        'PROCESS-NAME,chrome,DIRECT',
        'PROCESS-PATH,/usr/bin/curl,REJECT',
        'UID,1000,DIRECT',
        'NETWORK,TCP,REJECT',
        'RULE-SET,rules/geo,PROXY',
        'RULE-SET,rules/ads,REJECT,no-resolve',
        'SUB-RULE,myrule,REJECT',
      ];
      for (final input in cases) {
        expect(
          Rule.parse(input).rawValue,
          input,
          reason: 'round-trip $input',
        );
      }
    });
  });
}
