import 'dart:convert';

import 'package:fl_clash/models/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old and absent VPN settings keep an empty application list', () {
    expect(VpnProps.fromJson(null).smartAutoStopApplications, isEmpty);
    final upgraded = VpnProps.fromJson({
      'smartAutoStop': true,
      'smartAutoStopNetworks': ['192.168.100.0/24'],
    });
    expect(upgraded.smartAutoStopApplications, isEmpty);
    expect(upgraded.smartAutoStopNetworks, ['192.168.100.0/24']);
  });

  test('multiple application selections persist independently of networks', () {
    const original = VpnProps(
      smartAutoStop: true,
      smartAutoStopApplications: ['app.a', 'app.b'],
    );
    final restored = VpnProps.fromJson(
      jsonDecode(jsonEncode(original)) as Map<String, Object?>,
    );
    expect(restored, original);
    expect(restored.smartAutoStopNetworks, isEmpty);
    expect(
      restored
          .copyWith(smartAutoStopNetworks: ['10.0.0.0/8'])
          .smartAutoStopApplications,
      ['app.a', 'app.b'],
    );
  });
}
