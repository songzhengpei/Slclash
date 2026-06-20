import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/dashboard_palette.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SurgeNetworkOverviewCard extends ConsumerStatefulWidget {
  const SurgeNetworkOverviewCard({super.key});

  @override
  ConsumerState<SurgeNetworkOverviewCard> createState() =>
      _SurgeNetworkOverviewCardState();
}

class _SurgeNetworkOverviewCardState
    extends ConsumerState<SurgeNetworkOverviewCard> {
  static const _cardRadius = 26.0;
  static const _latencyRefreshInterval = Duration(seconds: 60);
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
  bool _lastIsStart = false;
  int _lastCheckIpNum = 0;
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

  static const Map<String, String> _countryKeywords = {
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

  /// Convert emoji flag (e.g. 🇭🇰) to ISO 3166-1 alpha-2 code (e.g. HK).
  static String? _emojiFlagToCountryCode(String flag) {
    final runes = flag.runes.toList();
    if (runes.length != 2) return null;
    final first = runes[0] - 0x1F1E6 + 0x41;
    final second = runes[1] - 0x1F1E6 + 0x41;
    if (first < 0x41 || first > 0x5A) return null;
    if (second < 0x41 || second > 0x5A) return null;
    return String.fromCharCodes([first, second]);
  }

  /// Extract the last non-empty chain entry as route name.
  static String? _extractRouteNameFromTracker(TrackerInfo tracker) {
    final chains = tracker.chains
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (chains.isEmpty) return null;
    return chains.last;
  }

  static bool _isDirectRoute(String? routeName) {
    if (routeName == null) return false;
    final upper = routeName.trim().toUpperCase();
    return upper == 'DIRECT' || upper.contains('DIRECT');
  }

  TrackerInfo? _findTrackerForTarget(
    _LatencyTarget target,
    List<TrackerInfo> requests, {
    required Set<String> beforeRequestIds,
  }) {
    final targetHost = target.host.toLowerCase();
    final targetBareHost = target.bareHost.toLowerCase();
    for (final request in requests.reversed) {
      // Skip connections that existed before the probe
      if (beforeRequestIds.contains(request.id)) continue;
      final metadata = request.metadata;
      final host = metadata.host.toLowerCase();
      final remoteDestination = metadata.remoteDestination.toLowerCase();
      // Priority 1: exact host match
      if (host == targetHost || host == targetBareHost) return request;
      // Priority 2: subdomain match (e.g. raw.github.com)
      if (host.endsWith('.$targetBareHost')) return request;
      // Priority 3: remoteDestination contains bare host
      if (remoteDestination.contains(targetBareHost)) return request;
    }
    return null;
  }

  /// Wait up to 3s for a tracker to appear for the given target.
  Future<TrackerInfo?> _waitTrackerForTarget(
    _LatencyTarget target, {
    required Set<String> beforeRequestIds,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      final tracker = _findTrackerForTarget(
        target,
        ref.read(requestsProvider).list,
        beforeRequestIds: beforeRequestIds,
      );
      if (tracker != null) return tracker;
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return null;
  }

  String? _inferCountryCodeFromRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) return null;
    final name = routeName.trim();
    // 1. Extract embedded emoji flag and convert to ISO code
    final embeddedFlag = RegExp(
      r'[\u{1F1E6}-\u{1F1FF}]{2}',
      unicode: true,
    ).firstMatch(name)?.group(0);
    if (embeddedFlag != null) {
      return _emojiFlagToCountryCode(embeddedFlag);
    }
    // 2. Match country keywords
    final lowerName = name.toLowerCase();
    for (final entry in _countryKeywords.entries) {
      final isShort = RegExp(r'^[a-z]{2,3}$').hasMatch(entry.key);
      final matched = isShort
          ? RegExp('(^|[^a-z])${RegExp.escape(entry.key)}([^a-z]|\$)')
              .hasMatch(lowerName)
          : lowerName.contains(entry.key);
      if (matched) return entry.value;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastIsStart = ref.read(isStartProvider);
      unawaited(_testLatencies());
      _syncLatencyRefreshTimer();
    });
  }

  @override
  void dispose() {
    _latencyRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncLatencyRefreshTimer() {
    if (_latencyRefreshTimer != null) return;
    _latencyRefreshTimer = Timer.periodic(_latencyRefreshInterval, (_) {
      unawaited(_testLatencies(force: true));
    });
  }

  Future<(int?, HttpClient)> _measureLatency(
    _LatencyTarget target,
  ) async {
    Future<HttpClientResponse> doRequest(
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
    final uri = Uri.parse(target.probeUrl);
    final stopwatch = Stopwatch()..start();
    try {
      HttpClientResponse response;
      try {
        response = await doRequest(client, uri, 'HEAD');
      } catch (_) {
        response = await doRequest(client, uri, 'GET');
      }
      stopwatch.stop();
      unawaited(response.drain<void>());
      return (stopwatch.elapsedMilliseconds, client);
    } catch (_) {
      stopwatch.stop();
      return (null, client);
    }
  }

  Future<String?> _getExitCountryCode() async {
    final cancelToken = CancelToken();
    try {
      final result = await request
          .checkIp(cancelToken: cancelToken)
          .timeout(const Duration(seconds: 5));
      return result.data?.countryCode;
    } catch (_) {
      cancelToken.cancel();
      return null;
    }
  }

  Future<void> _testLatencies({bool force = false}) async {
    if (_isTestingLatencies) return;
    if (!force && _latencyResults.isNotEmpty) return;
    final isStart = ref.read(isStartProvider);
    setState(() {
      _isTestingLatencies = true;
      for (final target in _latencyTargets) {
        _latencyResults[target.name] = const _LatencyResult.pending();
      }
    });

    // Detect exit country via IP API (shared fallback when proxy is off)
    String? fallbackCountryCode;
    if (!isStart) {
      fallbackCountryCode = await _getExitCountryCode();
    }

    // Serial probing: one platform at a time to avoid tracker confusion
    final entries = <MapEntry<String, _LatencyResult>>[];
    for (final target in _latencyTargets) {
      if (!mounted) break;
      final entry = await _testSingleLatencyTarget(
        target,
        isStart: isStart,
        fallbackCountryCode: fallbackCountryCode,
      );
      entries.add(entry);
    }
    if (!mounted) return;
    setState(() {
      _latencyResults
        ..clear()
        ..addEntries(entries);
      _isTestingLatencies = false;
    });
  }

  Future<MapEntry<String, _LatencyResult>> _testSingleLatencyTarget(
    _LatencyTarget target, {
    required bool isStart,
    required String? fallbackCountryCode,
  }) async {
    debugPrint('[LatencyProbe] target=${target.name} start');
    debugPrint('[LatencyProbe] target=${target.name} probeUrl=${target.probeUrl}');

    // Record existing request IDs before probe
    final beforeRequestIds = ref
        .read(requestsProvider)
        .list
        .map((item) => item.id)
        .toSet();
    debugPrint(
      '[LatencyProbe] target=${target.name} '
      'beforeRequestCount=${beforeRequestIds.length}',
    );

    // Start probe and tracker polling concurrently
    final probeFuture = _measureLatency(target);
    final trackerFuture = isStart
        ? _waitTrackerForTarget(
            target,
            beforeRequestIds: beforeRequestIds,
          )
        : Future<TrackerInfo?>.value(null);

    final (latency, client) = await probeFuture;
    debugPrint('[LatencyProbe] target=${target.name} latency=$latency');

    try {
      String? countryCode;
      if (isStart) {
        // Try immediate match first (probe just finished, tracker likely still in list)
        var tracker = _findTrackerForTarget(
          target,
          ref.read(requestsProvider).list,
          beforeRequestIds: beforeRequestIds,
        );
        // If no immediate match, wait for the polling future
        tracker ??= await trackerFuture;
        if (!mounted) {
          return MapEntry(target.name, _LatencyResult(latency));
        }

        if (tracker != null) {
          final routeName = _extractRouteNameFromTracker(tracker);
          debugPrint('[LatencyProbe] target=${target.name} matched=true');
          debugPrint('[LatencyProbe] target=${target.name} trackerId=${tracker.id}');
          debugPrint(
            '[LatencyProbe] target=${target.name} '
            'metadata.host=${tracker.metadata.host}',
          );
          debugPrint(
            '[LatencyProbe] target=${target.name} '
            'metadata.remoteDestination=${tracker.metadata.remoteDestination}',
          );
          debugPrint(
            '[LatencyProbe] target=${target.name} '
            'metadata.destinationIP=${tracker.metadata.destinationIP}',
          );
          debugPrint(
            '[LatencyProbe] target=${target.name} '
            'chains=${tracker.chains}',
          );
          debugPrint(
            '[LatencyProbe] target=${target.name} rule=${tracker.rule}',
          );
          debugPrint(
            '[LatencyProbe] target=${target.name} '
            'rulePayload=${tracker.rulePayload}',
          );
          debugPrint(
            '[LatencyProbe] target=${target.name} routeName=$routeName',
          );

          if (_isDirectRoute(routeName)) {
            // DIRECT route: use real exit IP country
            countryCode = await _getExitCountryCode();
            debugPrint(
              '[LatencyProbe] target=${target.name} '
              'countryCode=$countryCode (DIRECT)',
            );
          } else {
            countryCode = _inferCountryCodeFromRoute(routeName);
            debugPrint(
              '[LatencyProbe] target=${target.name} '
              'countryCode=$countryCode (route)',
            );
          }
        } else {
          debugPrint('[LatencyProbe] target=${target.name} matched=false');
        }
      }
      // Fallback to IP-based detection
      countryCode ??= fallbackCountryCode;
      return MapEntry(
        target.name,
        _LatencyResult(latency, countryCode: countryCode),
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final totalTraffic = ref.watch(totalTrafficProvider);
    final networkDetection = ref.watch(networkDetectionProvider);
    final isStart = ref.watch(isStartProvider);
    final checkIpNum = ref.watch(checkIpNumProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLatencyRefreshTimer();
      if (isStart && !_lastIsStart) {
        unawaited(_testLatencies(force: true));
      }
      if (checkIpNum != _lastCheckIpNum && _lastCheckIpNum != 0) {
        unawaited(_testLatencies(force: true));
      }
      _lastIsStart = isStart;
      _lastCheckIpNum = checkIpNum;
    });
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
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: surge.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: surge.separator),
      ),
      child: Column(
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
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
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
          const SizedBox(height: 14),
          Container(height: 1, color: surge.separator),
          const SizedBox(height: 14),
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
                                style: context.textTheme.titleSmall?.copyWith(
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
                      ],
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: SizedBox(
                        width: 78,
                        height: 78,
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
                    const SizedBox(height: 26),
                    _PlatformLatencyPanel(
                      targets: _latencyTargets,
                      results: _latencyResults,
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
          const SizedBox(height: 14),
          Container(height: 1, color: surge.separator),
          const SizedBox(height: 14),
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
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
  const _LatencyResult(this.latency, {this.countryCode})
      : pending = false;
  const _LatencyResult.pending()
      : latency = null,
        countryCode = null,
        pending = true;

  final int? latency;
  final String? countryCode;
  final bool pending;

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
    required this.activeColor,
    required this.fillColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.dangerColor,
    required this.onRetest,
  });

  final List<_LatencyTarget> targets;
  final Map<String, _LatencyResult> results;
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
          _PlatformLatencyRow(
            target: target,
            countryCode: results[target.name]?.countryCode,
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
    final upper = code.toUpperCase();
    if (upper.length != 2) return '';
    final firstLetter = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final flag =
        countryCode != null ? _countryCodeToEmoji(countryCode!) : null;
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
