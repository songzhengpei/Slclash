import 'package:fl_clash/services/mihomo_config/source_config.dart';

/// Coerces any map-like value (including isolate-transferred and yaml-derived
/// maps) into a plain String-keyed map.
MihomoConfigMap _asStringMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

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
  final tun = _asStringMap(config['tun']);
  for (final entry in tunPatch.entries) {
    if (slclashOwnedTunFields.contains(entry.key)) {
      tun[entry.key] = entry.value;
    }
  }
  config['tun'] = tun;
  return config;
}

/// Slclash-owned DNS fields, matching the Dns model exactly. Every other
/// Mihomo DNS field (cache-algorithm, direct-nameserver, fake-ip-ttl, future
/// fields, ...) is kernel/profile-owned and must be preserved.
const Set<String> slclashOwnedDnsFields = {
  'enable',
  'listen',
  'prefer-h3',
  'use-hosts',
  'use-system-hosts',
  'respect-rules',
  'ipv6',
  'default-nameserver',
  'enhanced-mode',
  'fake-ip-range',
  'fake-ip-filter',
  'nameserver-policy',
  'nameserver',
  'fallback',
  'proxy-server-nameserver',
  'fallback-filter',
};

/// Slclash-owned fallback-filter subfields, matching the FallbackFilter model
/// exactly. Future fallback-filter siblings are preserved.
const Set<String> slclashOwnedFallbackFilterFields = {
  'geoip',
  'geoip-code',
  'geosite',
  'ipcidr',
  'domain',
};

/// Applies Slclash-owned DNS values onto [config]'s dns section without
/// replacing the whole map. Owned fields win; nameserver-policy is replaced
/// as an atomic Slclash map; fallback-filter is patched by owned subfields
/// only; every other DNS field (cache-algorithm, direct-nameserver, future
/// fields, ...) is preserved. The dns map is created when missing.
MihomoConfigMap applyOwnedDnsPatch(
  MihomoConfigMap config,
  MihomoConfigMap dnsPatch,
) {
  final dns = _asStringMap(config['dns']);
  for (final entry in dnsPatch.entries) {
    if (!slclashOwnedDnsFields.contains(entry.key)) continue;
    if (entry.key == 'fallback-filter') {
      final filter = _asStringMap(dns['fallback-filter']);
      final filterPatch = entry.value;
      if (filterPatch is Map) {
        for (final sub in filterPatch.entries) {
          if (slclashOwnedFallbackFilterFields.contains(sub.key)) {
            filter[sub.key] = sub.value;
          }
        }
      }
      dns['fallback-filter'] = filter;
    } else {
      dns[entry.key] = entry.value;
    }
  }
  config['dns'] = dns;
  return config;
}
