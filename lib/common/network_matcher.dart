/// IPv4/CIDR network matcher for smart auto stop.
///
/// Supports plain IPv4 addresses (e.g. "192.168.1.100") and CIDR notation
/// (e.g. "192.168.1.0/24") in the trusted networks list.
class NetworkMatcher {
  /// Check if [ip] matches any network in [networks].
  ///
  /// Each entry in [networks] can be:
  /// - A plain IPv4 address: exact match
  /// - A CIDR notation "a.b.c.d/prefix": subnet match
  /// - Empty or whitespace entries are skipped
  static bool matches(String ip, List<String> networks) {
    final parsedIp = parseIpv4(ip);
    if (parsedIp == null) return false;

    for (final network in networks) {
      final trimmed = network.trim();
      if (trimmed.isEmpty) continue;

      if (_isCidr(trimmed)) {
        if (_matchesCidr(parsedIp, trimmed)) return true;
      } else {
        final networkIp = parseIpv4(trimmed);
        if (networkIp != null && parsedIp == networkIp) return true;
      }
    }
    return false;
  }

  /// Parse an IPv4 address string into a 32-bit integer.
  ///
  /// Returns `null` if the string is not a valid IPv4 address.
  static int? parseIpv4(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) return null;

    int result = 0;
    for (final part in parts) {
      if (part.isEmpty) return null;
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return null;
      if (part.length > 1 && part.startsWith('0')) return null;
      result = (result << 8) | value;
    }
    return result;
  }

  static bool _isCidr(String network) {
    final parts = network.split('/');
    return parts.length == 2 && int.tryParse(parts[1]) != null;
  }

  static bool _matchesCidr(int ip, String cidr) {
    final parts = cidr.split('/');
    final networkIp = parseIpv4(parts[0]);
    final prefixLen = int.parse(parts[1]);

    if (networkIp == null) return false;
    if (prefixLen < 0 || prefixLen > 32) return false;
    if (prefixLen == 0) return true;

    final mask = (~0) << (32 - prefixLen);
    return (ip & mask) == (networkIp & mask);
  }
}
