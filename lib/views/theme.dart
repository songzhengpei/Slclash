// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ThemeModeItem {
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;

  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
}

class FontFamilyItem {
  final FontFamily fontFamily;
  final String label;

  const FontFamilyItem({required this.fontFamily, required this.label});
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    return BaseScaffold(
      title: appLocalizations.theme,
      body: ColoredBox(
        color: surge.background,
        child: ListView(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: const [
            SurgeSection(
              showDividers: true,
              children: [
                _ThemeModeItem(),
                _DynamicColorItem(),
                _TextScaleFactorItem(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Widget child;
  final Info info;
  final List<Widget> actions;

  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: surge.spacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    info.label,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: surge.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
                ],
              ],
            ),
          ),
          SurgeCard(
            borderRadius: surge.radii.list,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shadow: false,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final themeMode = ref.watch(
      themeSettingProvider.select((state) => state.themeMode),
    );
    final List<ThemeModeItem> themeModeItems = [
      ThemeModeItem(
        iconData: Icons.auto_mode,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: Icons.light_mode,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: Icons.dark_mode,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLocalizations.themeMode,
            style: _themePageTitleStyle(context, surge),
          ),
          const SizedBox(height: 10),
          _SurgeThemeModeControl(
            value: themeMode,
            items: themeModeItems,
            onChanged: (value) {
              ref
                  .read(themeSettingProvider.notifier)
                  .update((state) => state.copyWith(themeMode: value));
            },
          ),
        ],
      ),
    );
  }
}

class _SurgeThemeModeControl extends StatelessWidget {
  const _SurgeThemeModeControl({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final ThemeMode value;
  final List<ThemeModeItem> items;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final selectedIndex = items
        .indexWhere((item) => item.themeMode == value)
        .clamp(0, items.length - 1);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 40,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: itemWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: surge.elevatedCard,
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final item in items)
                      Expanded(
                        child: _SurgeThemeModeButton(
                          item: item,
                          selected: value == item.themeMode,
                          onTap: () => onChanged(item.themeMode),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SurgeThemeModeButton extends StatelessWidget {
  const _SurgeThemeModeButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ThemeModeItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.iconData,
                size: 17,
                color: selected ? surge.primary : surge.textSecondary,
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                style:
                    context.textTheme.labelMedium?.copyWith(
                      color: selected ? surge.textPrimary : surge.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ) ??
                    TextStyle(
                      color: selected ? surge.textPrimary : surge.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DynamicColorItem extends ConsumerWidget {
  const _DynamicColorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final dynamicColor = ref.watch(
      themeSettingProvider.select((state) => state.dynamicColor),
    );
    return ListItem.switchItem(
      title: Text('动态取色', style: _themePageTitleStyle(context, surge)),
      subtitle: Text(
        dynamicColor ? '跟随系统 Material You 色彩' : '使用 SlClash 默认 Surge 色彩',
        style: context.textTheme.bodySmall?.copyWith(
          color: surge.textSecondary,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
      delegate: SwitchDelegate(
        value: dynamicColor,
        onChanged: (value) {
          ref
              .read(themeSettingProvider.notifier)
              .update((state) => state.copyWith(dynamicColor: value));
        },
      ),
    );
  }
}

class _PrimaryColorItem extends ConsumerStatefulWidget {
  const _PrimaryColorItem();

  @override
  ConsumerState<_PrimaryColorItem> createState() => _PrimaryColorItemState();
}

class _PrimaryColorItemState extends ConsumerState<_PrimaryColorItem> {
  int? _removablePrimaryColor;

  int _calcColumns(double maxWidth) {
    return max((maxWidth / 96).ceil(), 3);
  }

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.resetTip),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(
        primaryColors: defaultPrimaryColors,
        primaryColor: defaultPrimaryColor,
        schemeVariant: DynamicSchemeVariant.content,
      );
    });
  }

  Future<void> _handleDel() async {
    final appLocalizations = context.appLocalizations;
    if (_removablePrimaryColor == null) {
      return;
    }
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.colorSchemes),
      ),
    );
    if (res != true) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      final newPrimaryColors = List<int>.from(state.primaryColors)
        ..remove(_removablePrimaryColor);
      int? newPrimaryColor = state.primaryColor;
      if (state.primaryColor == _removablePrimaryColor) {
        if (newPrimaryColors.contains(defaultPrimaryColor)) {
          newPrimaryColor = defaultPrimaryColor;
        } else {
          newPrimaryColor = null;
        }
      }
      return state.copyWith(
        primaryColors: newPrimaryColors,
        primaryColor: newPrimaryColor,
      );
    });
    setState(() {
      _removablePrimaryColor = null;
    });
  }

  Future<void> _handleAdd() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showCommonDialog<int>(
      child: const _PaletteDialog(),
    );
    if (res == null) {
      return;
    }
    final isExists = ref.read(
      themeSettingProvider.select((state) => state.primaryColors.contains(res)),
    );
    if (isExists && mounted) {
      context.showNotifier(
        appLocalizations.existsTip(appLocalizations.colorSchemes),
      );
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(
        primaryColors: List.from(state.primaryColors)..add(res),
      );
    });
  }

  Future<void> _handleChangeSchemeVariant() async {
    final schemeVariant = ref.read(
      themeSettingProvider.select((state) => state.schemeVariant),
    );
    final value = await globalState.showCommonDialog<DynamicSchemeVariant>(
      child: OptionsDialog<DynamicSchemeVariant>(
        title: context.appLocalizations.colorSchemes,
        options: DynamicSchemeVariant.values,
        textBuilder: (item) => Intl.message('${item.name}Scheme'),
        value: schemeVariant,
      ),
    );
    if (value == null) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return state.copyWith(schemeVariant: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final vm4 = ref.watch(
      themeSettingProvider.select(
        (state) => VM4(
          state.primaryColor,
          state.primaryColors,
          state.schemeVariant,
          state.primaryColor == defaultPrimaryColor &&
              intListEquality.equals(
                state.primaryColors,
                defaultPrimaryColors,
              ) &&
              state.schemeVariant == DynamicSchemeVariant.content,
        ),
      ),
    );
    final primaryColor = vm4.a;
    final primaryColors = [null, ...vm4.b];
    final schemeVariant = vm4.c;
    final isEquals = vm4.d;

    return SliverToBoxAdapter(
      child: CommonPopScope(
        onPop: (context) {
          if (_removablePrimaryColor != null) {
            setState(() {
              _removablePrimaryColor = null;
            });
            return false;
          }
          return true;
        },
        child: ItemCard(
          info: Info(
            label: appLocalizations.themeColor,
            iconData: Icons.palette,
          ),
          actions: genActions([
            if (_removablePrimaryColor == null)
              FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _handleChangeSchemeVariant,
                child: Text(Intl.message('${schemeVariant.name}Scheme')),
              ),
            if (_removablePrimaryColor != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    _removablePrimaryColor = null;
                  });
                },
                child: Text(appLocalizations.cancel),
              ),
            if (_removablePrimaryColor == null && !isEquals)
              IconButton.filledTonal(
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                onPressed: _handleReset,
                icon: const Icon(Icons.replay),
              ),
          ], space: 8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final columns = _calcColumns(constraints.maxWidth);
                final itemWidth =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final color in primaryColors)
                      Container(
                        clipBehavior: Clip.none,
                        width: itemWidth,
                        height: itemWidth,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            EffectGestureDetector(
                              child: ColorSchemeBox(
                                isSelected: color == primaryColor,
                                primaryColor: color != null
                                    ? Color(color)
                                    : null,
                                onPressed: () {
                                  setState(() {
                                    _removablePrimaryColor = null;
                                  });
                                  ref
                                      .read(themeSettingProvider.notifier)
                                      .update(
                                        (state) =>
                                            state.copyWith(primaryColor: color),
                                      );
                                },
                              ),
                              onLongPress: () {
                                setState(() {
                                  _removablePrimaryColor = color;
                                });
                              },
                            ),
                            if (_removablePrimaryColor != null &&
                                _removablePrimaryColor == color)
                              Container(
                                color: Colors.white.opacity0,
                                padding: const EdgeInsets.all(8),
                                child: IconButton.filledTonal(
                                  onPressed: _handleDel,
                                  padding: const EdgeInsets.all(12),
                                  iconSize: 30,
                                  icon: Icon(
                                    color: context.colorScheme.primary,
                                    Icons.delete,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_removablePrimaryColor == null)
                      Container(
                        width: itemWidth,
                        height: itemWidth,
                        padding: const EdgeInsets.all(4),
                        child: IconButton.filledTonal(
                          onPressed: _handleAdd,
                          iconSize: 32,
                          icon: Icon(
                            color: context.colorScheme.primary,
                            Icons.add,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final String process = '${(textScale.scale * 100).round()}%';
    return Column(
      children: [
        ListItem.switchItem(
          title: Text(
            appLocalizations.textScale,
            style: _themePageTitleStyle(context, surge),
          ),
          delegate: SwitchDelegate(
            value: textScale.enable,
            onChanged: (value) {
              ref
                  .read(themeSettingProvider.notifier)
                  .update((state) => state.copyWith.textScale(enable: value));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            spacing: 32,
            children: [
              Expanded(
                child: DisabledMask(
                  status: !textScale.enable,
                  child: ActivateBox(
                    active: textScale.enable,
                    child: SliderTheme(
                      data: _SliderDefaultsM3(context),
                      child: Slider(
                        padding: EdgeInsets.zero,
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: (value) {
                          ref
                              .read(themeSettingProvider.notifier)
                              .update(
                                (state) =>
                                    state.copyWith.textScale(scale: value),
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 56),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surge.textSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    process,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: surge.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

TextStyle? _themePageTitleStyle(BuildContext context, SurgeTheme surge) {
  return context.textTheme.bodyMedium?.copyWith(
    color: surge.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog();

  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  final _controller = ValueNotifier<ui.Color>(Colors.transparent);

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.palette,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.value.toARGB32());
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 250,
            height: 250,
            child: Palette(controller: _controller),
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, color, _) {
              return PrimaryColorBox(
                primaryColor: color,
                child: FilledButton(
                  onPressed: () {},
                  child: Text(_controller.value.hex),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.secondaryContainer;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _colors.onSurface.withOpacity(0.38);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(1.0);

  @override
  Color? get inactiveTickMarkColor =>
      _colors.onSecondaryContainer.withOpacity(1.0);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onInverseSurface;

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface;

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get overlayColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.dragged)) {
          return _colors.primary.withOpacity(0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withOpacity(0.1);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle => Theme.of(
    context,
  ).textTheme.labelLarge!.copyWith(color: _colors.onInverseSurface);

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.hovered)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.focused)) {
        return const Size(2.0, 44.0);
      }
      if (states.contains(WidgetState.pressed)) {
        return const Size(2.0, 44.0);
      }
      return const Size(4.0, 44.0);
    });
  }

  @override
  double? get trackGap => 6.0;
}
