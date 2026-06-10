import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SurgeDashboardHero extends ConsumerWidget {
  const SurgeDashboardHero({super.key});

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
    debouncer.call(FunctionTag.updateStatus, () {
      ref
          .read(setupActionProvider.notifier)
          .updateStatus(nextIsStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  void _handleChangeMode(Mode mode, WidgetRef ref) {
    ref.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = Theme.of(context).extension<SurgeTheme>() ?? SurgeTheme.light();
    final appLocalizations = context.appLocalizations;
    final isStart = ref.watch(isStartProvider);
    final runTime = ref.watch(runTimeProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final coreStatus = ref.watch(coreStatusProvider);
    final statusLabel = isStart
        ? appLocalizations.connected
        : appLocalizations.disconnected;
    final runtimeText = utils.getTimeText(runTime);

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
                child: Text(
                  'SlClash',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.6,
                  ),
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
                _StatusPill(active: isStart, label: statusLabel),
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
    final appLocalizations = context.appLocalizations;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Center(
                    child: Text(
                      isStart ? appLocalizations.stop : appLocalizations.start,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.label});

  final bool active;
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
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF7BFFB2) : Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontSize: 10,
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

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final Mode value;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = Theme.of(context).extension<SurgeTheme>() ?? SurgeTheme.light();

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
