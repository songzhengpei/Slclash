import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mihomo bridge spellings round-trip into saved settings', () {
    for (final entry in {
      'gVisor': TunStack.gvisor,
      'System': TunStack.system,
      'Mixed': TunStack.mixed,
      'Mips': TunStack.mips,
    }.entries) {
      final tun = Tun.fromJson({'enable': true, 'stack': entry.key});
      expect(tun.stack, entry.value);
      expect(Tun.fromJson(tun.toJson()), tun);
      expect(tun.toJson()['stack'], entry.value.name);
    }
    expect(const Tun().stack, TunStack.mixed);
    expect(Tun.fromJson({}).stack, TunStack.mixed);
    expect(() => Tun.fromJson({'stack': 'unknown'}), throwsArgumentError);
  });

  test('Mips is offered only on a supporting bundled core', () {
    for (final version in ['', 'unknown', 'v1.19.29', '1.19.30']) {
      expect(tunStacksForMihomoVersion(version), [
        TunStack.gvisor,
        TunStack.system,
        TunStack.mixed,
      ]);
    }
    for (final version in ['v1.19.31', '1.19.32', '1.19.33', '1.20.0', '2.0.0']) {
      expect(tunStacksForMihomoVersion(version), contains(TunStack.mips));
    }
  });
}
