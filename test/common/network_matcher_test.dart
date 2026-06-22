import 'package:fl_clash/common/network_matcher.dart';
import 'package:test/test.dart';

void main() {
  group('parseIpv4', () {
    test('valid addresses', () {
      expect(NetworkMatcher.parseIpv4('192.168.1.1'), 3232235777);
      expect(NetworkMatcher.parseIpv4('0.0.0.0'), 0);
      expect(NetworkMatcher.parseIpv4('255.255.255.255'), 0xFFFFFFFF);
      expect(NetworkMatcher.parseIpv4('10.0.0.1'), 167772161);
    });

    test('invalid addresses', () {
      expect(NetworkMatcher.parseIpv4(''), isNull);
      expect(NetworkMatcher.parseIpv4('abc'), isNull);
      expect(NetworkMatcher.parseIpv4('192.168.1'), isNull);
      expect(NetworkMatcher.parseIpv4('192.168.1.1.1'), isNull);
      expect(NetworkMatcher.parseIpv4('256.0.0.0'), isNull);
      expect(NetworkMatcher.parseIpv4('192.168.1.01'), isNull);
      expect(NetworkMatcher.parseIpv4('192.168.1.-1'), isNull);
    });

    test('edge cases', () {
      expect(NetworkMatcher.parseIpv4('1.0.0.0'), 1 << 24);
      expect(NetworkMatcher.parseIpv4('0.1.0.0'), 1 << 16);
      expect(NetworkMatcher.parseIpv4('0.0.1.0'), 1 << 8);
      expect(NetworkMatcher.parseIpv4('0.0.0.1'), 1);
    });
  });

  group('matches - exact', () {
    test('exact match', () {
      expect(
        NetworkMatcher.matches('192.168.1.100', ['192.168.1.100']),
        isTrue,
      );
    });

    test('no match', () {
      expect(
        NetworkMatcher.matches('192.168.1.100', ['192.168.1.200']),
        isFalse,
      );
    });

    test('empty networks list', () {
      expect(
        NetworkMatcher.matches('192.168.1.100', []),
        isFalse,
      );
    });

    test('whitespace entries are skipped', () {
      expect(
        NetworkMatcher.matches('192.168.1.100', ['  ', '', '192.168.1.100']),
        isTrue,
      );
    });

    test('multiple networks - first match', () {
      expect(
        NetworkMatcher.matches('10.0.0.5', ['192.168.1.0/24', '10.0.0.0/8']),
        isTrue,
      );
    });

    test('multiple networks - no match', () {
      expect(
        NetworkMatcher.matches('172.16.0.1', ['192.168.1.0/24', '10.0.0.0/8']),
        isFalse,
      );
    });
  });

  group('matches - CIDR', () {
    test('/24 subnet match', () {
      expect(
        NetworkMatcher.matches('192.168.1.50', ['192.168.1.0/24']),
        isTrue,
      );
      expect(
        NetworkMatcher.matches('192.168.1.254', ['192.168.1.0/24']),
        isTrue,
      );
    });

    test('/24 subnet no match', () {
      expect(
        NetworkMatcher.matches('192.168.2.1', ['192.168.1.0/24']),
        isFalse,
      );
    });

    test('/16 subnet', () {
      expect(
        NetworkMatcher.matches('172.16.5.100', ['172.16.0.0/16']),
        isTrue,
      );
      expect(
        NetworkMatcher.matches('172.17.0.1', ['172.16.0.0/16']),
        isFalse,
      );
    });

    test('/8 subnet', () {
      expect(
        NetworkMatcher.matches('10.255.255.255', ['10.0.0.0/8']),
        isTrue,
      );
      expect(
        NetworkMatcher.matches('11.0.0.1', ['10.0.0.0/8']),
        isFalse,
      );
    });

    test('/32 (single host)', () {
      expect(
        NetworkMatcher.matches('192.168.1.1', ['192.168.1.1/32']),
        isTrue,
      );
      expect(
        NetworkMatcher.matches('192.168.1.2', ['192.168.1.1/32']),
        isFalse,
      );
    });

    test('/0 (matches all)', () {
      expect(
        NetworkMatcher.matches('1.2.3.4', ['0.0.0.0/0']),
        isTrue,
      );
    });

    test('invalid CIDR prefix', () {
      expect(
        NetworkMatcher.matches('192.168.1.1', ['192.168.1.0/33']),
        isFalse,
      );
      expect(
        NetworkMatcher.matches('192.168.1.1', ['192.168.1.0/-1']),
        isFalse,
      );
    });

    test('invalid CIDR network address', () {
      expect(
        NetworkMatcher.matches('192.168.1.1', ['abc/24']),
        isFalse,
      );
    });
  });

  group('matches - mixed', () {
    test('plain and CIDR mixed', () {
      expect(
        NetworkMatcher.matches('192.168.1.50', [
          '10.0.0.0/8',
          '192.168.1.100',
          '172.16.0.0/16',
        ]),
        isFalse,
      );
      expect(
        NetworkMatcher.matches('192.168.1.100', [
          '10.0.0.0/8',
          '192.168.1.100',
          '172.16.0.0/16',
        ]),
        isTrue,
      );
      expect(
        NetworkMatcher.matches('10.1.2.3', [
          '10.0.0.0/8',
          '192.168.1.100',
          '172.16.0.0/16',
        ]),
        isTrue,
      );
    });
  });
}
