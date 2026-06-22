import 'package:fl_clash/providers/smart_auto_stop.dart';
import 'package:test/test.dart';

void main() {
  group('isFilteredNetworkInterface', () {
    test('filters loopback', () {
      expect(isFilteredNetworkInterface('lo'), isTrue);
      expect(isFilteredNetworkInterface('lo0'), isTrue);
    });

    test('filters tun interfaces', () {
      expect(isFilteredNetworkInterface('tun0'), isTrue);
      expect(isFilteredNetworkInterface('tun1'), isTrue);
      expect(isFilteredNetworkInterface('TUN0'), isTrue);
    });

    test('filters utun interfaces', () {
      expect(isFilteredNetworkInterface('utun0'), isTrue);
      expect(isFilteredNetworkInterface('utun2'), isTrue);
    });

    test('filters ppp interfaces', () {
      expect(isFilteredNetworkInterface('ppp0'), isTrue);
      expect(isFilteredNetworkInterface('ppp1'), isTrue);
    });

    test('filters vpn interfaces', () {
      expect(isFilteredNetworkInterface('vpn0'), isTrue);
      expect(isFilteredNetworkInterface('vpn'), isTrue);
    });

    test('allows wifi interfaces', () {
      expect(isFilteredNetworkInterface('wlan0'), isFalse);
      expect(isFilteredNetworkInterface('wifi0'), isFalse);
    });

    test('allows ethernet interfaces', () {
      expect(isFilteredNetworkInterface('eth0'), isFalse);
      expect(isFilteredNetworkInterface('en0'), isFalse);
    });

    test('allows cellular interfaces', () {
      expect(isFilteredNetworkInterface('rmnet0'), isFalse);
      expect(isFilteredNetworkInterface('ccmni0'), isFalse);
    });

    test('case insensitive', () {
      expect(isFilteredNetworkInterface('TUN0'), isTrue);
      expect(isFilteredNetworkInterface('VPN0'), isTrue);
      expect(isFilteredNetworkInterface('Lo0'), isTrue);
      expect(isFilteredNetworkInterface('PPP0'), isTrue);
    });
  });

  group('filteredInterfacePrefixes', () {
    test('contains expected prefixes', () {
      expect(filteredInterfacePrefixes, containsAll(['lo', 'tun', 'utun', 'ppp', 'vpn']));
      expect(filteredInterfacePrefixes.length, 5);
    });
  });
}
