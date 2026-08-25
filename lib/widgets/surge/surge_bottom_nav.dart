import 'dart:math' as math;

import 'package:fl_clash/common/icons.dart';
import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';

class SurgeBottomNavLayout {
  const SurgeBottomNavLayout._();

  static const double height = 56;
  static const double horizontalInset = 21;
  static const double noGestureBottomInset = 12;
  static const double contentGap = 9;

  static double navBottomInset(BuildContext context) {
    return navBottomInsetFor(MediaQuery.viewPaddingOf(context).bottom);
  }

  static double mainPageBottomPadding(BuildContext context) {
    return mainPageBottomPaddingFor(MediaQuery.viewPaddingOf(context).bottom);
  }

  @visibleForTesting
  static double navBottomInsetFor(double viewPaddingBottom) {
    if (viewPaddingBottom <= 0) {
      return noGestureBottomInset;
    }
    return viewPaddingBottom;
  }

  @visibleForTesting
  static double mainPageBottomPaddingFor(double viewPaddingBottom) {
    return navBottomInsetFor(viewPaddingBottom) + height + contentGap;
  }
}

@immutable
class SurgeBottomNavItem {
  const SurgeBottomNavItem({
    required this.icon,
    required this.iconOutlined,
    required this.label,
  });

  final IconData icon;
  final IconData iconOutlined;
  final String label;
}

class SurgeBottomNav extends StatelessWidget {
  const SurgeBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<SurgeBottomNavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final bottomPadding = SurgeBottomNavLayout.navBottomInset(context);
    final navWidth = math.max(
      MediaQuery.sizeOf(context).width -
          SurgeBottomNavLayout.horizontalInset * 2,
      0.0,
    );
    final navSurface = Color.alphaBlend(surge.navBar, surge.background);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SurgeBottomNavLayout.horizontalInset,
        0,
        SurgeBottomNavLayout.horizontalInset,
        bottomPadding,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: navWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: navSurface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: surge.navBorder,
                width: surge.spacing.hairline,
              ),
              boxShadow: [
                BoxShadow(
                  color: surge.shadow.withValues(alpha: 0.14),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: surge.shadow.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: SizedBox(
                height: SurgeBottomNavLayout.height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      for (var index = 0; index < items.length; index++)
                        Expanded(
                          child: _SurgeBottomNavTile(
                            item: items[index],
                            selected: index == currentIndex,
                            onTap: () => onTap(index),
                          ),
                        ),
                    ],
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

class _SurgeBottomNavTile extends StatelessWidget {
  const _SurgeBottomNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SurgeBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = selected ? surge.primary : surge.textSecondary;
    final iconData = selected ? item.icon : item.iconOutlined;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: color, size: SurgeIconSize.navigation),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style:
                    (selected
                            ? context.typography.selectedNavigationLabel
                            : context.typography.navigationLabel)
                        .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
