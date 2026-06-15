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
    final style = dynamicColor
        ? FilledButton.styleFrom(visualDensity: VisualDensity.compact)
        : FilledButton.styleFrom(
            backgroundColor: surge.primary,
            foregroundColor: surge.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(surge.radii.button),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
    return FilledButton(style: style, onPressed: onPressed, child: Text(label));
  }
}
