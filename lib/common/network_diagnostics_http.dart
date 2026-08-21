import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/network_diagnostics_parsers.dart';
import 'package:fl_clash/models/models.dart';

class DiagnosticsHttpResponse {
  const DiagnosticsHttpResponse({
    required this.headerMs,
    required this.statusCode,
    this.body = '',
    this.method = 'GET',
  });

  final int headerMs;
  final int statusCode;
  final String body;
  final String method;
}

typedef DiagnosticsHttpGet =
    Future<DiagnosticsHttpResponse?> Function({
      required Uri uri,
      required Duration timeout,
      int? mixedPort,
      Map<String, String> headers,
      bool readBody,
    });

Future<DiagnosticsHttpResponse?> diagnosticsHttpGet({
  required Uri uri,
  required Duration timeout,
  int? mixedPort,
  Map<String, String> headers = const {},
  bool readBody = false,
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  if (mixedPort != null && mixedPort > 0) {
    client.findProxy = (uri) => 'PROXY 127.0.0.1:$mixedPort';
  }
  final watch = Stopwatch()..start();
  try {
    final request = await client.openUrl('GET', uri).timeout(timeout);
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.headers.set(HttpHeaders.userAgentHeader, 'FlClash');
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(timeout);
    watch.stop();
    var body = '';
    if (readBody) {
      final remaining = timeout - watch.elapsed;
      final wait = remaining.isNegative ? const Duration(milliseconds: 200) : remaining;
      body = await response
          .transform(const Utf8Decoder())
          .join()
          .timeout(wait, onTimeout: () => '');
    } else {
      unawaited(response.drain<void>());
    }
    return DiagnosticsHttpResponse(
      headerMs: watch.elapsedMilliseconds,
      statusCode: response.statusCode,
      body: body,
      method: 'GET',
    );
  } catch (_) {
    watch.stop();
    return null;
  } finally {
    client.close(force: true);
  }
}

class ExplicitIpGeoLookup {
  ExplicitIpGeoLookup({this.httpGet = diagnosticsHttpGet});

  final DiagnosticsHttpGet httpGet;

  static const timeout = Duration(seconds: 3);

  Future<IpInfo?> lookupCountryForIp(
    String ip, {
    required int generation,
    required int Function() currentGeneration,
    int? mixedPort,
    Future<String?> Function(String ip)? coreLookup,
  }) async {
    if (!isPlausibleIp(ip)) return null;
    if (generation != currentGeneration()) return null;
    final core = coreLookup;
    if (core != null) {
      final code = await core(ip);
      if (generation != currentGeneration()) return null;
      if (code != null && code.length == 2) {
        return IpInfo(ip: ip, countryCode: code.toUpperCase());
      }
    }
    final urls = [
      Uri.parse('http://ip-api.com/json/$ip?fields=status,countryCode,query'),
      Uri.parse('https://ipapi.co/$ip/json'),
      Uri.parse('https://ipinfo.io/$ip/json'),
    ];
    for (final url in urls) {
      if (generation != currentGeneration()) return null;
      final res = await httpGet(
        uri: url,
        timeout: timeout,
        mixedPort: mixedPort,
        headers: const {},
        readBody: true,
      );
      if (generation != currentGeneration()) return null;
      if (res == null || res.body.isEmpty) continue;
      try {
        final json = jsonDecode(res.body);
        if (json is! Map) continue;
        final map = Map<String, dynamic>.from(json);
        if (map['status'] == 'fail') continue;
        final code = (map['countryCode'] ??
                map['country_code'] ??
                map['country'])
            ?.toString();
        if (code != null && code.length == 2) {
          return IpInfo(ip: ip, countryCode: code.toUpperCase());
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
