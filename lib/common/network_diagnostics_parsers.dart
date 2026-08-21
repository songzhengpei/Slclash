import 'package:fl_clash/common/network_diagnostics_models.dart';

CloudflareTrace parseCloudflareTrace(String body) {
  String? ip;
  String? loc;
  String? colo;
  for (final raw in body.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim().toLowerCase();
    final value = line.substring(eq + 1).trim();
    if (value.isEmpty) continue;
    switch (key) {
      case 'ip':
        ip = value;
        break;
      case 'loc':
        loc = value.toUpperCase();
        break;
      case 'colo':
        colo = value;
        break;
    }
  }
  if (loc != null && loc.length != 2) {
    loc = null;
  }
  return CloudflareTrace(ip: ip, loc: loc, colo: colo);
}

/// Public Google report_mapping body: take only the left-side IP of `IP =>`.
GoogleReportMapping parseGoogleReportMapping(String body) {
  final text = body.trim();
  if (text.isEmpty) {
    return const GoogleReportMapping();
  }
  final match = RegExp(
    r'((?:\d{1,3}\.){3}\d{1,3}|[0-9a-fA-F:]+)\s*=>',
  ).firstMatch(text);
  return GoogleReportMapping(ip: match?.group(1));
}

bool isPlausibleIp(String? value) {
  if (value == null || value.isEmpty) return false;
  final v4 = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$');
  if (v4.hasMatch(value)) {
    return value.split('.').every((part) {
      final n = int.tryParse(part);
      return n != null && n >= 0 && n <= 255;
    });
  }
  return value.contains(':') && value.length >= 3;
}
