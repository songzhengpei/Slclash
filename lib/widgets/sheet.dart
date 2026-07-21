import 'dart:ui';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_bar/sl_app_bar.dart';
import 'app_bar/sl_app_bar_action.dart';
import 'app_bar/sl_app_bar_buttons.dart';
import 'scaffold.dart';
import 'side_sheet.dart';

@immutable
class SheetProps {
  final double? maxWidth;
  final double? maxHeight;
  final bool isScrollControlled;
  final bool useSafeArea;
  final Color? backgroundColor;
  final bool blur;

  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.backgroundColor,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
}

@immutable
class ExtendProps {
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
  final bool forceFull;

  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
    this.forceFull = false,
  });
}

enum SheetType { page, bottomSheet, sideSheet }

Future<T?> showSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  SheetProps props = const SheetProps(),
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final isMobile = globalState.container.read(isMobileViewProvider);
  final Future<T?> route = switch (isMobile) {
    true => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: props.isScrollControlled,
      builder: (_) {
        return SheetProvider(
          type: SheetType.bottomSheet,
          child: builder(context),
        );
      },
      backgroundColor: props.backgroundColor,
      barrierColor: Colors.black.withValues(
        alpha: SurgeMotion.modalBarrierOpacity,
      ),
      sheetAnimationStyle: const AnimationStyle(
        duration: SurgeMotion.sheetEnter,
        reverseDuration: SurgeMotion.sheetExit,
      ),
      showDragHandle: false,
      useSafeArea: props.useSafeArea,
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      isScrollControlled: props.isScrollControlled,
      context: context,
      backgroundColor: props.backgroundColor,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (_) {
        return SheetProvider(
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
  final result = await route;
  FocusManager.instance.primaryFocus?.unfocus();
  return result;
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) {
  final isMobile = globalState.container.read(isMobileViewProvider);
  return switch (isMobile || props.forceFull) {
    true => BaseNavigator.push(
      context,
      SheetProvider(type: SheetType.page, child: builder(context)),
    ),
    false => showModalSideSheet<T>(
      useSafeArea: props.useSafeArea,
      context: context,
      constraints: BoxConstraints(maxWidth: props.maxWidth ?? 360),
      filter: props.blur ? commonFilter : null,
      builder: (context) {
        return SheetProvider(
          type: SheetType.sideSheet,
          child: builder(context),
        );
      },
    ),
  };
}

class AdaptiveSheetScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final bool sheetTransparentToolBar;
  final List<IconButtonData> actions;
  final List<SlAppBarAction>? appBarActions;
  final VoidCallback? backAction;

  const AdaptiveSheetScaffold({
    super.key,
    required this.body,
    required this.title,
    this.sheetTransparentToolBar = false,
    this.actions = const [],
    this.appBarActions,
    this.backAction,
  });

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  final _isScrolledController = ValueNotifier<bool>(false);

  void _validateRuntime() {
    if (widget.appBarActions != null && widget.actions.isNotEmpty) {
      throw FlutterError(
        'AdaptiveSheetScaffold cannot use both actions and appBarActions.',
      );
    }
    if (widget.appBarActions != null && widget.appBarActions!.length > 1) {
      throw FlutterError(
        'AdaptiveSheetScaffold supports at most one semantic app bar action.',
      );
    }
  }

  IconData get backIconData {
    if (kIsWeb) return SurgeIcons.back;
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return SurgeIcons.back;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return SurgeIcons.back;
    }
  }

  @override
  void didUpdateWidget(covariant AdaptiveSheetScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backAction != widget.backAction) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _isScrolledController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _validateRuntime();
    final sheetProvider = SheetProvider.of(context);
    final nestedNavigatorPop = sheetProvider?.nestedNavigatorPop;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    final type = sheetProvider?.type ?? SheetType.page;
    final backgroundColor = type == SheetType.bottomSheet
        ? context.colorScheme.surfaceContainerLow
        : context.colorScheme.surface;
    final useCloseIcon =
        type != SheetType.page &&
        (nestedNavigatorPop != null && route?.impliesAppBarDismissal == false ||
            nestedNavigatorPop == null);
    final compact = type == SheetType.bottomSheet;
    final isSemantic = widget.appBarActions != null;

    Widget buildIconButton(IconButtonData data) {
      return SoftOsActionButton(
        icon: data.icon,
        onPressed: data.onPressed,
        compact: compact,
      );
    }

    Widget? buildActionGroup(List<IconButtonData> data) {
      if (data.isEmpty) return null;
      if (data.length == 1) return buildIconButton(data.first);
      final children = <Widget>[];
      for (var index = 0; index < data.length; index++) {
        if (index > 0) children.add(const SoftOsActionDivider());
        children.add(
          SoftOsActionDockButton(
            icon: data[index].icon,
            onPressed: data[index].onPressed,
            compact: compact,
          ),
        );
      }
      return SoftOsActionDock(compact: compact, children: children);
    }

    final AppBar appBar = isSemantic
        ? _buildSemanticAppBar(
            type: type,
            backgroundColor: backgroundColor,
            useCloseIcon: useCloseIcon,
            route: route,
          )
        : _buildLegacyAppBar(
            type: type,
            backgroundColor: backgroundColor,
            useCloseIcon: useCloseIcon,
            compact: compact,
            route: route,
            buildActionGroup: buildActionGroup,
          );

    if (type == SheetType.bottomSheet) {
      const handleSize = Size(28, 4);
      final sheetAppBar = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              alignment: Alignment.center,
              height: handleSize.height,
              width: handleSize.width,
              decoration: ShapeDecoration(
                color: context.colorScheme.onSurfaceVariant,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(handleSize.height / 2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: appBar,
          ),
          const SizedBox(height: 6),
        ],
      );
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.sheetTransparentToolBar) ...[
              sheetAppBar,
              Flexible(child: widget.body),
            ] else ...[
              Flexible(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      child: widget.body,
                      onNotification: (notification) {
                        if (notification is ScrollUpdateNotification) {
                          final pixels = notification.metrics.pixels;
                          _isScrolledController.value = pixels > 6;
                        }
                        return false;
                      },
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ValueListenableBuilder(
                        valueListenable: _isScrolledController,
                        builder: (_, isScrolled, child) {
                          return ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 12.0,
                                sigmaY: 12.0,
                              ),
                              child: ColoredBox(
                                color: isScrolled
                                    ? backgroundColor.opacity60
                                    : backgroundColor,
                                child: child!,
                              ),
                            ),
                          );
                        },
                        child: sheetAppBar,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
          ],
        ),
      );
    }
    return CommonScaffold(appBar: appBar, body: widget.body);
  }

  AppBar _buildSemanticAppBar({
    required SheetType type,
    required Color backgroundColor,
    required bool useCloseIcon,
    required ModalRoute<dynamic>? route,
  }) {
    final materialLocalizations = MaterialLocalizations.of(context);

    Widget? leading;
    VoidCallback? leadingOnPressed;
    if (type != SheetType.page) {
      if (useCloseIcon) {
        leadingOnPressed = context.safeNestedPop;
        leading = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SlAppBarIconButton(
            icon: SurgeIcons.close,
            tooltip: materialLocalizations.closeButtonTooltip,
            onPressed: leadingOnPressed,
          ),
        );
      } else {
        leadingOnPressed =
            widget.backAction ??
            () {
              Navigator.of(context).pop();
            };
        leading = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SlAppBarIconButton(
            icon: backIconData,
            tooltip: materialLocalizations.backButtonTooltip,
            onPressed: leadingOnPressed,
          ),
        );
      }
    } else if (route?.impliesAppBarDismissal == true) {
      leadingOnPressed =
          widget.backAction ??
          () {
            Navigator.of(context).maybePop();
          };
      leading = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SlAppBarIconButton(
          icon: backIconData,
          tooltip: materialLocalizations.backButtonTooltip,
          onPressed: leadingOnPressed,
        ),
      );
    }

    final trailing =
        widget.appBarActions != null && widget.appBarActions!.isNotEmpty
        ? SlAppBarActionsRenderer(actions: widget.appBarActions!)
        : null;

    final reserveSlots = leading != null || trailing != null;
    const slotWidth = 72.0;
    final effectiveSlotWidth = reserveSlots ? slotWidth : 0.0;

    return AppBar(
      backgroundColor: backgroundColor,
      forceMaterialTransparency: type == SheetType.bottomSheet,
      automaticallyImplyLeading: false,
      centerTitle: true,
      toolbarHeight: type == SheetType.bottomSheet ? 48 : null,
      titleTextStyle: type == SheetType.bottomSheet
          ? context.typography.sheetTitle.copyWith(
              color: SurgeTheme.of(context).textPrimary,
            )
          : null,
      title: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: reserveSlots
          ? Align(
              alignment: Alignment.centerLeft,
              child: leading ?? const SizedBox.shrink(),
            )
          : null,
      leadingWidth: effectiveSlotWidth,
      actions: [
        if (reserveSlots)
          SizedBox(
            width: effectiveSlotWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  AppBar _buildLegacyAppBar({
    required SheetType type,
    required Color backgroundColor,
    required bool useCloseIcon,
    required bool compact,
    required ModalRoute<dynamic>? route,
    required Widget? Function(List<IconButtonData>) buildActionGroup,
  }) {
    final actions = [?buildActionGroup(widget.actions)];

    final popButton = type != SheetType.page
        ? (useCloseIcon
              ? SoftOsActionButton(
                  icon: SurgeIcons.close,
                  onPressed: context.safeNestedPop,
                  compact: compact,
                )
              : SoftOsActionButton(
                  icon: backIconData,
                  onPressed:
                      widget.backAction ??
                      () {
                        Navigator.of(context).pop();
                      },
                  compact: compact,
                ))
        : null;
    final suffixPop = type != SheetType.page && actions.isEmpty && useCloseIcon;
    final pagePopButton =
        type == SheetType.page && route?.impliesAppBarDismissal == true
        ? SoftOsActionButton(
            icon: backIconData,
            onPressed:
                widget.backAction ??
                () {
                  Navigator.of(context).maybePop();
                },
            compact: compact,
          )
        : null;
    final leading = suffixPop ? null : popButton ?? pagePopButton;

    return AppBar(
      backgroundColor: backgroundColor,
      forceMaterialTransparency: type == SheetType.bottomSheet,
      leading: leading,
      leadingWidth: leading != null ? 56 : null,
      automaticallyImplyLeading: false,
      centerTitle: true,
      toolbarHeight: type == SheetType.bottomSheet ? 48 : null,
      title: Text(widget.title),
      titleTextStyle: type == SheetType.bottomSheet
          ? context.typography.sheetTitle.copyWith(
              color: SurgeTheme.of(context).textPrimary,
            )
          : null,
      actions: !suffixPop
          ? genActions(actions, endSpace: 16)
          : genActions([?popButton], endSpace: 16),
    );
  }
}
