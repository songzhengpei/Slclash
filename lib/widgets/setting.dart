import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

import 'card.dart';

class SettingInfoCard extends StatelessWidget {
  final Info info;
  final bool? isSelected;
  final VoidCallback onPressed;

  const SettingInfoCard(
    this.info, {
    super.key,
    this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeActionCard(
      selected: isSelected == true,
      variant: SurgeActionCardVariant.filled,
      onTap: onPressed,
      padding: const EdgeInsets.all(12),
      child: IconTheme.merge(
        data: IconThemeData(color: surge.primary, size: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(child: Icon(info.iconData)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                info.label,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: surge.textPrimary,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingTextCard extends StatelessWidget {
  final String text;
  final bool? isSelected;
  final VoidCallback onPressed;

  const SettingTextCard(
    this.text, {
    super.key,
    this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeActionCard(
      onTap: onPressed,
      selected: isSelected == true,
      variant: SurgeActionCardVariant.filled,
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: surge.textPrimary,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
