import 'dart:async';

import 'package:fl_clash/common/network_diagnostics_capture.dart';
import 'package:fl_clash/common/network_diagnostics_country.dart';
import 'package:fl_clash/common/network_diagnostics_http.dart';
import 'package:fl_clash/common/network_diagnostics_match.dart';
import 'package:fl_clash/common/network_diagnostics_models.dart';
import 'package:fl_clash/common/network_diagnostics_parsers.dart';
import 'package:fl_clash/common/network_diagnostics_revision.dart';
import 'package:fl_clash/common/network_diagnostics_session.dart';
import 'package:fl_clash/common/network_diagnostics_store.dart';
import 'package:fl_clash/common/proxy_group_selection.dart';
import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/event_lease.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerInfo _tracker({
  required String host,
  List<String> chains = const ['DIRECT'],
  DateTime? start,
}) {
  return TrackerInfo(
    id: 't-$host',
    start: start ?? DateTime.now(),
    metadata: Metadata(host: host),
    chains: chains,
    rule: 'DOMAIN',
    rulePayload: host,
  );
}

class _FakeCapture extends CoreRouteCapture {
  _FakeCapture(this.future);
  final Future<TrackerInfo?> future;

  @override
  Future<TrackerInfo?> arm({
    required NetworkDiagnosticTarget target,
    required DateTime armedAt,
    required Duration wait,
  }) async {
    final info = await future;
    if (info == null || !trackerMatchesTarget(info, target)) return null;
    return info;
  }
}

DiagnosticsHttpGet _scriptedHttp(
  List<Uri> uris, {
  String youtubeIp = '8.8.8.8',
  String chatgptBody = 'ip=1.1.1.1\nloc=SG\ncolo=SIN\n',
}) {
  return ({
    required Uri uri,
    required Duration timeout,
    int? mixedPort,
    Map<String, String> headers = const {},
    bool readBody = false,
  }) async {
    uris.add(uri);
    final s = uri.toString();
    if (s.contains('github.com/favicon.ico')) {
      expect(headers['range'] ?? headers['Range'], 'bytes=0-0');
      return const DiagnosticsHttpResponse(
        headerMs: 42,
        statusCode: 200,
        method: 'GET',
      );
    }
    if (s.contains('youtube.com/generate_204')) {
      return const DiagnosticsHttpResponse(
        headerMs: 74,
        statusCode: 204,
        method: 'GET',
      );
    }
    if (s.contains('cdn-cgi/trace')) {
      return DiagnosticsHttpResponse(
        headerMs: 96,
        statusCode: 200,
        body: chatgptBody,
        method: 'GET',
      );
    }
    if (s.contains('report_mapping')) {
      return DiagnosticsHttpResponse(
        headerMs: 10,
        statusCode: 200,
        body: '$youtubeIp => google AS15169',
        method: 'GET',
      );
    }
    if (s.contains('ip-api.com/json/')) {
      expect(s.contains(youtubeIp), isTrue);
      return const DiagnosticsHttpResponse(
        headerMs: 5,
        statusCode: 200,
        body: '{"status":"success","countryCode":"US","query":"8.8.8.8"}',
        method: 'GET',
      );
    }
    return const DiagnosticsHttpResponse(
      headerMs: 5,
      statusCode: 200,
      body: '{}',
      method: 'GET',
    );
  };
}

void main() {
  setUp(() {
    NetworkDiagnosticsRevision.resetForTest();
    CoreEventTypeLease.resetForTest();
  });

  group('parsers', () {
    test('ChatGPT trace parser reads ip loc colo', () {
      final trace = parseCloudflareTrace(
        'fl=123\n'
        'ip=203.0.113.9\n'
        'loc=JP\n'
        'colo=NRT\n',
      );
      expect(trace.ip, '203.0.113.9');
      expect(trace.loc, 'JP');
      expect(trace.colo, 'NRT');
    });

    test('malformed or missing trace fields stay unknown', () {
      expect(parseCloudflareTrace('').loc, isNull);
      expect(parseCloudflareTrace('ip=\nloc=\n').loc, isNull);
      expect(parseCloudflareTrace('ip=1.1.1.1\ncolo=SIN').loc, isNull);
      expect(parseCloudflareTrace('loc=JAPAN').loc, isNull);
    });

    test('Google report_mapping parser takes left-side public IP', () {
      final parsed = parseGoogleReportMapping(
        '203.0.113.10 => 74.125.0.0/16',
      );
      expect(parsed.ip, '203.0.113.10');
    });

    test('malformed Google mapping yields no IP', () {
      expect(parseGoogleReportMapping('').ip, isNull);
      expect(parseGoogleReportMapping('no arrow here').ip, isNull);
      expect(parseGoogleReportMapping('=> 1.2.3.4').ip, isNull);
    });
  });

  group('explicit IP GeoIP', () {
    test('looks up the explicit IP and first valid country wins', () async {
      final hits = <Uri>[];
      final geo = ExplicitIpGeoLookup(
        httpGet: ({
          required Uri uri,
          required Duration timeout,
          int? mixedPort,
          Map<String, String> headers = const {},
          bool readBody = false,
        }) async {
          hits.add(uri);
          if (uri.host == 'ip-api.com') {
            return const DiagnosticsHttpResponse(
              headerMs: 3,
              statusCode: 200,
              body: '{"status":"success","countryCode":"HK"}',
            );
          }
          fail('must not continue after first valid country');
        },
      );
      final info = await geo.lookupCountryForIp(
        '9.9.9.9',
        generation: 1,
        currentGeneration: () => 1,
      );
      expect(info?.countryCode, 'HK');
      expect(hits.single.toString(), contains('9.9.9.9'));
    });

    test('cancels when generation becomes stale', () async {
      final geo = ExplicitIpGeoLookup(
        httpGet: ({
          required Uri uri,
          required Duration timeout,
          int? mixedPort,
          Map<String, String> headers = const {},
          bool readBody = false,
        }) async {
          fail('stale generation must not HTTP');
        },
      );
      final info = await geo.lookupCountryForIp(
        '1.1.1.1',
        generation: 10,
        currentGeneration: () => 11,
      );
      expect(info, isNull);
    });
  });

  group('store / generation', () {
    test('refresh preserves previous visible result', () {
      final store = NetworkDiagnosticsStore();
      store.commitLatency(
        target: 'GitHub',
        generation: 0,
        latencyMs: 92,
        measuredAt: DateTime.now(),
      );
      store.commitRoute(
        target: 'GitHub',
        generation: 0,
        countryCode: 'JP',
        countrySource: NetworkDiagnosticCountrySource.coreChainHeuristic,
        countryConfidence: NetworkDiagnosticConfidence.medium,
        measuredAt: DateTime.now(),
      );
      store.beginRefresh(routeChange: false);
      expect(store.states['GitHub']!.latencyMs, 92);
      expect(store.states['GitHub']!.countryCode, 'JP');
      expect(store.states['GitHub']!.refreshing, isTrue);
    });

    test('stale generation result is discarded', () {
      final store = NetworkDiagnosticsStore();
      store.beginRefresh(routeChange: true);
      expect(store.generation, 1);
      store.beginRefresh(routeChange: true);
      expect(store.generation, 2);
      expect(
        store.commitLatency(
          target: 'GitHub',
          generation: 2,
          latencyMs: 11,
          measuredAt: DateTime.now(),
        ),
        isTrue,
      );
      expect(
        store.commitLatency(
          target: 'GitHub',
          generation: 1,
          latencyMs: 10,
          measuredAt: DateTime.now(),
        ),
        isFalse,
      );
      expect(store.states['GitHub']!.latencyMs, 11);
      expect(store.discarded, 1);
    });

    test('latency can commit before route', () {
      final store = NetworkDiagnosticsStore();
      final gen = store.beginRefresh(routeChange: false);
      expect(
        store.commitLatency(
          target: 'YouTube',
          generation: gen,
          latencyMs: 74,
          measuredAt: DateTime.now(),
        ),
        isTrue,
      );
      expect(store.states['YouTube']!.latencyMs, 74);
      expect(store.states['YouTube']!.countryCode, isNull);
      store.commitRoute(
        target: 'YouTube',
        generation: gen,
        countryCode: 'JP',
        countrySource: NetworkDiagnosticCountrySource.googleReportMapping,
        countryConfidence: NetworkDiagnosticConfidence.medium,
        measuredAt: DateTime.now(),
      );
      expect(store.states['YouTube']!.countryCode, 'JP');
    });
  });

  group('session probes', () {
    test('GitHub uses GET favicon only, YouTube uses generate_204 GET, no HEAD', () async {
      final uris = <Uri>[];
      final session = NetworkDiagnosticsSession(
        httpGet: _scriptedHttp(uris),
        capture: () => _FakeCapture(Future.value(null)),
      );
      await session.refresh(
        mixedPort: null,
        routeChange: false,
        reason: 'test',
      );
      expect(uris.any((u) => u.toString().contains('github.com/favicon.ico')), isTrue);
      expect(
        uris.any((u) => u.toString().contains('youtube.com/generate_204')),
        isTrue,
      );
      expect(uris.any((u) => u.toString().contains('cdn-cgi/trace')), isTrue);
      expect(uris.any((u) => u.path.toUpperCase().contains('HEAD')), isFalse);
      expect(session.store.states['GitHub']!.latencyMs, 42);
      expect(session.store.states['YouTube']!.latencyMs, 74);
      expect(session.store.states['ChatGPT']!.latencyMs, 96);
    });

    test('Core OFF does not reuse a global country as target country', () async {
      final session = NetworkDiagnosticsSession(
        httpGet: _scriptedHttp([]),
        capture: () => _FakeCapture(Future.value(null)),
      );
      await session.refresh(
        mixedPort: null,
        routeChange: false,
        reason: 'core_off',
      );
      expect(session.store.states['GitHub']!.countryCode, isNull);
      expect(
        session.store.states['GitHub']!.countrySource,
        NetworkDiagnosticCountrySource.unknown,
      );
      expect(session.store.states['ChatGPT']!.countryCode, 'SG');
      expect(
        session.store.states['ChatGPT']!.countrySource,
        NetworkDiagnosticCountrySource.chatgptTrace,
      );
      expect(session.store.states['YouTube']!.countryCode, 'US');
      expect(
        session.store.states['YouTube']!.countrySource,
        NetworkDiagnosticCountrySource.googleReportMapping,
      );
    });

    test('successful latency is visible before delayed route capture', () async {
      final route = Completer<TrackerInfo?>();
      final session = NetworkDiagnosticsSession(
        httpGet: _scriptedHttp([]),
        capture: () => _FakeCapture(route.future),
        listConnections: () async => [],
      );
      final done = session.refresh(
        mixedPort: 7890,
        routeChange: false,
        reason: 'order',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session.store.states['GitHub']!.latencyMs, 42);
      expect(session.store.states['GitHub']!.refreshing, isTrue);
      route.complete(null);
      await done;
      expect(session.store.states['GitHub']!.latencyMs, 42);
    });

    test('event miss uses at most one getConnections snapshot per target', () async {
      var calls = 0;
      final session = NetworkDiagnosticsSession(
        httpGet: _scriptedHttp([]),
        capture: () => _FakeCapture(Future.value(null)),
        listConnections: () async {
          calls += 1;
          return [_tracker(host: 'github.com', chains: ['🇭🇰 HK-1'])];
        },
      );
      await session.refresh(
        mixedPort: 7890,
        routeChange: false,
        reason: 'fallback',
      );
      expect(session.getConnectionsCalls, lessThanOrEqualTo(3));
      expect(session.getConnectionsCalls, calls);
      expect(session.snapshotFallbacks, session.getConnectionsCalls);
      expect(calls, isNonZero);
      expect(calls, lessThan(18));
    });

    test('YouTube disagreement keeps Google country and Mihomo routeName', () async {
      final session = NetworkDiagnosticsSession(
        httpGet: _scriptedHttp([]),
        capture: () => _FakeCapture(
          Future.value(
            _tracker(
              host: 'www.youtube.com',
              chains: ['🇯🇵 JP-Node', 'YouTube'],
            ),
          ),
        ),
        coreCountryLookup: (ip) async => 'US',
      );
      await session.refresh(
        mixedPort: 7890,
        routeChange: false,
        reason: 'yt',
      );
      final yt = session.store.states['YouTube']!;
      expect(yt.countryCode, 'US');
      expect(yt.routeName, '🇯🇵 JP-Node');
      expect(yt.countryConfidence, NetworkDiagnosticConfidence.medium);
      expect(
        yt.countrySource,
        NetworkDiagnosticCountrySource.googleReportMapping,
      );
    });
  });

  group('core tracker match / events', () {
    test('matches target host and ignores unrelated tracker', () {
      final github = _tracker(host: 'github.com');
      final other = _tracker(host: 'example.com');
      expect(trackerMatchesTarget(github, NetworkDiagnosticTarget.github), isTrue);
      expect(trackerMatchesTarget(other, NetworkDiagnosticTarget.github), isFalse);
    });

    test('request-event hit path completes capture', () async {
      final cap = CoreRouteCapture();
      final armed = cap.arm(
        target: NetworkDiagnosticTarget.github,
        armedAt: DateTime.now(),
        wait: const Duration(seconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      coreEventManager.sendEvent(
        CoreEvent(
          type: CoreEventType.request,
          data: {
            'id': 'evt-1',
            'start': DateTime.now().toIso8601String(),
            'metadata': {'host': 'github.com'},
            'chains': ['🇯🇵 JP-01'],
            'rule': 'DOMAIN',
            'rulePayload': 'github.com',
          },
        ),
      );
      final hit = await armed;
      expect(hit, isNotNull);
      expect(hit!.metadata.host, 'github.com');
      expect(cap.eventHits, 1);
    });

    test('event miss plus bounded fallback picks recent matching snapshot', () {
      final armedAt = DateTime.now();
      final picked = pickFallbackConnection(
        connections: [
          _tracker(
            host: 'github.com',
            start: armedAt.subtract(const Duration(minutes: 5)),
          ),
          _tracker(host: 'github.com', start: armedAt),
        ],
        target: NetworkDiagnosticTarget.github,
        armedAt: armedAt,
      );
      expect(picked?.start.isBefore(armedAt.subtract(const Duration(seconds: 2))), isFalse);
    });
  });

  group('revision / 4C gate', () {
    test('route revision bump is what diagnostics listen to', () {
      expect(NetworkDiagnosticsRevision.value, 0);
      NetworkDiagnosticsRevision.bump(reason: 'selection_success');
      expect(NetworkDiagnosticsRevision.value, 1);
    });

    test('failed selection result is not treated as success', () {
      expect(isCoreSelectionSuccess(''), isTrue);
      expect(isCoreSelectionSuccess('unable to find proxy xxx'), isFalse);
    });
  });

  test('chain heuristic is medium-confidence name parsing, not ground truth', () {
    final parsed = chainHeuristic(['SELECT', '🇯🇵 Tokyo-01']);
    expect(parsed.country, 'JP');
    expect(parsed.routeName, '🇯🇵 Tokyo-01');
    expect(extractCountryFromProxyName('DIRECT'), isNull);
  });
}
