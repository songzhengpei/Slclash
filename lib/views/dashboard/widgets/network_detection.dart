import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'surge_dashboard_card.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection> {
  String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final networkDetection = ref.watch(networkDetectionProvider);
    final ipInfo = networkDetection.ipInfo;
    final isLoading = networkDetection.isLoading;
    final emojiTextStyle = context.textTheme.titleMedium?.copyWith(
      fontFamily: FontFamily.twEmoji.value,
      fontSize: 18,
      letterSpacing: 0,
    );

    return SizedBox(
      height: getWidgetHeight(1),
      child: SurgeDashboardCard(
        title: appLocalizations.networkDetection,
        subtitle: 'Network',
        icon: Icons.network_check_rounded,
        height: getWidgetHeight(1),
        trailing: SizedBox.square(
          dimension: 28,
          child: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              globalState.showMessage(
                title: appLocalizations.tip,
                message: TextSpan(text: appLocalizations.detectionTip),
                cancelable: false,
              );
            },
            icon: Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: surge.textSecondary,
            ),
          ),
        ),
        child: FadeThroughBox(
          child: ipInfo != null
              ? Row(
                  key: const ValueKey('network-ok'),
                  children: [
                    Text(
                      _countryCodeToEmoji(ipInfo.countryCode),
                      style: emojiTextStyle,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ipInfo.ip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: surge.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                )
              : isLoading == false
              ? Text(
                  key: const ValueKey('network-timeout'),
                  'Timeout',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: surge.red.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                )
              : Align(
                  key: const ValueKey('network-loading'),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CommonCircleLoading(color: surge.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '检测中...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleSmall?.copyWith(
                            color: surge.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
