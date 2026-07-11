import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          const SizedBox(height: 16),
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
  Widget build(BuildContext context) =>
      const _SoftOsEmptyIllustration('assets/images/empty/log.svg');
}

class ProxyEmptyIllustration extends StatelessWidget {
  const ProxyEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const _SoftOsEmptyIllustration('assets/images/empty/proxy.svg');
}

class DataEmptyIllustration extends StatelessWidget {
  const DataEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const _SoftOsEmptyIllustration('assets/images/empty/data.svg');
}

class ProfileEmptyIllustration extends StatelessWidget {
  const ProfileEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const _SoftOsEmptyIllustration('assets/images/empty/profile.svg');
}

class ScriptEmptyIllustration extends StatelessWidget {
  const ScriptEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const _SoftOsEmptyIllustration('assets/images/empty/script.svg');
}

class RuleEmptyIllustration extends StatelessWidget {
  const RuleEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const _SoftOsEmptyIllustration('assets/images/empty/rule.svg');
}

class ConnectionEmptyIllustration extends StatelessWidget {
  const ConnectionEmptyIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      const _SoftOsEmptyIllustration('assets/images/empty/connection.svg');
}

class _SoftOsEmptyIllustration extends StatelessWidget {
  const _SoftOsEmptyIllustration(this.assetPath);

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 184,
      height: 184,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surge.card.withValues(alpha: isDark ? 0.58 : 0.72),
        borderRadius: BorderRadius.circular(46),
        border: Border.all(
          color: surge.separator.withValues(alpha: isDark ? 0.72 : 0.58),
          width: surge.spacing.hairline,
        ),
      ),
      child: _ThemeAwareSvg(assetPath),
    );
  }
}

class _ThemeAwareSvg extends StatelessWidget {
  const _ThemeAwareSvg(this.assetPath);

  final String assetPath;

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return FutureBuilder<String>(
      future: rootBundle.loadString(assetPath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          var svg = snapshot.data!;
          svg = svg.replaceAll(
            '#E8DEF8',
            '#${_colorToHex(surge.separator.withValues(alpha: 0.82))}',
          );
          svg = svg.replaceAll(
            '#6750A4',
            '#${_colorToHex(surge.textSecondary.withValues(alpha: 0.72))}',
          );
          svg = svg.replaceAll('#FDF7FF', '#${_colorToHex(surge.card)}');
          svg = svg.replaceAll('#C4C7C5', '#${_colorToHex(surge.separator)}');
          return SvgPicture.string(svg, width: 160, height: 160);
        }
        if (snapshot.hasError) {
          return Icon(SurgeIcons.error, color: surge.textSecondary);
        }
        return const SizedBox.square(dimension: 160);
      },
    );
  }
}
