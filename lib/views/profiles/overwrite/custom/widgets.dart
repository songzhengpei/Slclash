import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class InfoMessageButton extends StatelessWidget {
  final String message;

  const InfoMessageButton({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        onPressed: () {
          globalState.showMessage(message: TextSpan(text: message));
        },
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(Icons.info, size: 20, color: surge.red),
      ),
    );
  }
}

class OverwriteSectionHeader extends StatelessWidget {
  const OverwriteSectionHeader({super.key, required this.label, this.actions});

  final String label;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(
                color: surge.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          if (actions?.isNotEmpty == true) ...[
            const SizedBox(width: 12),
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
          ],
        ],
      ),
    );
  }
}

class OverwriteCountPill extends StatelessWidget {
  const OverwriteCountPill({super.key, required this.value});

  final Object value;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surge.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: surge.primary.withValues(alpha: 0.14),
          width: surge.spacing.hairline,
        ),
      ),
      child: Text(
        '$value',
        maxLines: 1,
        style: context.textTheme.labelSmall?.copyWith(
          color: surge.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class OverwriteIconButton extends StatelessWidget {
  const OverwriteIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = destructive ? surge.red : surge.primary;
    return SizedBox.square(
      dimension: 40,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: color.withValues(alpha: 0.11),
          foregroundColor: color,
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class OverwriteListItem extends StatelessWidget {
  const OverwriteListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onPressed,
    this.invalid = false,
    this.selected = false,
    this.destructive = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final bool invalid;
  final bool selected;
  final bool destructive;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final activeColor = destructive || invalid ? surge.red : surge.primary;
    return Padding(
      padding: margin,
      child: SurgeActionCard(
        onTap: onPressed,
        selected: selected,
        destructive: destructive || invalid,
        variant: SurgeActionCardVariant.filled,
        borderRadius: surge.radii.list,
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: activeColor, size: 20),
                child: leading!,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: destructive || invalid
                          ? surge.red
                          : selected
                          ? surge.primary
                          : surge.textPrimary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: surge.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              IconTheme.merge(
                data: IconThemeData(color: surge.textSecondary, size: 18),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget fadeAndSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurveTween(curve: Curves.easeInExpo).animate(animation),
    child: FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOutExpo))
          .animate(secondaryAnimation),
      child: const CommonPageTransitionsBuilder().buildTransitions(
        ModalRoute.of(context) as PageRoute,
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    ),
  );
}
