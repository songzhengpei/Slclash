import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ColorSchemeBox extends StatelessWidget {
  final Color? primaryColor;
  final bool? isSelected;
  final void Function()? onPressed;

  const ColorSchemeBox({
    super.key,
    required this.primaryColor,
    this.onPressed,
    this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: PrimaryColorBox(
        primaryColor: primaryColor,
        child: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            final surge = SurgeTheme.of(context);
            return Stack(
              children: [
                SurgeActionCard(
                  selected: isSelected == true,
                  variant: SurgeActionCardVariant.filled,
                  onTap: onPressed,
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: colorScheme.surface),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              color: colorScheme.primary,
                              alignment: Alignment.center,
                              child: Container(
                                width: 28,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colorScheme.onPrimary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    color: colorScheme.secondaryContainer,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    color: colorScheme.tertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.62,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FractionallySizedBox(
                                    widthFactor: 0.62,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.32,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isSelected == true)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: SurgeSelectIndicator(selected: true, size: 22),
                  ),
                if (primaryColor == null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: surge.card.withValues(alpha: 0.88),
                        shape: BoxShape.circle,
                        border: Border.all(color: surge.separator),
                      ),
                      child: Icon(
                        Icons.colorize,
                        size: 15,
                        color: surge.textSecondary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PrimaryColorBox extends ConsumerWidget {
  final Color? primaryColor;
  final Widget child;
  final Brightness? brightness;
  final bool ignoreConfig;

  const PrimaryColorBox({
    super.key,
    required this.primaryColor,
    required this.child,
    this.brightness,
    this.ignoreConfig = true,
  });

  @override
  Widget build(BuildContext context, ref) {
    final themeData = Theme.of(context);
    final colorScheme = ref.watch(
      genColorSchemeProvider(
        brightness ?? themeData.brightness,
        color: primaryColor,
        ignoreConfig: ignoreConfig,
      ),
    );
    return Theme(
      data: themeData.copyWith(colorScheme: colorScheme),
      child: child,
    );
  }
}
