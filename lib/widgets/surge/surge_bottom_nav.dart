import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'surge_theme_extension.dart';

@immutable
class SurgeBottomNavItem {
  const SurgeBottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? activeIcon;
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
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 16;
    final navWidth = math.max(MediaQuery.sizeOf(context).width - 36, 0.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPadding),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: navWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surge.navBar,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: surge.navBorder),
              boxShadow: [
                BoxShadow(
                  color: surge.shadow,
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surge.navBar,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
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
    final color = selected ? surge.textPrimary : surge.textSecondary;
    final icon = selected ? item.activeIcon ?? item.icon : item.icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Icon(icon, color: color, size: selected ? 25 : 24),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.0,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
