import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SurgeDashboardHero extends ConsumerStatefulWidget {
  const SurgeDashboardHero({super.key});

  @override
  ConsumerState<SurgeDashboardHero> createState() => _SurgeDashboardHeroState();
}

class _SurgeDashboardHeroState extends ConsumerState<SurgeDashboardHero> {
  Timer? _failureTimer;
  Timer? _connectingTimer;
  bool _showFailure = false;
  bool _showConnecting = false;

  @override
  void dispose() {
    _failureTimer?.cancel();
    _connectingTimer?.cancel();
    super.dispose();
  }

  String _modeLabel(Mode mode) {
    return switch (mode) {
      Mode.rule => 'Rule',
      Mode.global => 'Global',
      Mode.direct => 'Direct',
    };
  }

  String _coreStatusLabel(BuildContext context, CoreStatus status) {
    return switch (status) {
      CoreStatus.connecting => context.appLocalizations.connecting,
      CoreStatus.connected => context.appLocalizations.connected,
      CoreStatus.disconnected => context.appLocalizations.disconnected,
    };
  }

  void _handleSwitchStart(WidgetRef ref) {
    final nextIsStart = !ref.read(isStartProvider);
    if (nextIsStart) {
      _startConnectingAnimation();
    }
    debouncer.call(FunctionTag.updateStatus, () {
      ref
          .read(setupActionProvider.notifier)
          .updateStatus(nextIsStart, isInit: !ref.read(initProvider));
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
    _connectingTimer = Timer(const Duration(milliseconds: 1500), () {
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
    final runTime = ref.watch(runTimeProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final coreStatus = ref.watch(coreStatusProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final profileLabel =
        currentProfile?.realLabel.takeFirstValid(['SlClash']) ?? 'SlClash';
    final statusLabel = isStart
        ? appLocalizations.connected
        : appLocalizations.disconnected;
    final runtimeText = utils.getTimeText(runTime);

    ref.listen(coreStatusProvider, (previous, next) {
      final isFailedStart =
          previous == CoreStatus.connecting && next == CoreStatus.disconnected;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _ConnectionStatusLight(
                      coreStatus: coreStatus,
                      isStart: isStart,
                      showConnecting: _showConnecting,
                      showFailure: _showFailure,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        profileLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: surge.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HeroActionButton(
                isStart: isStart,
                loading: coreStatus == CoreStatus.connecting,
                onPressed: () => _handleSwitchStart(ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1495FF), Color(0xFF0068F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0052FF).withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
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
                        appLocalizations.outboundMode,
                        maxLines: 1,
                        softWrap: false,
                        style: context.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_modeLabel(mode)} Mode',
                        maxLines: 1,
                        softWrap: false,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 11,
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
                  active: isStart,
                  connecting:
                      _showConnecting || coreStatus == CoreStatus.connecting,
                  failed: _showFailure,
                  label: statusLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ModeSwitch(
            value: mode,
            onChanged: (value) => _handleChangeMode(value, ref),
          ),
          const SizedBox(height: 10),
          _HeroInfoBar(
            items: [
              _HeroInfoItem(label: 'Runtime', value: runtimeText),
              _HeroInfoItem(
                label: 'Core 状态',
                value: _coreStatusLabel(context, coreStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.isStart,
    required this.loading,
    required this.onPressed,
  });

  final bool isStart;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A84FF), Color(0xFF0052FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052FF).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 74, minHeight: 28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Center(
                      child: Text(
                        isStart ? 'Disconnect' : 'Connect',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatusLight extends StatefulWidget {
  const _ConnectionStatusLight({
    required this.coreStatus,
    required this.isStart,
    required this.showConnecting,
    required this.showFailure,
  });

  final CoreStatus coreStatus;
  final bool isStart;
  final bool showConnecting;
  final bool showFailure;

  @override
  State<_ConnectionStatusLight> createState() => _ConnectionStatusLightState();
}

class _ConnectionStatusLightState extends State<_ConnectionStatusLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.35,
      upperBound: 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _ConnectionStatusLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.coreStatus == CoreStatus.connecting || widget.showConnecting) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  Color _color(SurgeTheme surge) {
    if (widget.showFailure) return surge.red;
    if (widget.coreStatus == CoreStatus.connecting ||
        widget.showConnecting ||
        widget.isStart) {
      return surge.green;
    }
    return surge.textSecondary.withValues(alpha: 0.42);
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
                    widget.coreStatus == CoreStatus.disconnected &&
                        !widget.isStart &&
                        !widget.showFailure
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.active,
    required this.connecting,
    required this.failed,
    required this.label,
  });

  final bool active;
  final bool connecting;
  final bool failed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillStatusLight(
            active: active,
            connecting: connecting,
            failed: failed,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
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
    required this.connecting,
    required this.failed,
  });

  final bool active;
  final bool connecting;
  final bool failed;

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
      duration: const Duration(milliseconds: 160),
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

  Color _color() {
    if (widget.failed) return const Color(0xFFFF8A80);
    if (widget.connecting || widget.active) return const Color(0xFF7BFFB2);
    return Colors.white.withValues(alpha: 0.75);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

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
                alpha: !widget.active && !widget.connecting && !widget.failed
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

    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          for (final mode in const [Mode.rule, Mode.direct, Mode.global])
            Expanded(
              child: _ModeSwitchItem(
                label: switch (mode) {
                  Mode.rule => context.appLocalizations.rule,
                  Mode.direct => context.appLocalizations.direct,
                  Mode.global => context.appLocalizations.global,
                },
                selected: mode == value,
                primary: surge.primary,
                onTap: () => onChanged(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeSwitchItem extends StatelessWidget {
  const _ModeSwitchItem({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.055),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? primary : const Color(0xFF8D94A1),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.0,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroInfoItem {
  const _HeroInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _HeroInfoBar extends StatelessWidget {
  const _HeroInfoBar({required this.items});

  final List<_HeroInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  items[0].label,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8D95A1),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                Text(
                  items[0].value,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF111318),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFFD9DEE7),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  items[1].label,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8D95A1),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                Text(
                  items[1].value,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF111318),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
