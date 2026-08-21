enum NetworkDiagnosticLatencyStatus {
  unknown,
  fresh,
  refreshing,
  timeout,
  unavailable,
}

enum NetworkDiagnosticRouteStatus {
  unknown,
  fresh,
  refreshing,
  unavailable,
}

enum NetworkDiagnosticCountrySource {
  chatgptTrace,
  googleReportMapping,
  coreTracker,
  coreChainHeuristic,
  unknown,
}

enum NetworkDiagnosticConfidence {
  high,
  medium,
  low,
  unknown,
}

enum NetworkDiagnosticTargetId { github, youtube, chatgpt }

class NetworkDiagnosticTarget {
  const NetworkDiagnosticTarget({
    required this.id,
    required this.name,
    required this.url,
    required this.probeUrl,
  });

  final NetworkDiagnosticTargetId id;
  final String name;
  final String url;
  final String probeUrl;

  String get host => Uri.parse(url).host.toLowerCase();

  String get bareHost => host.startsWith('www.') ? host.substring(4) : host;

  String get probeHost => Uri.parse(probeUrl).host.toLowerCase();

  static const github = NetworkDiagnosticTarget(
    id: NetworkDiagnosticTargetId.github,
    name: 'GitHub',
    url: 'https://github.com',
    probeUrl: 'https://github.com/favicon.ico',
  );

  static const youtube = NetworkDiagnosticTarget(
    id: NetworkDiagnosticTargetId.youtube,
    name: 'YouTube',
    url: 'https://www.youtube.com',
    probeUrl: 'https://www.youtube.com/generate_204',
  );

  static const chatgpt = NetworkDiagnosticTarget(
    id: NetworkDiagnosticTargetId.chatgpt,
    name: 'ChatGPT',
    url: 'https://chatgpt.com',
    probeUrl: 'https://chatgpt.com/cdn-cgi/trace',
  );

  static const all = [github, youtube, chatgpt];
}

class NetworkDiagnosticTargetState {
  const NetworkDiagnosticTargetState({
    required this.target,
    this.latencyMs,
    this.latencyStatus = NetworkDiagnosticLatencyStatus.unknown,
    this.countryCode,
    this.egressIp,
    this.routeName,
    this.routeStatus = NetworkDiagnosticRouteStatus.unknown,
    this.countrySource = NetworkDiagnosticCountrySource.unknown,
    this.countryConfidence = NetworkDiagnosticConfidence.unknown,
    this.refreshing = false,
    this.generation = 0,
    this.measuredAt,
  });

  final NetworkDiagnosticTarget target;
  final int? latencyMs;
  final NetworkDiagnosticLatencyStatus latencyStatus;
  final String? countryCode;
  final String? egressIp;
  final String? routeName;
  final NetworkDiagnosticRouteStatus routeStatus;
  final NetworkDiagnosticCountrySource countrySource;
  final NetworkDiagnosticConfidence countryConfidence;
  final bool refreshing;
  final int generation;
  final DateTime? measuredAt;

  bool get hasVisibleLatency => latencyMs != null;

  NetworkDiagnosticTargetState copyWith({
    int? latencyMs,
    NetworkDiagnosticLatencyStatus? latencyStatus,
    String? countryCode,
    bool clearCountry = false,
    String? egressIp,
    bool clearEgress = false,
    String? routeName,
    bool clearRoute = false,
    NetworkDiagnosticRouteStatus? routeStatus,
    NetworkDiagnosticCountrySource? countrySource,
    NetworkDiagnosticConfidence? countryConfidence,
    bool? refreshing,
    int? generation,
    DateTime? measuredAt,
  }) {
    return NetworkDiagnosticTargetState(
      target: target,
      latencyMs: latencyMs ?? this.latencyMs,
      latencyStatus: latencyStatus ?? this.latencyStatus,
      countryCode: clearCountry ? null : (countryCode ?? this.countryCode),
      egressIp: clearEgress ? null : (egressIp ?? this.egressIp),
      routeName: clearRoute ? null : (routeName ?? this.routeName),
      routeStatus: routeStatus ?? this.routeStatus,
      countrySource: countrySource ?? this.countrySource,
      countryConfidence: countryConfidence ?? this.countryConfidence,
      refreshing: refreshing ?? this.refreshing,
      generation: generation ?? this.generation,
      measuredAt: measuredAt ?? this.measuredAt,
    );
  }
}

class CloudflareTrace {
  const CloudflareTrace({this.ip, this.loc, this.colo});

  final String? ip;
  final String? loc;
  final String? colo;
}

class GoogleReportMapping {
  const GoogleReportMapping({this.ip});

  final String? ip;
}
