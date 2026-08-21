import 'package:fl_clash/providers/smart_auto_stop.dart';
import 'package:test/test.dart';

void main() {
  test(
    'confirmed smart stop converges native and Flutter without a full stop',
    () async {
      final calls = <String>[];
      var flutterSmartStopped = false;

      final success = await convergeConfirmedSmartStop(
        smartStop: () async {
          calls.add('smartStop');
          return true;
        },
        setNativeSmartStopped: (value) async {
          calls.add('native:$value');
        },
        setFlutterSmartStopped: (value) {
          flutterSmartStopped = value;
          calls.add('flutter:$value');
        },
        stopLocalListener: () async {
          calls.add('listenerOnly');
        },
      );

      expect(success, isTrue);
      expect(flutterSmartStopped, isTrue);
      expect(calls, [
        'smartStop',
        'native:true',
        'flutter:true',
        'listenerOnly',
      ]);
      expect(calls, isNot(contains('serviceStop')));
    },
  );

  test(
    'failed smart stop does not mutate Flutter or stop its listener',
    () async {
      var mutations = 0;
      final success = await convergeConfirmedSmartStop(
        smartStop: () async => false,
        setNativeSmartStopped: (_) async => mutations++,
        setFlutterSmartStopped: (_) => mutations++,
        stopLocalListener: () async => mutations++,
      );

      expect(success, isFalse);
      expect(mutations, 0);
    },
  );

  test(
    'smart resume preserves native start identity and clears pause state',
    () async {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(123456789);
      DateTime? restoredStartTime;
      var flutterSmartStopped = true;

      final success = await convergeConfirmedSmartResume(
        smartResume: () async => true,
        setNativeSmartStopped: (value) async {
          expect(value, isFalse);
        },
        getNativeStartTime: () async => startedAt,
        resumeLocalListener: (value) async {
          restoredStartTime = value;
        },
        setFlutterSmartStopped: (value) => flutterSmartStopped = value,
      );

      expect(success, isTrue);
      expect(restoredStartTime, same(startedAt));
      expect(flutterSmartStopped, isFalse);
    },
  );

  test(
    'smart resume without confirmed native identity keeps pause UI',
    () async {
      var mutations = 0;
      final success = await convergeConfirmedSmartResume(
        smartResume: () async => true,
        setNativeSmartStopped: (_) async => mutations++,
        getNativeStartTime: () async => null,
        resumeLocalListener: (_) async => mutations++,
        setFlutterSmartStopped: (_) => mutations++,
      );

      expect(success, isFalse);
      expect(mutations, 0);
    },
  );

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
      expect(
        filteredInterfacePrefixes,
        containsAll(['lo', 'tun', 'utun', 'ppp', 'vpn']),
      );
      expect(filteredInterfacePrefixes.length, 5);
    });
  });
}
