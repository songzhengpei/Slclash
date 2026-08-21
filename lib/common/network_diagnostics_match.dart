import 'package:fl_clash/common/network_diagnostics_models.dart';
import 'package:fl_clash/models/models.dart';

/// Exact probe-host match for diagnostics fallback.
///
/// Uses [NetworkDiagnosticTarget.probeUrl] host only. Nearby GitHub
/// subdomains such as `api.github.com` must not count as the favicon probe.
bool trackerMatchesTarget(TrackerInfo conn, NetworkDiagnosticTarget target) {
  final expected = _normalizeHost(target.probeHost);
  if (expected.isEmpty) return false;
  for (final raw in [conn.metadata.host, conn.metadata.remoteDestination]) {
    final field = _normalizeHost(raw);
    if (field.isEmpty) continue;
    if (field == expected) return true;
  }
  return false;
}

String _normalizeHost(String raw) {
  var field = raw.trim().toLowerCase();
  if (field.isEmpty) return '';
  if (field.startsWith('[') && field.contains(']')) {
    final end = field.indexOf(']');
    field = field.substring(1, end);
    return field;
  }
  final colon = field.indexOf(':');
  if (colon > 0 && field.split(':').length == 2) {
    field = field.substring(0, colon);
  }
  return field;
}
