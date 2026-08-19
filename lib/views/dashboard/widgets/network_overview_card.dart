import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
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
    required this.headerHeight,
    required this.chartHeight,
    required this.trafficTitleToChartGap,
    required this.latencyHeaderToRowsGap,
    required this.afterTrafficGap,
    required this.headerToChartGap,
    required this.chartToDividerGap,
    required this.dividerToTrafficGap,
    required this.detectionTopGap,
    required this.detectionBottomGap,
    required this.latencyRowGap,
  });

  final double headerHeight;
  final double chartHeight;
  final double trafficTitleToChartGap;
  final double latencyHeaderToRowsGap;
  final double afterTrafficGap;
  final double headerToChartGap;
  final double chartToDividerGap;
  final double dividerToTrafficGap;
  final double detectionTopGap;
  final double detectionBottomGap;
  final double latencyRowGap;
}

class NetworkOverviewCardLayoutCalculator {
  const NetworkOverviewCardLayoutCalculator._();

  static const double dividerHeight = 1;
  static const double detectionVerticalGap = 16;
  static const double pixelRoundingAllowance = 1;

  static double headerHeightFor(DashboardResponsiveLayout layout) =>
      math.max(layout.legacy(28), layout.textIcon(18));
  static double chartHeightFor(DashboardResponsiveLayout layout) =>
      layout.legacy(82);
  static double headerToChartGapFor(DashboardResponsiveLayout layout) =>
      layout.legacy(10);
  static double chartToDividerGapFor(DashboardResponsiveLayout layout) =>
      layout.legacy(16);
  static double dividerToTrafficGapFor(DashboardResponsiveLayout layout) =>
      layout.legacy(16);
  static double trafficTitleToChartGapFor(DashboardResponsiveLayout layout) =>
      layout.legacy(24);
  static double latencyHeaderToRowsGapFor(DashboardResponsiveLayout layout) =>
      layout.legacy(14);
  static double latencyRowGapFor(DashboardResponsiveLayout layout) =>
      layout.legacy(12);
  static double trafficToDividerGapFor(DashboardResponsiveLayout layout) =>
      layout.legacy(16);
  static double detectionBarHeightFor(DashboardResponsiveLayout layout) {
    const metricLineHeight = 16.0;
    final scaledLineHeight = metricLineHeight * layout.textScale;
    return layout.legacy(34) + math.max(0, scaledLineHeight - metricLineHeight);
  }

  static double detectionSectionHeightFor(DashboardResponsiveLayout layout) =>
      detectionVerticalGap * 2 + detectionBarHeightFor(layout);

  static double _trafficSectionMinHeightFor(DashboardResponsiveLayout layout) {
    final donutColumn =
        headerHeightFor(layout) +
        trafficTitleToChartGapFor(layout) +
        layout.legacy(78);
    final latencyColumn =
        headerHeightFor(layout) +
        latencyHeaderToRowsGapFor(layout) +
        layout.legacy(25) * 3 +
        latencyRowGapFor(layout) * 2;
    if (layout.requiresReflow) {
      return donutColumn + layout.geometry(12) + latencyColumn;
    }
    return math.max(donutColumn, latencyColumn);
  }

  static double naturalOuterHeightFor(DashboardResponsiveLayout layout) {
    return layout.legacy(16) +
        naturalInnerHeightFor(layout) +
        pixelRoundingAllowance;
  }

  static double naturalInnerHeightFor(DashboardResponsiveLayout layout) {
    final reflowHeaderExtra = layout.requiresReflow ? layout.geometry(32) : 0.0;
    final reflowTextExtra = layout.requiresReflow
        ? layout.legacy(72) * math.max(0, layout.textScale - 1)
        : 0.0;
    return headerHeightFor(layout) +
        reflowHeaderExtra +
        reflowTextExtra +
        headerToChartGapFor(layout) +
        chartHeightFor(layout) +
        chartToDividerGapFor(layout) +
        dividerHeight +
        dividerToTrafficGapFor(layout) +
        _trafficSectionMinHeightFor(layout) +
        trafficToDividerGapFor(layout) +
        dividerHeight +
        detectionSectionHeightFor(layout);
  }

  @visibleForTesting
  static NetworkOverviewCardLayout layoutFor({
    required double availableOuterHeight,
    required DashboardResponsiveLayout responsiveLayout,
    required double contentExpansionFraction,
  }) {
    final naturalOuterHeight = naturalOuterHeightFor(responsiveLayout);
    final resolvedOuterHeight = math.max(
      availableOuterHeight,
      naturalOuterHeight,
    );
    final extraHeight = resolvedOuterHeight - naturalOuterHeight;
    final distributedExtraHeight =
        extraHeight * contentExpansionFraction.clamp(0.0, 1.0);
    return NetworkOverviewCardLayout(
      headerHeight: headerHeightFor(responsiveLayout),
      chartHeight:
          chartHeightFor(responsiveLayout) + distributedExtraHeight * 0.40,
      headerToChartGap:
          headerToChartGapFor(responsiveLayout) + distributedExtraHeight * 0.10,
      chartToDividerGap:
          chartToDividerGapFor(responsiveLayout) +
          distributedExtraHeight * 0.075,
      dividerToTrafficGap:
          dividerToTrafficGapFor(responsiveLayout) +
          distributedExtraHeight * 0.075,
      trafficTitleToChartGap:
          trafficTitleToChartGapFor(responsiveLayout) +
          distributedExtraHeight * 0.10,
      latencyHeaderToRowsGap:
          latencyHeaderToRowsGapFor(responsiveLayout) +
          distributedExtraHeight * 0.06,
      latencyRowGap:
          latencyRowGapFor(responsiveLayout) + distributedExtraHeight * 0.02,
      afterTrafficGap:
          trafficToDividerGapFor(responsiveLayout) +
          distributedExtraHeight * 0.02,
      detectionTopGap: detectionVerticalGap,
      detectionBottomGap: detectionVerticalGap,
    );
  }
}

class SurgeNetworkOverviewCard extends ConsumerStatefulWidget {
  const SurgeNetworkOverviewCard({
    super.key,
    required this.layout,
    this.contentExpansionFraction = 0,
  });

  final DashboardResponsiveLayout layout;
  final double contentExpansionFraction;

  @override
  ConsumerState<SurgeNetworkOverviewCard> createState() =>
      _SurgeNetworkOverviewCardState();
}

class _SurgeNetworkOverviewCardState
    extends ConsumerState<SurgeNetworkOverviewCard> {
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

  String _overviewTitle(BuildContext context) {
    return context.appLocalizations.networkOverview;
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
    if (NavigationTrace.enabled) {
      NavigationTrace.networkLatencyTimerActive = false;
    }
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
      if (NavigationTrace.enabled) {
        NavigationTrace.networkLatencyTimerActive = false;
      }
      return;
    }
    if (_latencyRefreshTimer != null) return;
    _latencyRefreshTimer = Timer.periodic(_latencyRefreshInterval, (_) {
      unawaited(_testLatencies(force: true));
    });
    if (NavigationTrace.enabled) {
      NavigationTrace.networkLatencyTimerActive = true;
    }
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
    final semantic = surge.semantic;
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final totalTraffic = ref.watch(totalTrafficProvider);
    final countryCode = ref.watch(
      networkDetectionProvider.select((s) => s.ipInfo?.countryCode),
    );
    final networkIpInfo = ref.watch(
      networkDetectionProvider.select((s) => s.ipInfo),
    );
    final networkIsLoading = ref.watch(
      networkDetectionProvider.select((s) => s.isLoading),
    );
    final networkHasChecked = ref.watch(
      networkDetectionProvider.select((s) => s.hasChecked),
    );
    final isForeground = ref.watch(appForegroundProvider);
    final isDashboardActive = ref.watch(
      currentPageLabelProvider.select((l) => l == PageLabel.dashboard),
    );
    final shouldAnimateLoading =
        isForeground && isDashboardActive && networkIsLoading;
    final hasPendingLatency = _latencyResults.values.any((r) => r.pending);
    final shouldAnimatePending =
        isForeground && isDashboardActive && hasPendingLatency;
    final isStart = ref.watch(isStartProvider);
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
        ? semantic.dashboardDynamicActive
        : semantic.dashboardInactive;
    final downloadColor = isStart
        ? semantic.dashboardActiveGreen
        : semantic.dashboardInactiveVariant;
    final lineFillStartAlpha = isStart ? 0.16 : 1.0;
    final lineFillEndAlpha = isStart ? 0.03 : 0.08;
    final responsiveLayout = widget.layout;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        responsiveLayout.cardHorizontalPadding,
        responsiveLayout.legacy(16),
        responsiveLayout.cardHorizontalPadding,
        0,
      ),
      decoration: BoxDecoration(
        color: surge.card,
        borderRadius: BorderRadius.circular(responsiveLayout.cardRadius),
        border: Border.all(
          color: surge.separator,
          width: surge.spacing.hairline,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = NetworkOverviewCardLayoutCalculator.layoutFor(
            availableOuterHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight + responsiveLayout.legacy(16)
                : NetworkOverviewCardLayoutCalculator.naturalOuterHeightFor(
                    responsiveLayout,
                  ),
            responsiveLayout: responsiveLayout,
            contentExpansionFraction: widget.contentExpansionFraction,
          );
          final overviewLabels = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: responsiveLayout.textIcon(18),
                height: layout.headerHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    SurgeIcons.network,
                    color: isStart ? surge.primary : surge.inactive,
                    size: responsiveLayout.textIcon(18),
                  ),
                ),
              ),
              SizedBox(width: responsiveLayout.geometry(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _overviewTitle(context),
                      style: context.typography.cardTitle.copyWith(
                        color: surge.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final liveSpeed = ValueListenableBuilder<Traffic>(
            valueListenable: currentSpeedNotifier,
            builder: (_, speed, _) => _LiveSpeedBadge(
              up: speed.up,
              down: speed.down,
              upColor: uploadColor,
              downColor: downloadColor,
              layout: responsiveLayout,
              reflow: responsiveLayout.requiresReflow,
            ),
          );
          final overviewHeader = responsiveLayout.requiresReflow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    overviewLabels,
                    SizedBox(height: responsiveLayout.geometry(8)),
                    Align(alignment: Alignment.centerRight, child: liveSpeed),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: overviewLabels),
                    SizedBox(width: responsiveLayout.geometry(12)),
                    liveSpeed,
                  ],
                );
          final trafficSummary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: responsiveLayout.textIcon(18),
                    height: layout.headerHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        SurgeIcons.traffic,
                        size: responsiveLayout.textIcon(18),
                        color: surge.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(width: responsiveLayout.geometry(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appLocalizations.trafficUsage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.cardTitle.copyWith(
                            color: surge.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: layout.trafficTitleToChartGap),
              Padding(
                padding: EdgeInsets.only(left: responsiveLayout.geometry(2)),
                child: SizedBox(
                  width: responsiveLayout.legacy(78),
                  height: responsiveLayout.legacy(78),
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
          );
          final latencyPanel = Column(
            children: [
              SizedBox(
                height: layout.headerHeight,
                child: Row(
                  children: [
                    const Spacer(),
                    _TotalTrafficBadge(
                      up: totalTraffic.up,
                      down: totalTraffic.down,
                      upColor: uploadColor,
                      downColor: downloadColor,
                      layout: responsiveLayout,
                    ),
                  ],
                ),
              ),
              SizedBox(height: layout.latencyHeaderToRowsGap),
              _PlatformLatencyPanel(
                targets: _latencyTargets,
                results: _latencyResults,
                fallbackCountryCode: countryCode,
                activeColor: semantic.dashboardDynamicActive,
                fillColor: surge.fill,
                textColor: surge.textPrimary,
                secondaryTextColor: surge.textSecondary,
                dangerColor: surge.red,
                latencyGood: semantic.latencyGood,
                latencyMedium: semantic.latencyMedium,
                latencyBad: semantic.latencyBad,
                onRetest: () => unawaited(_testLatencies(force: true)),
                shouldAnimatePending: shouldAnimatePending,
                rowGap: layout.latencyRowGap,
                layout: responsiveLayout,
              ),
            ],
          );
          final trafficSection = responsiveLayout.requiresReflow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    trafficSummary,
                    SizedBox(height: responsiveLayout.geometry(12)),
                    latencyPanel,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: responsiveLayout.geometry(112),
                      child: trafficSummary,
                    ),
                    Expanded(child: latencyPanel),
                  ],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              overviewHeader,
              SizedBox(height: layout.headerToChartGap),
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
              SizedBox(height: layout.chartToDividerGap),
              Container(height: 1, color: surge.separator),
              SizedBox(height: layout.dividerToTrafficGap),
              trafficSection,
              SizedBox(height: layout.afterTrafficGap),
              Container(height: 1, color: surge.separator),
              SizedBox(height: layout.detectionTopGap),
              _NetworkDetectionBar(
                ipInfo: networkIpInfo,
                isLoading: networkIsLoading,
                hasChecked: networkHasChecked,
                shouldAnimate: shouldAnimateLoading,
                primaryColor: surge.primary,
                textColor: surge.textPrimary,
                secondaryTextColor: surge.textSecondary,
                fillColor: surge.fill,
                dangerColor: surge.red,
                label: appLocalizations.networkDetection,
                layout: responsiveLayout,
              ),
              SizedBox(height: layout.detectionBottomGap),
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
    required this.layout,
    required this.reflow,
  });

  final num up;
  final num down;
  final Color upColor;
  final Color downColor;
  final DashboardResponsiveLayout layout;
  final bool reflow;

  @override
  Widget build(BuildContext context) {
    final lines = [
      _LiveSpeedLine(
        icon: SurgeIcons.arrowUp,
        value: '${up.traffic.show}/s',
        color: upColor,
        layout: layout,
      ),
      _LiveSpeedLine(
        icon: SurgeIcons.arrowDown,
        value: '${down.traffic.show}/s',
        color: downColor,
        layout: layout,
      ),
    ];
    return reflow
        ? Wrap(
            spacing: layout.geometry(12),
            runSpacing: layout.geometry(6),
            alignment: WrapAlignment.end,
            children: lines,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              lines.first,
              SizedBox(width: layout.geometry(12)),
              lines.last,
            ],
          );
  }
}

class _LiveSpeedLine extends StatelessWidget {
  const _LiveSpeedLine({
    required this.icon,
    required this.value,
    required this.color,
    required this.layout,
  });

  final IconData icon;
  final String value;
  final Color color;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: layout.textIcon(14), color: color),
        SizedBox(width: layout.geometry(4)),
        Text(value, style: context.typography.metric.copyWith(color: color)),
      ],
    );
  }
}

class _NetworkDetectionBar extends StatelessWidget {
  const _NetworkDetectionBar({
    required this.ipInfo,
    required this.isLoading,
    required this.hasChecked,
    required this.shouldAnimate,
    required this.primaryColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.fillColor,
    required this.dangerColor,
    required this.label,
    required this.layout,
  });

  final DashboardResponsiveLayout layout;

  final IpInfo? ipInfo;
  final bool isLoading;
  final bool hasChecked;
  final bool shouldAnimate;
  final Color primaryColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color fillColor;
  final Color dangerColor;
  final String label;

  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return countryCode;
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final height = NetworkOverviewCardLayoutCalculator.detectionBarHeightFor(
      layout,
    );
    // Local variables for type promotion (fields can't be promoted by null check)
    final localIpInfo = ipInfo;
    final localIsLoading = isLoading;

    Widget valueWidget;
    if (localIpInfo != null) {
      valueWidget = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _countryCodeToEmoji(localIpInfo.countryCode),
            maxLines: 1,
            style: context.typography.controlLabel.copyWith(
              fontFamily: FontFamily.twEmoji.value,
            ),
          ),
          SizedBox(width: layout.geometry(6)),
          Flexible(
            child: TooltipText(
              text: Text(
                localIpInfo.ip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: context.typography.dashboardIpValue.copyWith(
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (localIsLoading) {
      valueWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: SizedBox(
              width: layout.geometry(12),
              height: layout.geometry(12),
              child: CommonCircleLoading(
                color: primaryColor,
                active: shouldAnimate,
              ),
            ),
          ),
          SizedBox(width: layout.geometry(6)),
          Text(
            context.appLocalizations.loading,
            maxLines: 1,
            style: context.typography.compactMetric.copyWith(
              color: secondaryTextColor,
            ),
          ),
        ],
      );
    } else if (hasChecked) {
      valueWidget = Text(
        'Timeout',
        maxLines: 1,
        style: context.typography.compactMetric.copyWith(color: dangerColor),
      );
    } else {
      valueWidget = const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: layout.geometry(14)),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(layout.geometry(22)),
      ),
      child: Row(
        children: [
          Icon(
            SurgeIcons.networkCheck,
            size: layout.geometry(16),
            color: primaryColor,
          ),
          SizedBox(width: layout.geometry(8)),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: context.typography.supporting.copyWith(
              color: secondaryTextColor,
            ),
          ),
          SizedBox(width: layout.geometry(12)),
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
    required this.layout,
  });

  final num up;
  final num down;
  final Color upColor;
  final Color downColor;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrafficAmount(
          icon: SurgeIcons.arrowUp,
          value: up,
          color: upColor,
          layout: layout,
        ),
        SizedBox(width: layout.geometry(12)),
        _TrafficAmount(
          icon: SurgeIcons.arrowDown,
          value: down,
          color: downColor,
          layout: layout,
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
    required this.layout,
  });

  final IconData icon;
  final num value;
  final Color color;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    final formatted = value.traffic.show;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: layout.textIcon(14), color: color),
        SizedBox(width: layout.geometry(4)),
        Text(
          formatted,
          style: context.typography.metric.copyWith(color: color),
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
    required this.latencyGood,
    required this.latencyMedium,
    required this.latencyBad,
    required this.onRetest,
    required this.shouldAnimatePending,
    required this.rowGap,
    required this.layout,
  });

  final List<_LatencyTarget> targets;
  final Map<String, _LatencyResult> results;
  final String? fallbackCountryCode;
  final Color activeColor;
  final Color fillColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color dangerColor;
  final Color latencyGood;
  final Color latencyMedium;
  final Color latencyBad;
  final VoidCallback onRetest;
  final bool shouldAnimatePending;
  final double rowGap;
  final DashboardResponsiveLayout layout;

  Color _flowColor(_LatencyResult? result) {
    if (result == null || result.pending) return activeColor;
    final latency = result.latency;
    if (latency == null) return latencyBad;
    if (latency < 180) return latencyGood;
    if (latency < 420) return latencyMedium;
    return latencyBad;
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
      return RepaintBoundary(
        child: SizedBox(
          width: layout.geometry(12),
          height: layout.geometry(12),
          child: CommonCircleLoading(
            color: activeColor,
            active: shouldAnimatePending,
          ),
        ),
      );
    }
    if (result?.timeout == true) {
      return Text(
        'Timeout',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: _valueStyle(context).copyWith(color: dangerColor),
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
    return context.typography.dashboardLatencyValue;
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
            active: results[target.name]?.pending == true,
            layout: layout,
          ),
          if (target != targets.last) SizedBox(height: rowGap),
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
    this.active = false,
    required this.layout,
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
  final bool active;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PlatformBrandIcon(target: target, layout: layout),
        SizedBox(width: layout.geometry(6)),
        _RouteFlagBadge(countryCode: countryCode, layout: layout),
        SizedBox(width: layout.geometry(8)),
        Expanded(
          child: SurgePressable(
            compact: true,
            behavior: HitTestBehavior.opaque,
            onTap: onRetest,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: layout.legacy(8)),
              child: _FlowingLatencyBar(
                widthFactor: barWidthFactor,
                trackColor: trackColor,
                flowColor: flowColor,
                layout: layout,
                active: active,
              ),
            ),
          ),
        ),
        SizedBox(width: layout.geometry(8)),
        SizedBox(
          width: layout.geometry(50),
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    );
  }
}

class _PlatformBrandIcon extends StatelessWidget {
  const _PlatformBrandIcon({required this.target, required this.layout});

  final _LatencyTarget target;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    final name = target.name.toLowerCase();
    if (name == 'youtube') {
      return _BrandImageIcon(
        tooltip: target.name,
        assetPath: 'assets/images/icon/latency_youtube.png',
        layout: layout,
      );
    }
    if (name == 'chatgpt') {
      return _BrandImageIcon(
        tooltip: target.name,
        assetPath: 'assets/images/icon/latency_chatgpt.png',
        tintInDarkMode: true,
        layout: layout,
      );
    }
    return _BrandImageIcon(
      tooltip: target.name,
      assetPath: 'assets/images/icon/latency_github.png',
      tintInDarkMode: true,
      layout: layout,
    );
  }
}

class _BrandImageIcon extends StatelessWidget {
  const _BrandImageIcon({
    required this.tooltip,
    required this.assetPath,
    this.tintInDarkMode = false,
    required this.layout,
  });

  final String tooltip;
  final String assetPath;
  final bool tintInDarkMode;
  final DashboardResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = tintInDarkMode && isDark
        ? SurgeTheme.of(context).textPrimary
        : null;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: layout.legacy(25),
        height: layout.legacy(25),
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
  const _RouteFlagBadge({required this.countryCode, required this.layout});

  final String? countryCode;
  final DashboardResponsiveLayout layout;

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
      width: layout.legacy(20),
      height: layout.legacy(20),
      child: flag == null || flag.isEmpty
          ? Center(
              child: Icon(
                SurgeIcons.network,
                size: layout.geometry(13),
                color: surge.textSecondary,
              ),
            )
          : Center(
              child: Text(
                flag,
                maxLines: 1,
                style: context.typography.controlLabel.copyWith(
                  fontFamily: 'Twemoji',
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
    required this.layout,
    this.active = false,
  });

  final double widthFactor;
  final Color trackColor;
  final Color flowColor;
  final DashboardResponsiveLayout layout;
  final bool active;

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
      duration: SurgeMotion.latencyFlow,
    );
    if (widget.active) {
      _controller.repeat();
    }
    if (NavigationTrace.enabled) {
      NavigationTrace.networkLatencyBarRepeating = _controller.isAnimating;
    }
  }

  @override
  void didUpdateWidget(covariant _FlowingLatencyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
    if (NavigationTrace.enabled) {
      NavigationTrace.networkLatencyBarRepeating = _controller.isAnimating;
    }
  }

  @override
  void dispose() {
    if (NavigationTrace.enabled) {
      NavigationTrace.networkLatencyBarRepeating = false;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(surge.radii.chart),
        child: SizedBox(
          height: widget.layout.legacy(8),
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
      ),
    );
  }
}
