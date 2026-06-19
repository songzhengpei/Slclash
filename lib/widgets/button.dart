import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

import 'builder.dart';

class CommonFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Icon icon;
  final String label;

  const CommonFloatingActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: Theme.of(context).floatingActionButtonTheme
            .copyWith(
              extendedIconLabelSpacing: 0,
              extendedPadding: const EdgeInsets.all(16),
            ),
      ),
      child: FloatingActionButtonExtendedBuilder(
        builder: (isExtended) {
          return FloatingActionButton.extended(
            heroTag: null,
            icon: icon,
            onPressed: onPressed,
            isExtended: true,
            label: AnimatedSize(
              alignment: Alignment.centerLeft,
              duration: midDuration,
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                duration: midDuration,
                opacity: isExtended ? 1.0 : 0.4,
                curve: Curves.linear,
                child: isExtended
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(label, softWrap: false),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MoreActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? trailing;

  const MoreActionButton({
    super.key,
    this.onPressed,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SurgeActionCard(
        variant: SurgeActionCardVariant.filled,
        borderRadius: 18,
        onTap: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: surge.textPrimary,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconTheme.merge(
              data: IconThemeData(color: surge.textSecondary, size: 18),
              child: trailing ?? const Icon(Icons.arrow_forward_ios),
            ),
          ],
        ),
      ),
    );
  }
}
