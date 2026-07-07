import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

class SoftOsControlDock extends StatelessWidget {
  const SoftOsControlDock({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surge.textSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: surge.separator.withValues(alpha: 0.55),
          width: surge.spacing.hairline,
        ),
      ),
      child: SizedBox(
        height: 38,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class SoftOsDockButton extends StatelessWidget {
  const SoftOsDockButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final foreground = loading ? surge.textSecondary : surge.textPrimary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 44,
            child: Center(
              child: loading
                  ? SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Icon(icon, size: 17, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class SoftOsDockDivider extends StatelessWidget {
  const SoftOsDockDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      height: 20,
      child: VerticalDivider(
        width: 1,
        thickness: surge.spacing.hairline,
        color: surge.separator.withValues(alpha: 0.55),
      ),
    );
  }
}
