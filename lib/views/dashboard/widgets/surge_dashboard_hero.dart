import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/dashboard_palette.dart';
import 'package:fl_clash/views/proxies/common.dart' as proxy_common;
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _heroFillDuration = Duration(milliseconds: 1500);
const _statusLightPulseDuration = Duration(milliseconds: 112);

class SurgeDashboardHero extends ConsumerStatefulWidget {
  const SurgeDashboardHero({super.key});

  @override
  ConsumerState<SurgeDashboardHero> createState() => _SurgeDashboardHeroState();
}

class _SurgeDashboardHeroState extends ConsumerState<SurgeDashboardHero>
    with TickerProviderStateMixin {
  Timer? _failureTimer;
  Timer? _connectingTimer;
  bool _showFailure = false;
  bool _showConnecting = false;
  String? _transitionKind;
  late final AnimationController _fillController;
  late final AnimationController _sheenController;
  late final Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    final isStart = ref.read(isStartProvider);
    final isSmartStopped = ref.read(isSmartStoppedProvider);
    _fillController = AnimationController(
      vsync: this,
      duration: _heroFillDuration,
      value: (isStart || isSmartStopped) ? 1 : 0,
    );
    _fillAnimation = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _failureTimer?.cancel();
    _connectingTimer?.cancel();
    _fillController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  String _modeLabel(Mode mode) {
    return switch (mode) {
      Mode.rule => 'Rule',
      Mode.global => 'Global',
      Mode.direct => 'Direct',
    };
  }

  void _handleSwitchStart(WidgetRef ref) {
    final nextIsStart = !ref.read(isStartProvider);
    final kind = nextIsStart ? 'start' : 'stop';
    if (mounted) {
      setState(() => _transitionKind = kind);
      _sheenController.repeat();
    }
    if (nextIsStart) {
      _startConnectingAnimation();
      _fillController.forward();
    } else {
      _fillController.reverse();
    }
    debouncer.call(FunctionTag.updateStatus, () async {
      try {
        await ref
            .read(setupActionProvider.notifier)
            .updateStatus(nextIsStart, isInit: !ref.read(initProvider));
      } finally {
        if (mounted) {
          setState(() => _transitionKind = null);
          _sheenController.stop();
        }
      }
    }, duration: commonDuration);
  }

  void _handleChangeMode(Mode mode, WidgetRef ref) {
    ref.read(setupActionProvider.notifier).changeMode(mode);
  }

  void _startConnectingAnimation() {
    _connectingTimer?.cancel();
    if (mounted) {
      setState(() => _showConnecting = true);
    }
    _connectingTimer = Timer(_heroFillDuration, () {
      if (mounted) {
        setState(() => _showConnecting = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final surge =
        Theme.of(context).extension<SurgeTheme>() ?? SurgeTheme.light();
    final appLocalizations = context.appLocalizations;
    final isStart = ref.watch(isStartProvider);
    final isSmartResuming = ref.watch(isSmartResumingProvider);
    final isSmartStopped = ref.watch(isSmartStoppedProvider);
    final isSmartPaused = isSmartStopped && !isStart;
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final coreStatus = ref.watch(coreStatusProvider);
    final connecting = coreStatus == CoreStatus.connecting || _showConnecting;
    final transitionStart = _transitionKind == 'start';
    final transitionStop = _transitionKind == 'stop';
    final transitionPausing = _transitionKind == 'pausing';
    final buttonLabel = transitionPausing
        ? '暂停中'
        : isSmartResuming
        ? '恢复中'
        : transitionStop
        ? '停止中'
        : (transitionStart || connecting)
        ? '启动中'
        : isSmartPaused
        ? '恢复'
        : isStart
        ? '停止'
        : '启动';
    final buttonLoading =
        transitionPausing ||
        isSmartResuming ||
        transitionStart ||
        transitionStop ||
        connecting;
    final dynamicColor = ref.watch(
      themeSettingProvider.select((state) => state.dynamicColor),
    );
    final currentProfile = ref.watch(currentProfileProvider);
    final profileLabel =
        currentProfile?.realLabel.takeFirstValid(['SlClash']) ?? 'SlClash';
    final statusLabel = isSmartPaused
        ? appLocalizations.smartStopped
        : isStart
        ? appLocalizations.connected
        : appLocalizations.disconnected;
    ref.listen(isStartProvider, (previous, next) {
      if (next) {
        _fillController.forward();
      } else if (!ref.read(isSmartStoppedProvider)) {
        _fillController.reverse();
      }
    });

    ref.listen(isSmartStoppedProvider, (previous, next) {
      // Auto smart-stop triggered during start transition → "暂停中"
      if (next && previous == false && _transitionKind == 'start') {
        _sheenController.repeat();
        if (mounted) setState(() => _transitionKind = 'pausing');
        return;
      }
      // "暂停中" resolved → stop sheen
      if (_transitionKind == 'pausing' && isSmartPaused) {
        _sheenController.stop();
        if (mounted) setState(() => _transitionKind = null);
      }
    });

    // Auto-clear transition when proxy state catches up.
    ref.listen(isStartProvider, (previous, next) {
      if (_transitionKind == 'start' && next) {
        _sheenController.stop();
        _connectingTimer?.cancel();
        if (mounted) {
          setState(() {
            _showConnecting = false;
            _transitionKind = null;
          });
        }
      } else if (_transitionKind == 'stop' && !next && !isSmartStopped) {
        _sheenController.stop();
        if (mounted) setState(() => _transitionKind = null);
      }
    });

    ref.listen(coreStatusProvider, (previous, next) {
      final isFailedStart =
          previous == CoreStatus.connecting && next == CoreStatus.disconnected;
      if (next == CoreStatus.disconnected &&
          !ref.read(isSmartStoppedProvider)) {
        _fillController.reverse();
      }
      if (next != CoreStatus.disconnected || !isFailedStart) {
        _failureTimer?.cancel();
        if (_showFailure && mounted) {
          setState(() => _showFailure = false);
        }
        return;
      }
      _failureTimer?.cancel();
      if (mounted) {
        setState(() => _showFailure = true);
      }
      _failureTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() => _showFailure = false);
        }
      });
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: surge.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: surge.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SubscriptionSelectorBar(
                profileLabel: profileLabel,
                currentProfileId: currentProfile?.id,
                coreStatus: coreStatus,
                isStart: isStart,
                isSmartPaused: isSmartPaused,
                showConnecting: _showConnecting,
                showFailure: _showFailure,
              ),
              const SizedBox(width: 12),
              _HeroActionButton(
                isStart: isStart,
                isSmartPaused: isSmartPaused,
                isSmartResuming: isSmartResuming,
                loading: buttonLoading,
                label: buttonLabel,
                sheenController: _sheenController,
                onPressed: buttonLoading
                    ? null
                    : () {
                        if (isSmartPaused) {
                          ref
                              .read(smartAutoStopManagerProvider.notifier)
                              .resumeNow();
                        } else {
                          _handleSwitchStart(ref);
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              return _HeroModeCard(
                fillProgress: _fillAnimation.value,
                modeLabel: '${_modeLabel(mode)} Mode',
                title: '出站流量',
                active: isStart,
                isSmartPaused: isSmartPaused,
                dynamicColor: dynamicColor,
                connecting:
                    _showConnecting || coreStatus == CoreStatus.connecting,
                failed: _showFailure,
                statusLabel: statusLabel,
              );
            },
          ),
          const SizedBox(height: 12),
          _ModeSwitch(
            value: mode,
            onChanged: (value) => _handleChangeMode(value, ref),
          ),
          const SizedBox(height: 10),
          const _HeroProxySelectorBar(),
        ],
      ),
    );
  }
}

class _HeroModeCard extends StatelessWidget {
  const _HeroModeCard({
    required this.fillProgress,
    required this.title,
    required this.modeLabel,
    required this.active,
    required this.isSmartPaused,
    required this.dynamicColor,
    required this.connecting,
    required this.failed,
    required this.statusLabel,
  });

  final double fillProgress;
  final String title;
  final String modeLabel;
  final bool active;
  final bool isSmartPaused;
  final bool dynamicColor;
  final bool connecting;
  final bool failed;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: _HeroModeCardSurface(
        title: title,
        modeLabel: modeLabel,
        active: active,
        isSmartPaused: isSmartPaused,
        dynamicColor: dynamicColor,
        connecting: connecting,
        failed: failed,
        statusLabel: statusLabel,
        fillProgress: fillProgress.clamp(0.0, 1.0),
      ),
    );
  }
}

class _HeroModeCardSurface extends StatelessWidget {
  const _HeroModeCardSurface({
    required this.title,
    required this.modeLabel,
    required this.active,
    required this.isSmartPaused,
    required this.dynamicColor,
    required this.connecting,
    required this.failed,
    required this.statusLabel,
    required this.fillProgress,
  });

  final String title;
  final String modeLabel;
  final bool active;
  final bool isSmartPaused;
  final bool dynamicColor;
  final bool connecting;
  final bool failed;
  final String statusLabel;
  final double fillProgress;

  @override
  Widget build(BuildContext context) {
    final progress = fillProgress.clamp(0.0, 1.0);
    final activeFill = isSmartPaused
        ? dashboardSmartPausedFill
        : dashboardDynamicActiveFill;
    const foregroundColor = Colors.white;
    final secondaryAlpha = lerpDouble(
      0.82,
      dynamicColor ? 0.92 : 0.82,
      progress,
    );
    final secondaryColor = foregroundColor.withValues(alpha: secondaryAlpha);
    final onBlue = progress > 0.5;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: activeFill, end: activeFill),
      duration: _heroFillDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, animatedActiveFill, child) {
        final smoothFill = animatedActiveFill ?? activeFill;
        final fillColor = Color.lerp(
          dashboardInactiveFill,
          smoothFill,
          progress,
        )!;
        return Container(
          width: double.infinity,
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: fillColor,
            gradient: !dynamicColor && progress > 0.001
                ? LinearGradient(
                    colors: [
                      fillColor,
                      Color.lerp(fillColor, Colors.black, 0.16)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.call_split_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: foregroundColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  modeLabel,
                  maxLines: 1,
                  softWrap: false,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(
            active: active,
            isSmartPaused: isSmartPaused,
            connecting: connecting,
            failed: failed,
            label: statusLabel,
            dynamicColor: dynamicColor,
            onBlue: onBlue,
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.isStart,
    required this.isSmartPaused,
    required this.isSmartResuming,
    required this.loading,
    required this.label,
    required this.sheenController,
    required this.onPressed,
  });

  final bool isStart;
  final bool isSmartPaused;
  final bool isSmartResuming;
  final bool loading;
  final String label;
  final AnimationController sheenController;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final Color baseColor;
    if (isSmartPaused || isSmartResuming || label == '暂停中') {
      baseColor = surge.orange;
    } else if (isStart || label == '停止中') {
      baseColor = surge.red;
    } else {
      baseColor = surge.green;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, Color.lerp(baseColor, Colors.black, 0.16)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 74, minHeight: 28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shimmer layer — only visible when loading
                  if (loading)
                    Positioned.fill(
                      child: _ActionButtonSheen(controller: sheenController),
                    ),
                  // Text label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      // Animated dots during loading
                      if (loading) ...[
                        const SizedBox(width: 2),
                        _LoadingDots(controller: sheenController),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliding sheen gradient that sweeps across the button during loading.
class _ActionButtonSheen extends StatelessWidget {
  const _ActionButtonSheen({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return FractionalTranslation(
            translation: Offset(-1.4 + controller.value * 2.8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Three subtle dots that pulse during loading.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(opacity: _dotOpacity(t, 0)),
            _Dot(opacity: _dotOpacity(t, 1)),
            _Dot(opacity: _dotOpacity(t, 2)),
          ],
        );
      },
    );
  }

  double _dotOpacity(double t, int index) {
    final phase = (t + index / 3) % 1;
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SubscriptionSelectorBar extends ConsumerWidget {
  const _SubscriptionSelectorBar({
    required this.profileLabel,
    required this.currentProfileId,
    required this.coreStatus,
    required this.isStart,
    required this.isSmartPaused,
    required this.showConnecting,
    required this.showFailure,
  });

  final String profileLabel;
  final int? currentProfileId;
  final CoreStatus coreStatus;
  final bool isStart;
  final bool isSmartPaused;
  final bool showConnecting;
  final bool showFailure;

  Color _statusColor(SurgeTheme surge) {
    if (showFailure) return surge.red;
    if (isSmartPaused) return surge.orange;
    if (coreStatus == CoreStatus.connecting || showConnecting || isStart) {
      return const Color(0xFF2FAA67);
    }
    return surge.textSecondary.withValues(alpha: 0.48);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final profiles = ref.watch(profilesProvider);
    final statusColor = _statusColor(surge);

    return Expanded(
      child: GestureDetector(
        onTap: () => _showSubscriptionSelectorSheet(
          context,
          ref,
          profiles,
          currentProfileId,
        ),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                profileLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Dropdown arrow icon, color reflects connection status
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionSelectorSheet(
    BuildContext context,
    WidgetRef ref,
    List<Profile> profiles,
    int? currentProfileId,
  ) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: false),
      builder: (sheetContext) {
        final surge = SurgeTheme.of(sheetContext);
        return AdaptiveSheetScaffold(
          title: '选择订阅',
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isSelected = profile.id == currentProfileId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(currentProfileIdProvider.notifier).value =
                          profile.id;
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? surge.selectedFill : surge.fill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? surge.primary.withValues(alpha: 0.48)
                              : surge.separator,
                          width: isSelected ? 1 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSelected) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2FAA67),
                                shape: BoxShape.circle,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              profile.realLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: surge.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            profile.type == ProfileType.url ? 'URL' : '本地',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: surge.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: surge.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.active,
    required this.isSmartPaused,
    required this.connecting,
    required this.failed,
    required this.label,
    required this.dynamicColor,
    required this.onBlue,
  });

  final bool active;
  final bool isSmartPaused;
  final bool connecting;
  final bool failed;
  final String label;
  final bool dynamicColor;
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final pillAlpha = onBlue && dynamicColor ? 0.24 : 0.18;
    final background = Colors.white.withValues(alpha: pillAlpha);
    final borderColor = onBlue
        ? Colors.white.withValues(alpha: dynamicColor ? 0.28 : 0.16)
        : Colors.white.withValues(alpha: 0.18);
    const textColor = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillStatusLight(
            active: active,
            isSmartPaused: isSmartPaused,
            connecting: connecting,
            failed: failed,
            onBlue: onBlue,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillStatusLight extends StatefulWidget {
  const _PillStatusLight({
    required this.active,
    required this.isSmartPaused,
    required this.connecting,
    required this.failed,
    required this.onBlue,
  });

  final bool active;
  final bool isSmartPaused;
  final bool connecting;
  final bool failed;
  final bool onBlue;

  @override
  State<_PillStatusLight> createState() => _PillStatusLightState();
}

class _PillStatusLightState extends State<_PillStatusLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _statusLightPulseDuration,
      lowerBound: 0.35,
      upperBound: 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _PillStatusLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.connecting) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  Color _color(SurgeTheme surge) {
    if (widget.failed) return const Color(0xFFFF8A80);
    if (widget.isSmartPaused) return surge.orange;
    if (widget.connecting || widget.active) return const Color(0xFF7BFFB2);
    return widget.onBlue
        ? Colors.white.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.72);
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = _color(surge);

    return FadeTransition(
      opacity: _opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha:
                    !widget.active &&
                        !widget.connecting &&
                        !widget.failed &&
                        !widget.isSmartPaused
                    ? 0
                    : 0.32,
              ),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final Mode value;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final surge =
        Theme.of(context).extension<SurgeTheme>() ?? SurgeTheme.light();
    const modes = [Mode.rule, Mode.direct, Mode.global];
    final selectedIndex = modes.indexOf(value).clamp(0, modes.length - 1);

    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / modes.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: itemWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surge.elevatedCard,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final mode in modes)
                    Expanded(
                      child: _ModeSwitchItem(
                        label: switch (mode) {
                          Mode.rule => context.appLocalizations.rule,
                          Mode.direct => context.appLocalizations.direct,
                          Mode.global => context.appLocalizations.global,
                        },
                        selected: mode == value,
                        primary: surge.primary,
                        textSecondary: surge.textSecondary,
                        onTap: () => onChanged(mode),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeSwitchItem extends StatelessWidget {
  const _ModeSwitchItem({
    required this.label,
    required this.selected,
    required this.primary,
    required this.textSecondary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? primary : textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  letterSpacing: 0,
                ) ??
                TextStyle(
                  color: selected ? primary : textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

class _HeroProxySelectorBar extends ConsumerWidget {
  const _HeroProxySelectorBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final groups = ref.watch(currentGroupsStateProvider).value;
    final currentGroupName = ref.watch(
      currentProfileProvider.select((state) => state?.currentGroupName ?? ''),
    );
    final selectedGroupName =
        currentGroupName.isNotEmpty &&
            groups.any((g) => g.name == currentGroupName)
        ? currentGroupName
        : (groups.isNotEmpty ? groups.first.name : '');

    final selectedProxyName = selectedGroupName.isNotEmpty
        ? ref.watch(selectedProxyNameProvider(selectedGroupName))
        : null;

    return Container(
      width: double.infinity,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          // Group selector (left)
          Expanded(
            child: GestureDetector(
              onTap: () => _showGroupSelectorSheet(
                context,
                ref,
                groups,
                selectedGroupName,
              ),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      selectedGroupName.isEmpty ? '-' : selectedGroupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: surge.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: surge.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: surge.separator,
          ),
          // Node selector (right)
          Expanded(
            child: GestureDetector(
              onTap: selectedGroupName.isNotEmpty
                  ? () => _showNodeSelectorSheet(
                      context,
                      ref,
                      selectedGroupName,
                      selectedProxyName ?? '',
                    )
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      selectedProxyName == null || selectedProxyName.isEmpty
                          ? '-'
                          : selectedProxyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: surge.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: surge.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupSelectorSheet(
    BuildContext context,
    WidgetRef ref,
    List<Group> groups,
    String selectedGroupName,
  ) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: false),
      builder: (sheetContext) {
        final surge = SurgeTheme.of(sheetContext);
        return AdaptiveSheetScaffold(
          title: sheetContext.appLocalizations.proxyGroup,
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final isSelected = group.name == selectedGroupName;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      proxy_common.updateCurrentGroupName(group.name);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? surge.selectedFill : surge.fill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? surge.primary.withValues(alpha: 0.48)
                              : surge.separator,
                          width: isSelected ? 1 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSelected) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2FAA67),
                                shape: BoxShape.circle,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: surge.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            group.type.name,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: surge.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: surge.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showNodeSelectorSheet(
    BuildContext context,
    WidgetRef ref,
    String groupName,
    String currentProxyName,
  ) {
    final groups = ref.read(groupsProvider);
    final matchingGroups = groups.where((g) => g.name == groupName);
    final group = matchingGroups.isNotEmpty
        ? matchingGroups.first
        : groups.first;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: _NodeSelectionSheet(
          group: group,
          currentProxyName: currentProxyName,
        ),
      ),
    );
  }
}

class _NodeSelectionSheet extends ConsumerStatefulWidget {
  const _NodeSelectionSheet({
    required this.group,
    required this.currentProxyName,
  });

  final Group group;
  final String currentProxyName;

  @override
  ConsumerState<_NodeSelectionSheet> createState() =>
      _NodeSelectionSheetState();
}

class _NodeSelectionSheetState extends ConsumerState<_NodeSelectionSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isDelayTesting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _delayTest() async {
    if (_isDelayTesting) return;
    setState(() => _isDelayTesting = true);
    await proxy_common.delayTest(widget.group.all, widget.group.testUrl);
    if (mounted) setState(() => _isDelayTesting = false);
  }

  void _scrollToSelected() {
    final proxies = widget.group.all;
    final selectedIndex = proxies.indexWhere(
      (p) => p.name == widget.currentProxyName,
    );
    if (selectedIndex == -1) return;
    // Each node card: padding vertical 10*2 + text ~18 + bottom margin 6 = ~44
    // Use a safe offset that ensures the item is visible near the top
    final targetOffset = (selectedIndex * 44.0) - 80;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final filteredProxies = widget.group.all
        .where(
          (p) =>
              _searchQuery.isEmpty ||
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 28,
            height: 4,
            margin: const EdgeInsets.only(top: 6),
            decoration: ShapeDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title bar: same structure as AdaptiveSheetScaffold bottomSheet
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: Text(
                        '节点',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.fontSize ??
                                  22) -
                              4,
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Search field with embedded action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: surge.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: context.appLocalizations.search,
                hintStyle: TextStyle(color: surge.textSecondary, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: surge.textSecondary,
                  size: 20,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      onPressed: _scrollToSelected,
                      iconSize: 20,
                      icon: Icon(Icons.adjust, color: surge.textSecondary),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      onPressed: _isDelayTesting ? null : _delayTest,
                      iconSize: 20,
                      icon: _isDelayTesting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: surge.textSecondary,
                              ),
                            )
                          : Icon(
                              Icons.network_ping_rounded,
                              color: surge.textSecondary,
                            ),
                    ),
                  ],
                ),
                isDense: true,
                filled: true,
                fillColor: surge.fill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: surge.separator),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: surge.separator),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: surge.primary, width: 1.5),
                ),
              ),
            ),
          ),
          // Node list
          Expanded(
            child: filteredProxies.isEmpty
                ? Center(
                    child: Text(
                      context.appLocalizations.noData,
                      style: TextStyle(color: surge.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: filteredProxies.length,
                    itemBuilder: (context, index) {
                      final proxy = filteredProxies[index];
                      return _NodeCard(
                        proxy: proxy,
                        group: widget.group,
                        isSelected: proxy.name == widget.currentProxyName,
                        onTap: () {
                          _changeProxy(ref, proxy.name);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _changeProxy(WidgetRef ref, String proxyName) {
    final groupName = widget.group.name;
    final isComputedSelected = widget.group.type.isComputedSelected;
    final isSelector = widget.group.type == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final nextName = isComputedSelected
          ? (ref.read(proxyNameProvider(groupName)) == proxyName
                ? ''
                : proxyName)
          : proxyName;
      ref
          .read(profilesActionProvider.notifier)
          .updateCurrentSelectedMap(groupName, nextName);
      ref
          .read(proxiesActionProvider.notifier)
          .changeProxyDebounce(groupName, nextName);
    }
  }
}

class _NodeCard extends ConsumerWidget {
  const _NodeCard({
    required this.proxy,
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final Proxy proxy;
  final Group group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    final delayColor = delay == null
        ? surge.textSecondary
        : delay == 0
        ? surge.textSecondary
        : delay < 0
        ? surge.red
        : utils.getDelayColor(delay) ?? surge.textSecondary;
    final delayLabel = delay == null
        ? ''
        : delay == 0
        ? '...'
        : delay > 0
        ? '${delay}ms'
        : 'Timeout';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? surge.selectedFill : surge.fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? surge.primary.withValues(alpha: 0.48)
                    : surge.separator,
                width: isSelected ? 1 : 0.5,
              ),
            ),
            child: Row(
              children: [
                if (isSelected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2FAA67),
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                  ),
                ],
                Expanded(
                  child: Text(
                    proxy.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: surge.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (delayLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: delayColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      delayLabel,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: delayColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 18, color: surge.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
