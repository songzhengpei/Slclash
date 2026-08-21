import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/network_diagnostics_capture.dart';
import 'package:fl_clash/common/network_diagnostics_country.dart';
import 'package:fl_clash/common/network_diagnostics_http.dart';
import 'package:fl_clash/common/network_diagnostics_models.dart';
import 'package:fl_clash/common/network_diagnostics_parsers.dart';
import 'package:fl_clash/common/network_diagnostics_store.dart';
import 'package:fl_clash/common/perf_trace.dart';
import 'package:fl_clash/models/models.dart';

const networkDiagnosticsTimeout = Duration(seconds: 3);
const youtubeMappingUrl =
    'https://redirector.googlevideo.com/report_mapping?di=no';

class NetworkDiagnosticsSession {
  NetworkDiagnosticsSession({
    NetworkDiagnosticsStore? store,
    DiagnosticsHttpGet? httpGet,
    ExplicitIpGeoLookup? geo,
    CoreRouteCapture Function()? capture,
    this.listConnections,
    this.coreCountryLookup,
  }) : store = store ?? NetworkDiagnosticsStore(),
       httpGet = httpGet ?? diagnosticsHttpGet,
       geo = geo ?? ExplicitIpGeoLookup(httpGet: httpGet ?? diagnosticsHttpGet),
       capture = capture ?? CoreRouteCapture.new;

  final NetworkDiagnosticsStore store;
  final DiagnosticsHttpGet httpGet;
  final ExplicitIpGeoLookup geo;
  final CoreRouteCapture Function() capture;
  final Future<List<TrackerInfo>> Function()? listConnections;
  final Future<String?> Function(String ip)? coreCountryLookup;

  var getConnectionsCalls = 0;
  var snapshotFallbacks = 0;
  var routeMisses = 0;

  Future<void> refresh({
    required int? mixedPort,
    required bool routeChange,
    required String reason,
    void Function()? onChanged,
  }) async {
    final generation = store.beginRefresh(routeChange: routeChange);
    StartupTrace.mark(
      'diagnostics_refresh_begin',
      extras: {'generation': generation, 'reason': reason},
    );
    onChanged?.call();
    final port = mixedPort != null && mixedPort > 0 ? mixedPort : null;
    await Future.wait(
      NetworkDiagnosticTarget.all.map((target) async {
        await _probeTarget(
          target: target,
          generation: generation,
          mixedPort: port,
          routeChange: routeChange,
          reason: reason,
          onChanged: onChanged,
        );
      }),
    );
  }

  Future<void> _probeTarget({
    required NetworkDiagnosticTarget target,
    required int generation,
    required int? mixedPort,
    required bool routeChange,
    required String reason,
    void Function()? onChanged,
  }) async {
    final refreshStarted = DateTime.now();
    StartupTrace.mark(
      'target_latency_begin',
      extras: {
        'target': target.name,
        'generation': generation,
        'reason': reason,
      },
    );
    final armedAt = DateTime.now();
    final cap = mixedPort != null ? capture() : null;
    cap?.start(target: target, armedAt: armedAt);

    TrackerInfo? tracker;
    var routeSource = 'none';

    Future<void> captureLiveRoute() async {
      StartupTrace.mark(
        'target_route_begin',
        extras: {
          'target': target.name,
          'generation': generation,
          'reason': reason,
        },
      );
      final eventHit = cap?.hit;
      if (eventHit != null) {
        tracker = eventHit;
        routeSource = 'event';
        _markTracker('core_request_event_hit', target, generation, eventHit);
        return;
      }
      if (mixedPort == null || listConnections == null) {
        return;
      }
      getConnectionsCalls += 1;
      snapshotFallbacks += 1;
      try {
        final conns = await listConnections!();
        tracker = pickFallbackConnection(
          connections: conns,
          target: target,
          armedAt: armedAt,
        );
        if (tracker != null) {
          routeSource = 'snapshot';
          _markTracker('core_snapshot_fallback', target, generation, tracker!);
        } else if (conns.isNotEmpty) {
          final sample = conns
              .take(4)
              .map(
                (c) =>
                    '${c.metadata.host}|${c.metadata.destinationIP}|${c.metadata.remoteDestination}|${c.rulePayload}|${c.chains.join('>')}',
              )
              .join(' ;; ');
          StartupTrace.mark(
            'core_snapshot_unmatched',
            extras: {
              'target': target.name,
              'generation': generation,
              'sample': sample,
            },
          );
        }
      } catch (_) {}
    }

    DiagnosticsHttpResponse? latencyRes;
    try {
      final probeHeaders = target.id == NetworkDiagnosticTargetId.github
          ? const {HttpHeaders.rangeHeader: 'bytes=0-0'}
          : const <String, String>{};
      latencyRes = await httpGet(
        uri: Uri.parse(target.probeUrl),
        timeout: networkDiagnosticsTimeout,
        mixedPort: mixedPort,
        headers: probeHeaders,
        readBody: target.id == NetworkDiagnosticTargetId.chatgpt,
        onHeaders: (headers) async {
          if (store.commitLatency(
            target: target.name,
            generation: generation,
            latencyMs: headers.headerMs,
            measuredAt: DateTime.now(),
          )) {
            StartupTrace.mark(
              'target_latency_visible',
              extras: {
                'target': target.name,
                'generation': generation,
                'reason': reason,
                'latency_ms': headers.headerMs,
                'elapsed_from_refresh_ms': DateTime.now()
                    .difference(refreshStarted)
                    .inMilliseconds,
              },
            );
            onChanged?.call();
          }
          if (mixedPort != null) {
            await captureLiveRoute();
          }
        },
      );
    } finally {
      cap?.stop();
    }

    if (latencyRes == null) {
      store.commitLatency(
        target: target.name,
        generation: generation,
        latencyMs: null,
        measuredAt: DateTime.now(),
      );
    }

    if (mixedPort != null && tracker == null && routeSource == 'none') {
      routeMisses += 1;
      StartupTrace.mark(
        'core_route_miss',
        extras: {'target': target.name, 'generation': generation},
      );
    }

    var country = '';
    var source = NetworkDiagnosticCountrySource.unknown;
    var confidence = NetworkDiagnosticConfidence.unknown;
    String? egressIp;
    String? routeName;
    final heuristic = tracker == null
        ? (routeName: null, country: null)
        : chainHeuristic(tracker!.chains);
    routeName = heuristic.routeName;

    switch (target.id) {
      case NetworkDiagnosticTargetId.chatgpt:
        final trace = parseCloudflareTrace(latencyRes?.body ?? '');
        if (trace.loc != null) {
          country = trace.loc!;
          egressIp = trace.ip;
          source = NetworkDiagnosticCountrySource.chatgptTrace;
          confidence = NetworkDiagnosticConfidence.high;
        }
        break;
      case NetworkDiagnosticTargetId.youtube:
        final mappingRes = await httpGet(
          uri: Uri.parse(youtubeMappingUrl),
          timeout: networkDiagnosticsTimeout,
          mixedPort: mixedPort,
          headers: const {},
          readBody: true,
        );
        final mapping = parseGoogleReportMapping(mappingRes?.body ?? '');
        if (mapping.ip != null) {
          egressIp = mapping.ip;
          final info = await geo.lookupCountryForIp(
            mapping.ip!,
            generation: generation,
            currentGeneration: () => store.generation,
            mixedPort: mixedPort,
            coreLookup: coreCountryLookup,
          );
          if (info != null) {
            country = info.countryCode;
            source = NetworkDiagnosticCountrySource.googleReportMapping;
            confidence = NetworkDiagnosticConfidence.medium;
            if (heuristic.country != null &&
                heuristic.country!.toUpperCase() == country.toUpperCase()) {
              confidence = NetworkDiagnosticConfidence.high;
            } else if (heuristic.country != null &&
                heuristic.country!.toUpperCase() != country.toUpperCase()) {
              confidence = NetworkDiagnosticConfidence.medium;
            }
          }
        }
        break;
      case NetworkDiagnosticTargetId.github:
        if (mixedPort != null && heuristic.country != null) {
          country = heuristic.country!;
          source = NetworkDiagnosticCountrySource.coreChainHeuristic;
          confidence = NetworkDiagnosticConfidence.medium;
        }
        break;
    }

    final gotRoute =
        country.isNotEmpty || (routeName != null && routeName.isNotEmpty);
    if (store.commitRoute(
      target: target.name,
      generation: generation,
      countryCode: country.isEmpty ? null : country,
      egressIp: egressIp,
      routeName: routeName,
      countrySource: source,
      countryConfidence: confidence,
      measuredAt: DateTime.now(),
    )) {
      StartupTrace.mark(
        'target_route_visible',
        extras: {
          'target': target.name,
          'generation': generation,
          'reason': reason,
          'country': country,
          'country_source': source.name,
          'confidence': confidence.name,
          'route_source': routeSource,
          'elapsed_from_refresh_ms': DateTime.now()
              .difference(refreshStarted)
              .inMilliseconds,
        },
      );
      onChanged?.call();
    }
    store.finishTarget(
      target: target.name,
      generation: generation,
      routeChange: routeChange,
      gotRoute: gotRoute,
    );
    StartupTrace.mark(
      'target_refresh_end',
      extras: {
        'target': target.name,
        'generation': generation,
        'reason': reason,
      },
    );
    onChanged?.call();
  }

  void _markTracker(
    String mark,
    NetworkDiagnosticTarget target,
    int generation,
    TrackerInfo tracker,
  ) {
    StartupTrace.mark(
      mark,
      extras: {
        'target': target.name,
        'generation': generation,
        'host': tracker.metadata.host,
        'destinationIP': tracker.metadata.destinationIP,
        'remoteDestination': tracker.metadata.remoteDestination,
        'rule': tracker.rule,
        'rulePayload': tracker.rulePayload,
        'chains': tracker.chains.join('>'),
      },
    );
  }
}
