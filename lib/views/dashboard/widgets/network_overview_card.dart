import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/dashboard_palette.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maps country keywords found in proxy names to ISO 3166-1 alpha-2 codes.
const _countryKeywords = {
  'hk': 'HK',
  'hong kong': 'HK',
  '香港': 'HK',
  'tw': 'TW',
  'taiwan': 'TW',
  '台湾': 'TW',
  '臺灣': 'TW',
  'jp': 'JP',
  'japan': 'JP',
  '日本': 'JP',
  'sg': 'SG',
  'singapore': 'SG',
  '新加坡': 'SG',
  'us': 'US',
  'usa': 'US',
  'united states': 'US',
  'america': 'US',
  '美国': 'US',
  '美國': 'US',
  'kr': 'KR',
  'korea': 'KR',
  '韩国': 'KR',
  '韓國': 'KR',
  'uk': 'GB',
  'gb': 'GB',
  'united kingdom': 'GB',
  'britain': 'GB',
  '英国': 'GB',
  '英國': 'GB',
  'de': 'DE',
  'germany': 'DE',
  '德国': 'DE',
  '德國': 'DE',
  'fr': 'FR',
  'france': 'FR',
  '法国': 'FR',
  '法國': 'FR',
  'ca': 'CA',
  'canada': 'CA',
  '加拿大': 'CA',
  'au': 'AU',
  'australia': 'AU',
  '澳大利亚': 'AU',
  'nl': 'NL',
  'netherlands': 'NL',
  '荷兰': 'NL',
};

/// Returns true when [text] contains [keyword] as a standalone token (for
/// short Latin keywords) or as a substring (for longer / CJK keywords).
bool _matchesCountryKeyword(String text, String keyword) {
  final isShortLatinKeyword = RegExp(r'^[a-z]{2,3}$').hasMatch(keyword);
  if (!isShortLatinKeyword) {
    return text.contains(keyword);
  }
  return RegExp(
    '(^|[^a-z])${RegExp.escape(keyword)}([^a-z]|\$)',
  ).hasMatch(text);
}

/// Extracts an embedded flag emoji (e.g. 🇯🇵) from [text], if present.
String? _extractEmbeddedFlag(String text) {
  return RegExp(
    r'[\u{1F1E6}-\u{1F1FF}]{2}',
    unicode: true,
  ).firstMatch(text)?.group(0);
}

@visibleForTesting
class NetworkOverviewCardLayout {
  const NetworkOverviewCardLayout({
    required this.chartHeight,
    required this.trafficTitleToChartGap,
    required this.latencyHeaderToRowsGap,
    required this.afterTrafficGap,
  });

  final double chartHeight;
  final double trafficTitleToChartGap;
  final double latencyHeaderToRowsGap;
  final double afterTrafficGap;
}

class NetworkOverviewCardLayoutCalculator {
  const NetworkOverviewCardLayoutCalculator._();

  static const double headerHeight = 26;
  static const double chartBaseHeight = 82;
  static const double trafficRowBaseHeight = 132;
  static const double detectionBarHeight = 34;
  static const double dividerHeight = 1;

  static const double headerToChartGap = 10;
  static const double chartToDividerGap = 14;
  static const double dividerToTrafficGap = 14;
  static const double trafficTitleToChartBaseGap = 28;
  static const double latencyHeaderToRowsBaseGap = 26;
  static const double trafficToDividerBaseGap = 14;
  static const double dividerToDetectionGap = 14;

  static double naturalOuterHeightFor(double scale) {
    return 20 * scale + naturalInnerHeightFor(scale) + 18 * scale;
  }

  static double naturalInnerHeightFor(double scale) {
    return headerHeight +
        headerToChartGap * scale +
        chartBaseHeight * scale +
        chartToDividerGap * scale +
        dividerHeight +
        dividerToTrafficGap * scale +
        trafficRowBaseHeight * scale +
        trafficToDividerBaseGap * scale +
        dividerHeight +
        dividerToDetectionGap * scale +
        detectionBarHeight;
  }

  @visibleForTesting
  static NetworkOverviewCardLayout layoutFor({
    required double availableInnerHeight,
    required double scale,
  }) {
    final extraHeight = math.max(
      0.0,
      availableInnerHeight - naturalInnerHeightFor(scale),
    );
    final chartExtra = extraHeight * 0.55;
    final middleExtra = extraHeight - chartExtra;

    return NetworkOverviewCardLayout(
      chartHeight: chartBaseHeight * scale + chartExtra,
      trafficTitleToChartGap:
          trafficTitleToChartBaseGap * scale + middleExtra * 0.35,
      latencyHeaderToRowsGap:
          latencyHeaderToRowsBaseGap * scale + middleExtra * 0.35,
      afterTrafficGap: trafficToDividerBaseGap * scale + middleExtra * 0.30,
    );
  }
}

class SurgeNetworkOverviewCard extends ConsumerStatefulWidget {
  const SurgeNetworkOverviewCard({super.key, this.layoutScale = 1});

  final double layoutScale;

  @override
  ConsumerState<SurgeNetworkOverviewCard> createState() =>
      _SurgeNetworkOverviewCardState();
}

class _SurgeNetworkOverviewCardState
    extends ConsumerState<SurgeNetworkOverviewCard> {
  static const _cardRadius = 26.0;
  static const _latencyRefreshInterval = Duration(seconds: 60);
  static const _pageLabel = PageLabel.dashboard;
  static const _latencyTargets = [
    _LatencyTarget(
      name: 'GitHub',
      url: 'https://github.com',
      probeUrl: 'https://github.com/favicon.ico',
    ),
    _LatencyTarget(
      name: 'YouTube',
      url: 'https://www.youtube.com',
      probeUrl: 'https://www.youtube.com/generate_204',
    ),
    _LatencyTarget(
      name: 'ChatGPT',
      url: 'https://chatgpt.com',
      probeUrl: 'https://chatgpt.com/favicon.ico',
    ),
  ];

  static const _latencyTimeout = Duration(seconds: 5);

  final Map<String, _LatencyResult> _latencyResults = {};
  Timer? _latencyRefreshTimer;
  bool _isTestingLatencies = false;

  double _scaled(double value) => value * widget.layoutScale;

  bool _isChinese(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  }

  String _overviewTitle(BuildContext context) {
    return _isChinese(context) ? '网络概览' : 'Network Overview';
  }

  List<Point> _buildSeries(
    List<Traffic> traffics,
    num Function(Traffic traffic) valueOf,
    List<double> placeholder,
  ) {
    final values = traffics
        .map((traffic) => valueOf(traffic).toDouble())
        .toList();
    final hasRealData = values.any((value) => value > 0);
    final source = hasRealData ? values : placeholder;
    return source
        .asMap()
        .entries
        .map((entry) => Point(entry.key.toDouble(), entry.value))
        .toList();
  }

  String? _extractCountryFromProxyName(String proxyName) {
    final flag = _extractEmbeddedFlag(proxyName);
    if (flag != null) return _emojiToCountryCode(flag);
    final lower = proxyName.toLowerCase();
    for (final entry in _countryKeywords.entries) {
      if (_matchesCountryKeyword(lower, entry.key)) return entry.value;
    }
    return null;
  }

  static String? _emojiToCountryCode(String emoji) {
    final runes = emoji.runes.toList();
    if (runes.length != 2) return null;
    final a = runes[0] - 0x1F1E6;
    final b = runes[1] - 0x1F1E6;
    if (a < 0 || a > 25 || b < 0 || b > 25) return null;
    return String.fromCharCodes([0x41 + a, 0x41 + b]);
  }

  /// Check whether a core connection record matches the probe target.
  bool _matchesHost(TrackerInfo conn, _LatencyTarget target) {
    final host = target.host;
    final bareHost = target.bareHost;
    final meta = conn.metadata;

    for (final raw in [meta.host, meta.destinationIP, meta.remoteDestination]) {
      final field = raw.toLowerCase();
      if (field.isEmpty) continue;
      if (field == host || field == bareHost) return true;
      if (field.endsWith('.$bareHost')) return true;
      // Strip port suffix (e.g. "host:443")
      final colon = field.indexOf(':');
      final fieldNoPort = colon > 0 ? field.substring(0, colon) : field;
      if (fieldNoPort == bareHost ||
          fieldNoPort.endsWith('.$bareHost') ||
          (bareHost.isNotEmpty && fieldNoPort == 'www.$bareHost')) {
        return true;
      }
    }
    return false;
  }

  /// Poll the core /connections endpoint (via FFI) for up to 3 seconds,
  /// matching only connections whose id is not in [beforeIds].
  /// Returns the first matching [TrackerInfo], or null.
  Future<TrackerInfo?> _pollCoreConnections(
    _LatencyTarget target,
    Set<String> beforeIds,
  ) async {
    for (var i = 0; i < 18; i++) {
      if (i != 0) {
        await Future.delayed(const Duration(milliseconds: 160));
      }
      try {
        final conns = await CoreController().getConnections();
        for (final conn in conns) {
          if (beforeIds.contains(conn.id)) continue;
          if (_matchesHost(conn, target)) return conn;
        }
      } catch (_) {
        // Core may not be ready; silently retry.
      }
    }
    return null;
  }

  /// Poll [requestsProvider] for up to 3 seconds after a probe, looking for
  /// a new [TrackerInfo] whose host matches [target]. Only entries added
  /// after [startIndex] are considered, so historical connections are never
  /// mistaken for this probe.
  Future<TrackerInfo?> _pollForNewTracker(
    _LatencyTarget target,
    Set<String> beforeIds,
  ) async {
    final host = target.host;
    final bareHost = target.bareHost;
    // Poll for up to 3s, checking immediately on the first iteration to avoid
    // missing short-lived connections (e.g. favicon or generate_204).
    for (var i = 0; i < 36; i++) {
      if (i != 0) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
      final requests = ref.read(requestsProvider).list;
      for (final req in requests) {
        if (beforeIds.contains(req.id)) continue;
        final meta = req.metadata;
        final reqHost = meta.host.toLowerCase();
        final remoteDest = meta.remoteDestination.toLowerCase();
        final destIP = meta.destinationIP.toLowerCase();
        if (reqHost == host ||
            reqHost == bareHost ||
            reqHost.endsWith('.$bareHost') ||
            remoteDest.contains(bareHost) ||
            destIP.contains(bareHost)) {
          return req;
        }
      }
    }
    return null;
  }

  /// Probe one target and capture both latency and the country code inferred
  /// from the Clash route chain. Returns a fully-populated [_LatencyResult].
  /// Uses core /connections (FFI) as primary source; falls back to
  /// requestsProvider polling for the rare case the core path misses.
  Future<_LatencyResult> _probeSingleTarget(
    _LatencyTarget target, {
    required int? mixedPort,
    required String? fallbackCountryCode,
  }) async {
    // --- snapshot IDs before the probe so we only match NEW connections ---
    final beforeProviderIds = ref
        .read(requestsProvider)
        .list
        .map((e) => e.id)
        .toSet();
    Set<String> beforeCoreIds;
    if (mixedPort != null) {
      try {
        final conns = await CoreController().getConnections();
        beforeCoreIds = conns.map((e) => e.id).toSet();
      } catch (_) {
        beforeCoreIds = {};
      }
    } else {
      beforeCoreIds = {};
    }

    // Start core polling and provider polling BEFORE the probe request.
    // Both run in parallel with the HTTP measurement.
    final coreFuture = mixedPort != null
        ? _pollCoreConnections(target, beforeCoreIds)
        : Future<TrackerInfo?>.value(null);
    final providerFuture = mixedPort != null
        ? _pollForNewTracker(target, beforeProviderIds)
        : Future<TrackerInfo?>.value(null);

    final latency = await _measureLatency(target, mixedPort: mixedPort);

    String? countryCode;
    String? routeName;
    TrackerInfo? trackerInfo;
    bool coreHit = false;
    bool providerHit = false;

    if (mixedPort != null && latency != null) {
      // Prefer core /connections — it captures live connections regardless
      // of how briefly they exist.
      trackerInfo = await coreFuture;
      if (trackerInfo != null) {
        coreHit = true;
      } else {
        // Fallback: poll provider for connections that arrived via events.
        trackerInfo = await providerFuture;
        if (trackerInfo != null) {
          providerHit = true;
        }
      }

      if (trackerInfo != null) {
        // Walk chains in reverse; use the first entry that resolves to a
        // country code. If DIRECT is encountered, fall back immediately.
        for (final chain in trackerInfo.chains.reversed) {
          final trimmed = chain.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed.toUpperCase() == 'DIRECT') {
            routeName ??= trimmed;
            countryCode ??= fallbackCountryCode;
            break;
          }
          final cc = _extractCountryFromProxyName(trimmed);
          if (cc != null) {
            routeName = trimmed;
            countryCode = cc;
            break;
          }
          // Keep first non-empty as fallback routeName if no country resolves.
          routeName ??= trimmed;
        }
      }
    }

    // Fallback logic: only apply fallbackCountryCode when proxy is not
    // running. When proxy IS running but tracker capture failed, return
    // countryCode: null so the UI shows a globe instead of the wrong flag.
    final effectiveCountryCode = mixedPort == null
        ? (countryCode ?? fallbackCountryCode)
        : countryCode;

    assert(() {
      debugPrint(
        '[LatencyRoute] target=${target.name} mixedPort=$mixedPort '
        'latency=$latency coreHit=$coreHit providerHit=$providerHit '
        'host=${trackerInfo?.metadata.host} '
        'chains=${trackerInfo?.chains} '
        'country=$effectiveCountryCode',
      );
      return true;
    }());

    return _LatencyResult(
      latency: latency,
      countryCode: effectiveCountryCode,
      routeName: routeName,
      proxyName: routeName,
    );
  }

  @override
  void initState() {
    super.initState();

    // Listen to foreground changes — sync timer, refresh on return-to-foreground
    ref.listenManual(appForegroundProvider, (prev, next) {
      _syncLatencyRefreshTimer();
      if (next) {
        unawaited(_testLatencies(force: true));
      }
    });
    // Listen to page changes — sync timer, refresh when dashboard becomes visible
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      _syncLatencyRefreshTimer();
      if (next == _pageLabel) {
        unawaited(_testLatencies(force: true));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_shouldRunLatencyRefresh(ref)) {
        unawaited(_testLatencies());
      }
      _syncLatencyRefreshTimer();
    });
  }

  @override
  void dispose() {
    _latencyRefreshTimer?.cancel();
    super.dispose();
  }

  bool _shouldRunLatencyRefresh(WidgetRef ref) {
    final uiAutoRefresh = ref.read(uiAutoRefreshEnabledProvider);
    final isDashboardPage = ref.read(currentPageLabelProvider) == _pageLabel;
    return uiAutoRefresh && isDashboardPage;
  }

  bool _shouldUseClashRoute(WidgetRef ref) {
    final isRunning = ref.read(isStartProvider);
    final isSmartStopped = ref.read(isSmartStoppedProvider);
    return isRunning && !isSmartStopped;
  }

  void _syncLatencyRefreshTimer() {
    if (!_shouldRunLatencyRefresh(ref)) {
      if (_latencyRefreshTimer != null) {
        _latencyRefreshTimer?.cancel();
        _latencyRefreshTimer = null;
      }
      return;
    }
    if (_latencyRefreshTimer != null) return;
    _latencyRefreshTimer = Timer.periodic(_latencyRefreshInterval, (_) {
      unawaited(_testLatencies(force: true));
    });
  }

  Future<int?> _measureLatency(_LatencyTarget target, {int? mixedPort}) async {
    Future<HttpClientResponse> request(
      HttpClient client,
      Uri uri,
      String method,
    ) async {
      final httpRequest = await client
          .openUrl(method, uri)
          .timeout(_latencyTimeout);
      httpRequest.followRedirects = false;
      httpRequest.maxRedirects = 0;
      httpRequest.headers.set(HttpHeaders.userAgentHeader, 'FlClash');
      if (method == 'GET') {
        httpRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      }
      return httpRequest.close().timeout(_latencyTimeout);
    }

    final client = HttpClient()..connectionTimeout = _latencyTimeout;
    if (mixedPort != null) {
      client.findProxy = (uri) => 'PROXY 127.0.0.1:$mixedPort';
    }
    final uri = Uri.parse(target.probeUrl);
    final stopwatch = Stopwatch()..start();
    try {
      HttpClientResponse response;
      try {
        response = await request(client, uri, 'HEAD');
      } catch (_) {
        response = await request(client, uri, 'GET');
      }
      stopwatch.stop();
      unawaited(response.drain<void>());
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      stopwatch.stop();
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _testLatencies({bool force = false}) async {
    // Allow testing even when proxy is not running (requirement 7), but
    // skip if another test is already in progress or results are fresh.
    if (_isTestingLatencies) return;
    if (!force && _latencyResults.isNotEmpty) return;

    final hasProxy = _shouldUseClashRoute(ref);
    final mixedPort = hasProxy
        ? ref.read(patchClashConfigProvider).mixedPort
        : null;
    final fallbackCountryCode = ref
        .read(networkDetectionProvider)
        .ipInfo
        ?.countryCode;

    setState(() {
      _isTestingLatencies = true;
      for (final target in _latencyTargets) {
        _latencyResults[target.name] = const _LatencyResult.pending();
      }
    });

    // Parallel per-target: all targets probe concurrently,
    // each result is shown as soon as it completes.
    await Future.wait(
      _latencyTargets.map((target) async {
        if (!mounted) return;
        final result = await _probeSingleTarget(
          target,
          mixedPort: mixedPort != 0 ? mixedPort : null,
          fallbackCountryCode: fallbackCountryCode,
        );
        if (!mounted) return;
        setState(() {
          _latencyResults[target.name] = result;
        });
      }),
    );

    if (!mounted) return;
    setState(() {
      _isTestingLatencies = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final totalTraffic = ref.watch(totalTrafficProvider);
    final networkDetection = ref.watch(networkDetectionProvider);
    final isStart = ref.watch(isStartProvider);
    final lastTraffic = traffics.isEmpty ? const Traffic() : traffics.last;
    final hasLiveTraffic = traffics.any(
      (traffic) => traffic.up > 0 || traffic.down > 0,
    );
    final uploadPoints = _buildSeries(traffics, (traffic) => traffic.up, const [
      0.13,
      0.13,
      0.13,
      0.13,
      0.13,
      0.13,
      0.13,
      0.13,
    ]);
    final downloadPoints = _buildSeries(
      traffics,
      (traffic) => traffic.down,
      const [0.077, 0.077, 0.077, 0.077, 0.077, 0.077, 0.077, 0.077],
    );
    final uploadColor = isStart
        ? dashboardDynamicActiveFill
        : dashboardInactiveFill;
    final downloadColor = isStart
        ? dashboardActiveGreenFill
        : dashboardInactiveVariantFill;
    final lineFillStartAlpha = isStart ? 0.16 : 1.0;
    final lineFillEndAlpha = isStart ? 0.03 : 0.08;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, _scaled(20), 18, _scaled(18)),
      decoration: BoxDecoration(
        color: surge.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: surge.separator),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
            availableInnerHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : NetworkOverviewCardLayoutCalculator.naturalInnerHeightFor(
                    widget.layoutScale,
                  ),
            scale: widget.layoutScale,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Icon(
                        Icons.public_rounded,
                        color: isStart ? surge.primary : surge.inactive,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _overviewTitle(context),
                          style: context.textTheme.titleMedium?.copyWith(
                            color: surge.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.08,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Network Overview',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: surge.textSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w400,
                            height: 1.12,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LiveSpeedBadge(
                    up: lastTraffic.up,
                    down: lastTraffic.down,
                    upColor: uploadColor,
                    downColor: downloadColor,
                  ),
                ],
              ),
              SizedBox(height: _scaled(10)),
              SizedBox(
                height: layout.chartHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LineChart(
                        points: uploadPoints,
                        color: uploadColor,
                        gradient: true,
                        gradientStartAlpha: lineFillStartAlpha,
                        gradientEndAlpha: lineFillEndAlpha,
                        duration: commonDuration,
                        minY: hasLiveTraffic ? null : 0,
                        maxY: hasLiveTraffic ? null : 0.2,
                      ),
                    ),
                    Positioned.fill(
                      child: LineChart(
                        points: downloadPoints,
                        color: downloadColor,
                        gradient: true,
                        gradientStartAlpha: lineFillStartAlpha,
                        gradientEndAlpha: lineFillEndAlpha,
                        duration: commonDuration,
                        minY: hasLiveTraffic ? null : 0,
                        maxY: hasLiveTraffic ? null : 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: _scaled(14)),
              Container(height: 1, color: surge.separator),
              SizedBox(height: _scaled(14)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: Icon(
                                Icons.data_saver_off_rounded,
                                size: 18,
                                color: surge.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appLocalizations.trafficUsage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.titleSmall
                                        ?.copyWith(
                                          color: surge.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          height: 1.08,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Traffic',
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(
                                          color: surge.textSecondary,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w400,
                                          height: 1.12,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: layout.trafficTitleToChartGap),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: SizedBox(
                            width: _scaled(78),
                            height: _scaled(78),
                            child: DonutChart(
                              data: [
                                DonutChartData(
                                  value: totalTraffic.up.toDouble(),
                                  color: uploadColor,
                                ),
                                DonutChartData(
                                  value: totalTraffic.down.toDouble(),
                                  color: downloadColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 0),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Spacer(),
                            _TotalTrafficBadge(
                              up: totalTraffic.up,
                              down: totalTraffic.down,
                              upColor: uploadColor,
                              downColor: downloadColor,
                            ),
                          ],
                        ),
                        SizedBox(height: layout.latencyHeaderToRowsGap),
                        _PlatformLatencyPanel(
                          targets: _latencyTargets,
                          results: _latencyResults,
                          fallbackCountryCode:
                              networkDetection.ipInfo?.countryCode,
                          activeColor: dashboardDynamicActiveFill,
                          fillColor: surge.fill,
                          textColor: surge.textPrimary,
                          secondaryTextColor: surge.textSecondary,
                          dangerColor: surge.red,
                          onRetest: () {
                            unawaited(_testLatencies(force: true));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: layout.afterTrafficGap),
              Container(height: 1, color: surge.separator),
              SizedBox(height: _scaled(14)),
              _NetworkDetectionBar(
                networkDetection: networkDetection,
                primaryColor: surge.primary,
                textColor: surge.textPrimary,
                secondaryTextColor: surge.textSecondary,
                fillColor: surge.fill,
                dangerColor: surge.red,
                label: appLocalizations.networkDetection,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveSpeedBadge extends StatelessWidget {
  const _LiveSpeedBadge({
    required this.up,
    required this.down,
    required this.upColor,
    required this.downColor,
  });

  final num up;
  final num down;
  final Color upColor;
  final Color downColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LiveSpeedLine(
          icon: Icons.arrow_upward_rounded,
          value: '${up.traffic.show}/s',
          color: upColor,
        ),
        const SizedBox(width: 12),
        _LiveSpeedLine(
          icon: Icons.arrow_downward_rounded,
          value: '${down.traffic.show}/s',
          color: downColor,
        ),
      ],
    );
  }
}

class _LiveSpeedLine extends StatelessWidget {
  const _LiveSpeedLine({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: context.textTheme.labelMedium?.copyWith(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _NetworkDetectionBar extends StatelessWidget {
  const _NetworkDetectionBar({
    required this.networkDetection,
    required this.primaryColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.fillColor,
    required this.dangerColor,
    required this.label,
  });

  final NetworkDetectionState networkDetection;
  final Color primaryColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color fillColor;
  final Color dangerColor;
  final String label;

  static const _flagVerticalOffset = 0.8;

  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return countryCode;
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final ipInfo = networkDetection.ipInfo;
    final isLoading = networkDetection.isLoading;

    Widget valueWidget;
    if (ipInfo != null) {
      valueWidget = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 16,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, _flagVerticalOffset),
                child: Text(
                  _countryCodeToEmoji(ipInfo.countryCode),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: FontFamily.twEmoji.value,
                    fontSize: 14,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: TooltipText(
              text: Text(
                ipInfo.ip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (isLoading == false) {
      valueWidget = Text(
        'Timeout',
        maxLines: 1,
        style: TextStyle(
          color: dangerColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      );
    } else {
      valueWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CommonCircleLoading(color: primaryColor),
          ),
          const SizedBox(width: 6),
          Text(
            context.appLocalizations.loading,
            maxLines: 1,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 10,
              fontWeight: FontWeight.w400,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.network_check_rounded, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: valueWidget),
          ),
        ],
      ),
    );
  }
}

class _LatencyTarget {
  const _LatencyTarget({
    required this.name,
    required this.url,
    required this.probeUrl,
  });

  final String name;
  final String url;
  final String probeUrl;

  String get host => Uri.parse(url).host.toLowerCase();

  String get bareHost => host.startsWith('www.') ? host.substring(4) : host;
}

class _LatencyResult {
  const _LatencyResult({
    required this.latency,
    this.countryCode,
    this.routeName,
    this.proxyName,
  }) : pending = false;

  const _LatencyResult.pending()
    : latency = null,
      pending = true,
      countryCode = null,
      routeName = null,
      proxyName = null;

  final int? latency;
  final bool pending;
  final String? countryCode;
  final String? routeName;
  final String? proxyName;

  bool get timeout => !pending && latency == null;
}

class _TotalTrafficBadge extends StatelessWidget {
  const _TotalTrafficBadge({
    required this.up,
    required this.down,
    required this.upColor,
    required this.downColor,
  });

  final num up;
  final num down;
  final Color upColor;
  final Color downColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrafficAmount(
          icon: Icons.arrow_upward_rounded,
          value: up,
          color: upColor,
        ),
        const SizedBox(width: 12),
        _TrafficAmount(
          icon: Icons.arrow_downward_rounded,
          value: down,
          color: downColor,
        ),
      ],
    );
  }
}

class _TrafficAmount extends StatelessWidget {
  const _TrafficAmount({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final formatted = value.traffic.show;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          formatted,
          style: context.textTheme.labelMedium?.copyWith(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PlatformLatencyPanel extends StatelessWidget {
  const _PlatformLatencyPanel({
    required this.targets,
    required this.results,
    required this.fallbackCountryCode,
    required this.activeColor,
    required this.fillColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.dangerColor,
    required this.onRetest,
  });

  final List<_LatencyTarget> targets;
  final Map<String, _LatencyResult> results;
  final String? fallbackCountryCode;
  final Color activeColor;
  final Color fillColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color dangerColor;
  final VoidCallback onRetest;

  Color _flowColor(_LatencyResult? result) {
    if (result == null || result.pending) return activeColor;
    final latency = result.latency;
    if (latency == null) return dashboardSunsetError;
    if (latency < 180) return dashboardSunsetSuccess;
    if (latency < 420) return dashboardSunsetWarning;
    return dashboardSunsetError;
  }

  Color _trackColor(_LatencyResult? result) {
    final flow = _flowColor(result);
    return Color.lerp(flow, Colors.black, 0.76)!.withValues(alpha: 0.58);
  }

  double _barWidth(_LatencyResult? result) {
    if (result == null || result.pending) return 1;
    final latency = result.latency;
    if (latency == null) return 1;
    return (latency / 640).clamp(0.08, 1).toDouble();
  }

  Widget _value(BuildContext context, _LatencyResult? result) {
    if (result?.pending == true) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CommonCircleLoading(color: activeColor),
      );
    }
    if (result?.timeout == true) {
      return Text(
        'Timeout',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: _valueStyle(context).copyWith(color: dangerColor, fontSize: 10),
      );
    }
    final latency = result?.latency;
    if (latency == null) {
      return Text(
        '-',
        maxLines: 1,
        softWrap: false,
        style: _valueStyle(context).copyWith(color: secondaryTextColor),
      );
    }
    final padded = latency.toString().padLeft(3, '0');
    return Text(
      '${padded}ms',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: _valueStyle(context).copyWith(color: textColor),
    );
  }

  TextStyle _valueStyle(BuildContext context) {
    return context.textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.0,
          letterSpacing: 0,
        ) ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final target in targets) ...[
          // Do not show fallback country code in pending state;
          // only use the resolved countryCode from a completed probe.
          _PlatformLatencyRow(
            target: target,
            countryCode: () {
              final r = results[target.name];
              return (r == null || r.pending) ? null : r.countryCode;
            }(),
            trackColor: _trackColor(results[target.name]),
            flowColor: _flowColor(results[target.name]),
            barWidthFactor: _barWidth(results[target.name]),
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            trailing: _value(context, results[target.name]),
            onRetest: onRetest,
          ),
          if (target != targets.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PlatformLatencyRow extends StatelessWidget {
  const _PlatformLatencyRow({
    required this.target,
    required this.countryCode,
    required this.trackColor,
    required this.flowColor,
    required this.barWidthFactor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.trailing,
    required this.onRetest,
  });

  final _LatencyTarget target;
  final String? countryCode;
  final Color trackColor;
  final Color flowColor;
  final double barWidthFactor;
  final Color textColor;
  final Color secondaryTextColor;
  final Widget trailing;
  final VoidCallback onRetest;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PlatformBrandIcon(target: target),
        const SizedBox(width: 6),
        _RouteFlagBadge(countryCode: countryCode),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _FlowingLatencyBar(
                widthFactor: barWidthFactor,
                trackColor: trackColor,
                flowColor: flowColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    );
  }
}

class _PlatformBrandIcon extends StatelessWidget {
  const _PlatformBrandIcon({required this.target});

  final _LatencyTarget target;

  @override
  Widget build(BuildContext context) {
    final name = target.name.toLowerCase();
    if (name == 'youtube') {
      return _BrandImageIcon(
        tooltip: target.name,
        assetPath: 'assets/images/icon/latency_youtube.png',
      );
    }
    if (name == 'chatgpt') {
      return _BrandImageIcon(
        tooltip: target.name,
        assetPath: 'assets/images/icon/latency_chatgpt.png',
        tintInDarkMode: true,
      );
    }
    return _BrandImageIcon(
      tooltip: target.name,
      assetPath: 'assets/images/icon/latency_github.png',
      tintInDarkMode: true,
    );
  }
}

class _BrandImageIcon extends StatelessWidget {
  const _BrandImageIcon({
    required this.tooltip,
    required this.assetPath,
    this.tintInDarkMode = false,
  });

  final String tooltip;
  final String assetPath;
  final bool tintInDarkMode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = tintInDarkMode && isDark
        ? SurgeTheme.of(context).textPrimary
        : null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 25,
        height: 25,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          color: tintColor,
          colorBlendMode: tintColor == null ? null : BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _RouteFlagBadge extends StatelessWidget {
  const _RouteFlagBadge({required this.countryCode});

  final String? countryCode;

  String _countryCodeToEmoji(String code) {
    final c = code.toUpperCase();
    if (c.length != 2) return '';
    final firstLetter = c.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = c.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final flag = countryCode?.length == 2
        ? _countryCodeToEmoji(countryCode!)
        : null;
    return SizedBox(
      width: 20,
      height: 20,
      child: flag == null || flag.isEmpty
          ? Center(
              child: Icon(
                Icons.public_rounded,
                size: 13,
                color: surge.textSecondary,
              ),
            )
          : Center(
              child: Text(
                flag,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Twemoji',
                  fontSize: 15,
                  height: 1.0,
                ),
              ),
            ),
    );
  }
}

class _FlowingLatencyBar extends StatefulWidget {
  const _FlowingLatencyBar({
    required this.widthFactor,
    required this.trackColor,
    required this.flowColor,
  });

  final double widthFactor;
  final Color trackColor;
  final Color flowColor;

  @override
  State<_FlowingLatencyBar> createState() => _FlowingLatencyBarState();
}

class _FlowingLatencyBarState extends State<_FlowingLatencyBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: widget.trackColor)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widget.widthFactor,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final sweep = _controller.value;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.8 + 3.6 * sweep, 0),
                        end: Alignment(-0.2 + 3.6 * sweep, 0),
                        colors: [
                          widget.flowColor.withValues(alpha: 0.70),
                          widget.flowColor,
                          widget.flowColor.withValues(alpha: 0.74),
                        ],
                        stops: const [0, 0.48, 1],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
