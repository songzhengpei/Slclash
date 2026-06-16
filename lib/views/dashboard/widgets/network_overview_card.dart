import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
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
  static const _latencyRefreshInterval = Duration(seconds: 15);
  static const _latencyTargets = [
    _LatencyTarget(name: 'GitHub', url: 'https://github.com'),
    _LatencyTarget(name: 'YouTube', url: 'https://www.youtube.com'),
    _LatencyTarget(name: 'ChatGPT', url: 'https://chatgpt.com'),
  ];

  static const _latencyTimeout = Duration(seconds: 10);

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

  Future<int?> _measureLatency(String url) async {
    final uri = Uri.parse(url);
    final host = uri.host;
    final port = uri.port != 0 ? uri.port : 443;
    final stopwatch = Stopwatch()..start();
    try {
      // TCP + TLS handshake — measures DNS + TCP + TLS, no HTTP overhead
      final socket = await SecureSocket.connect(host, port,
          timeout: _latencyTimeout);
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      stopwatch.stop();
      return null;
    }
  }

  Future<void> _testLatencies({bool force = false}) async {
    if (_isTestingLatencies) return;
    if (!force && _latencyResults.isNotEmpty) return;
    setState(() {
      _isTestingLatencies = true;
      for (final target in _latencyTargets) {
        _latencyResults[target.name] = const _LatencyResult.pending();
      }
    });
    final entries = await Future.wait(
      _latencyTargets.map((target) async {
        final latency = await _measureLatency(target.url);
        return MapEntry(target.name, _LatencyResult(latency));
      }),
    );
    if (!mounted) return;
    setState(() {
      _latencyResults
        ..clear()
        ..addEntries(entries);
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
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: SizedBox(
                        width: 66,
                        height: 66,
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
                      isStart: isStart,
                      activeColor: uploadColor,
                      secondaryActiveColor: downloadColor,
                      inactiveColor: dashboardInactiveFill,
                      fillColor: surge.fill,
                      textColor: surge.textPrimary,
                      secondaryTextColor: surge.textSecondary,
                      dangerColor: surge.red,
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
        children: [
          Text(
            _countryCodeToEmoji(ipInfo.countryCode),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 6),
          Text(
            ipInfo.ip,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.0,
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
          const Spacer(),
          valueWidget,
        ],
      ),
    );
  }
}

class _LatencyTarget {
  const _LatencyTarget({required this.name, required this.url});

  final String name;
  final String url;
}

class _LatencyResult {
  const _LatencyResult(this.latency) : pending = false;
  const _LatencyResult.pending() : latency = null, pending = true;

  final int? latency;
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
    required this.isStart,
    required this.activeColor,
    required this.secondaryActiveColor,
    required this.inactiveColor,
    required this.fillColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.dangerColor,
  });

  final List<_LatencyTarget> targets;
  final Map<String, _LatencyResult> results;
  final bool isStart;
  final Color activeColor;
  final Color secondaryActiveColor;
  final Color inactiveColor;
  final Color fillColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color dangerColor;

  Color _flowColor(_LatencyResult? result) {
    if (result == null || result.pending) return inactiveColor;
    if (!isStart) return inactiveColor;
    final latency = result.latency;
    if (latency == null) return dashboardSunsetError;
    if (latency < 180) return dashboardSunsetSuccess;
    if (latency < 420) return dashboardSunsetWarning;
    return dashboardSunsetError;
  }

  Color _trackColor(_LatencyResult? result) {
    if (!isStart) return fillColor;
    final flow = _flowColor(result);
    return Color.lerp(flow, Colors.black, 0.76)!.withValues(alpha: 0.58);
  }

  double _barWidth(_LatencyResult? result) {
    if (result == null || result.pending) return 0;
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
            name: target.name,
            isStart: isStart,
            trackColor: _trackColor(results[target.name]),
            flowColor: _flowColor(results[target.name]),
            barWidthFactor: _barWidth(results[target.name]),
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            trailing: _value(context, results[target.name]),
          ),
          if (target != targets.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LatencyRefreshButton extends StatelessWidget {
  const _LatencyRefreshButton({
    required this.isTesting,
    required this.color,
    required this.inactiveColor,
    required this.onRefresh,
  });

  final bool isTesting;
  final Color color;
  final Color inactiveColor;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: IconButton(
        onPressed: isTesting ? null : onRefresh,
        icon: AnimatedRotation(
          turns: isTesting ? 1 : 0,
          duration: commonDuration,
          child: const Icon(Icons.refresh_rounded, size: 15),
        ),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        color: color,
        disabledColor: inactiveColor,
        tooltip: 'Refresh',
      ),
    );
  }
}

class _PlatformLatencyRow extends StatelessWidget {
  const _PlatformLatencyRow({
    required this.name,
    required this.isStart,
    required this.trackColor,
    required this.flowColor,
    required this.barWidthFactor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.trailing,
  });

  final String name;
  final bool isStart;
  final Color trackColor;
  final Color flowColor;
  final double barWidthFactor;
  final Color textColor;
  final Color secondaryTextColor;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: const Offset(-10, 0),
          child: SizedBox(
            width: 56,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: context.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.0,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 0),
        Expanded(
          child: Transform.translate(
            offset: const Offset(-8, 0),
            child: _FlowingLatencyBar(
              widthFactor: barWidthFactor,
              trackColor: trackColor,
              flowColor: flowColor,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Transform.translate(
          offset: const Offset(-7, 0),
          child: SizedBox(
            width: 46,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ),
      ],
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
