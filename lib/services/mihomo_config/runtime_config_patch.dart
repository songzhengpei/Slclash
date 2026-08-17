import 'package:fl_clash/services/mihomo_config/source_config.dart';

/// Slclash-owned TUN fields. These six fields are the complete Slclash TUN
/// contract; every other Mihomo TUN field (mtu, strict-route,
/// auto-detect-interface, ...) is kernel/profile-owned and must be preserved
/// untouched. Keep this list in sync with the Tun model.
const Set<String> slclashOwnedTunFields = {
  'enable',
  'device',
  'dns-hijack',
  'stack',
  'route-address',
  'auto-route',
};

/// Applies Slclash-owned TUN values onto [config]'s tun section. Slclash
/// values win for the owned fields; every other TUN sibling is preserved.
/// The tun map is patched in place (never wholesale-replaced) and created
/// when missing.
MihomoConfigMap applyOwnedTunPatch(
  MihomoConfigMap config,
  MihomoConfigMap tunPatch,
) {
  final tun = (config['tun'] as MihomoConfigMap?) ?? <String, dynamic>{};
  for (final entry in tunPatch.entries) {
    if (slclashOwnedTunFields.contains(entry.key)) {
      tun[entry.key] = entry.value;
    }
  }
  config['tun'] = tun;
  return config;
}
