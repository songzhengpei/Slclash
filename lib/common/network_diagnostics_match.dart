import 'package:fl_clash/common/network_diagnostics_models.dart';
import 'package:fl_clash/models/models.dart';

bool trackerMatchesTarget(TrackerInfo conn, NetworkDiagnosticTarget target) {
  final host = target.host;
  final bareHost = target.bareHost;
  final meta = conn.metadata;
  final fields = [
    meta.host,
    meta.destinationIP,
    meta.remoteDestination,
    conn.rulePayload,
    conn.rule,
  ];
  for (final raw in fields) {
    final field = raw.toLowerCase();
    if (field.isEmpty) continue;
    if (_hostMatches(field, host: host, bareHost: bareHost)) {
      return true;
    }
    if (field.contains(bareHost)) {
      return true;
    }
  }
  return false;
}

bool _hostMatches(
  String field, {
  required String host,
  required String bareHost,
}) {
  final colon = field.indexOf(':');
  final fieldNoPort = colon > 0 ? field.substring(0, colon) : field;
  if (fieldNoPort == host || fieldNoPort == bareHost) return true;
  if (fieldNoPort.endsWith('.$bareHost')) return true;
  if (bareHost.isNotEmpty && fieldNoPort == 'www.$bareHost') return true;
  return false;
}
