import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';

class SurgeListTile extends StatelessWidget {
  const SurgeListTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.dense = false,
    this.showDivider = true,
    this.destructive = false,
    this.enabled = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool dense;
  final bool showDivider;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final titleColor = !enabled
        ? surge.textSecondary.withValues(alpha: 0.45)
        : destructive
        ? surge.red
        : surge.textPrimary;
    final minHeight = dense ? 52.0 : 60.0;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                if (leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      color: destructive ? surge.red : surge.primary,
                      size: 21,
                    ),
                    child: leading!,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: showDivider
                          ? Border(
                              bottom: BorderSide(
                                color: surge.separator,
                                width: surge.spacing.hairline,
                              ),
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: hasSubtitle ? 8 : 0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: titleColor,
                                          fontSize: 16,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                  if (hasSubtitle) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: surge.textSecondary,
                                            fontSize: 13,
                                            letterSpacing: 0,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 12),
                            trailing!,
                          ],
                          if (showChevron) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: surge.textSecondary.withValues(alpha: 0.7),
                              size: 22,
                            ),
                          ],
                        ],
                      ),
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
