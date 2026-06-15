import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SurgeNetworkOverviewCard extends ConsumerWidget {
  const SurgeNetworkOverviewCard({super.key});

  static const _cardRadius = 26.0;
  bool _isChinese(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
  }

  String _overviewTitle(BuildContext context) {
    return _isChinese(context) ? '网络概览' : 'Network Overview';
  }

  String _uploadTotalLabel(BuildContext context) {
    return _isChinese(context) ? '上传总计' : 'Upload total';
  }

  String _downloadTotalLabel(BuildContext context) {
    return _isChinese(context) ? '下载总计' : 'Download total';
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
  Widget build(BuildContext context, WidgetRef ref) {
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
    final uploadColor = isStart ? surge.primary : surge.inactive;
    final downloadColor = isStart ? surge.green : surge.inactiveVariant;
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
              Expanded(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appLocalizations.trafficUsage,
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
                      ],
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
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
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 54),
                  child: Column(
                    children: [
                      _TrafficLineItem(
                        icon: Icons.arrow_upward_rounded,
                        label: _uploadTotalLabel(context),
                        value: totalTraffic.up,
                        color: uploadColor,
                      ),
                      const SizedBox(height: 18),
                      _TrafficLineItem(
                        icon: Icons.arrow_downward_rounded,
                        label: _downloadTotalLabel(context),
                        value: totalTraffic.down,
                        color: downloadColor,
                      ),
                    ],
                  ),
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
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            ipInfo.ip,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
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
          fontSize: 11,
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
              fontSize: 9,
              fontWeight: FontWeight.w400,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.network_check_rounded, size: 15, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 11,
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

class _TrafficLineItem extends StatelessWidget {
  const _TrafficLineItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final formatted = value.traffic;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelMedium?.copyWith(
              color: surge.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.08,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        RichText(
          textAlign: TextAlign.right,
          text: TextSpan(
            children: [
              TextSpan(
                text: formatted.value,
                style: context.textTheme.titleMedium?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
              TextSpan(
                text: ' ${formatted.unit}',
                style: context.textTheme.labelMedium?.copyWith(
                  color: surge.textSecondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
