import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

class NullStatus extends StatelessWidget {
  final String label;
  final Widget illustration;

  const NullStatus({
    super.key,
    required this.label,
    this.illustration = const DataEmptyIllustration(),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0.0, -0.25),
      child: Wrap(
        direction: Axis.vertical,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          illustration,
          const SizedBox(height: 14),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: SurgeTheme.of(context).textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class LogEmptyIllustration extends StatelessWidget {
  const LogEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SoftOsEmptyIllustration(icon: SurgeIcons.logs);
  }
}

class ProxyEmptyIllustration extends StatelessWidget {
  const ProxyEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SoftOsEmptyIllustration(icon: SurgeIcons.proxyGroup);
  }
}

class DataEmptyIllustration extends StatelessWidget {
  const DataEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SoftOsEmptyIllustration(icon: SurgeIcons.info);
  }
}

class ProfileEmptyIllustration extends StatelessWidget {
  const ProfileEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SoftOsEmptyIllustration(icon: SurgeIcons.profiles);
  }
}

class ScriptEmptyIllustration extends StatelessWidget {
  const ScriptEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SoftOsEmptyIllustration(icon: SurgeIcons.code);
  }
}

class RuleEmptyIllustration extends StatelessWidget {
  const RuleEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SoftOsEmptyIllustration(icon: SurgeIcons.rule);
  }
}

class ConnectionEmptyIllustration extends StatelessWidget {
  const ConnectionEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SoftOsEmptyIllustration(icon: SurgeIcons.connections);
  }
}

class _SoftOsEmptyIllustration extends StatelessWidget {
  const _SoftOsEmptyIllustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      width: 88,
      height: 88,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surge.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: surge.separator, width: surge.spacing.hairline),
        boxShadow: [
          BoxShadow(
            color: surge.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surge.fill,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: surge.separator.withValues(alpha: 0.7),
            width: surge.spacing.hairline,
          ),
        ),
        child: Icon(icon, size: 28, color: surge.textSecondary),
      ),
    );
  }
}
