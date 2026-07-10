import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonMinFilledButtonTheme extends StatelessWidget {
  final Widget child;

  const CommonMinFilledButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FilledButtonTheme(
      data: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: child,
    );
  }
}

class CommonMinIconButtonTheme extends StatelessWidget {
  final Widget child;

  const CommonMinIconButtonTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          iconSize: 20.ap,
        ),
      ),
      child: child,
    );
  }
}

class SurgeAddButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final String label;

  const SurgeAddButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final dynamicColor = ref.watch(
      themeSettingProvider.select((state) => state.dynamicColor),
    );
    final isShortLabel = label.trim().runes.length <= 2;
    final style = FilledButton.styleFrom(
      backgroundColor: dynamicColor ? null : surge.primary,
      foregroundColor: dynamicColor ? null : surge.onPrimary,
      padding: EdgeInsets.symmetric(horizontal: isShortLabel ? 0 : 14),
      fixedSize: isShortLabel ? const Size(55, 38) : null,
      minimumSize: const Size(0, 38),
      tapTargetSize: isShortLabel
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surge.radii.button),
      ),
    );
    return FilledButton(
      style: style,
      onPressed: onPressed,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
