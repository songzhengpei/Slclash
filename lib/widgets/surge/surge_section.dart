import 'package:flutter/material.dart';

import 'surge_card.dart';
import 'surge_theme_extension.dart';

class SurgeSection extends StatelessWidget {
  const SurgeSection({
    super.key,
    required this.children,
    this.title,
    this.footer,
    this.padding,
    this.margin,
    this.showDividers = false,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showDividers;

  List<Widget> _buildChildren(SurgeTheme surge) {
    if (!showDividers) return children;
    return [
      for (var i = 0; i < children.length; i++) ...[
        if (i != 0) Divider(height: 0, color: surge.separator),
        children[i],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final sectionMargin =
        margin ??
        EdgeInsets.only(
          left: surge.spacing.pagePadding,
          right: surge.spacing.pagePadding,
          bottom: surge.spacing.sectionSpacing,
        );

    return Padding(
      padding: sectionMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: surge.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
          SurgeCard(
            borderRadius: surge.radii.list,
            padding: padding ?? EdgeInsets.zero,
            shadow: false,
            child: Column(children: _buildChildren(surge)),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, right: 4),
              child: Text(
                footer!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: surge.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
