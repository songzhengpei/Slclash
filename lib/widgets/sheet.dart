import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_bar/sl_app_bar_action.dart';
import 'app_bar/sl_app_bar_buttons.dart';
import 'app_bar/sl_app_bar.dart';
import 'scaffold.dart';

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
      builder: builder,
      isScrollControlled: props.isScrollControlled,
      useSafeArea: props.useSafeArea,
      backgroundColor: props.backgroundColor,
      constraints: BoxConstraints(
        maxWidth: props.maxWidth ?? 400,
        maxHeight: props.maxHeight ?? MediaQuery.of(context).size.height - 60,
      ),
    ),
    false => Navigator.of(context).push<T>(
      _SheetRoute<T>(
        builder: builder,
        props: props,
      ),
    ),
  };
  return route;
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push<T>(
    _ExtendRoute<T>(
      builder: builder,
      props: props,
    ),
  );
}

class _SheetRoute<T> extends PageRoute<T> {
  _SheetRoute({required this.builder, required this.props});

  final WidgetBuilder builder;
  final SheetProps props;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => 'sheet';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final theme = Theme.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final shadowColor = theme.shadowColor;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              right: 0,
              top: 6,
              bottom: 6,
              width: MediaQuery.of(context).size.width * (1 - animation.value),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surface.withValues(alpha: 0.5 * (1 - animation.value)),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.3 * animation.value),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * animation.value,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    bottomLeft: Radius.circular(28),
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class _ExtendRoute<T> extends PageRoute<T> {
  _ExtendRoute({required this.builder, required this.props});

  final WidgetBuilder builder;
  final ExtendProps props;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => 'extend';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(0, 0.15), end: Offset.zero),
      ),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

class AdaptiveSheetScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final bool sheetTransparentToolBar;
  final List<SlAppBarAction> actions;
  final VoidCallback? backAction;

  const AdaptiveSheetScaffold({
    super.key,
    required this.body,
    required this.title,
    this.sheetTransparentToolBar = false,
    this.actions = const [],
    this.backAction,
  });

  @override
  State<AdaptiveSheetScaffold> createState() => _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends State<AdaptiveSheetScaffold> {
  final _isScrolledController = ValueNotifier<bool>(false);

  IconData get backIconData {
    if (kIsWeb) {
      return SurgeIcons.back;
    }
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

    // Leading button.
    final leading = () {
      if (type == SheetType.page) {
        if (route?.impliesAppBarDismissal == true) {
          return slAppBarLeadingButton(
            tooltip: 'Back',
            onPressed: widget.backAction ?? () => Navigator.of(context).maybePop(),
          );
        }
        return null;
      }
      return slAppBarLeadingButton(
        tooltip: useCloseIcon ? 'Close' : 'Back',
        onPressed: useCloseIcon
            ? context.safeNestedPop
            : widget.backAction ?? () => Navigator.of(context).pop(),
        isClose: useCloseIcon,
      );
    }();

    // Right actions rendered via the new action model.
    final actionWidgets = widget.actions.isEmpty
        ? null
        : buildAppBarActions(context, widget.actions);

    // Symmetrical toolbar: left slot | centred title | right slot.
    const slotWidth = 64.0;
    final toolbarHeight = type == SheetType.bottomSheet ? 48.0 : kToolbarHeight;
    final appBar = AppBar(
      toolbarHeight: toolbarHeight,
      backgroundColor: backgroundColor,
      forceMaterialTransparency: true,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          SizedBox(
            width: slotWidth,
            child: leading != null
                ? Align(alignment: Alignment.centerLeft, child: leading)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.title,
                style: context.typography.sheetTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: slotWidth,
            child: actionWidgets != null
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actionWidgets,
                    ),
                  )
                : null,
          ),
        ],
      ),
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
              decoration: BoxDecoration(
                color: SurgeTheme.of(context).separator,
                borderRadius: BorderRadius.circular(handleSize.height / 2),
              ),
            ),
          ),
          appBar,
        ],
      );

      if (widget.sheetTransparentToolBar) {
        final scrollThreshold = type == SheetType.bottomSheet ? 0.0 : 100.0;
        return ValueListenableBuilder<bool>(
          valueListenable: _isScrolledController,
          builder: (context, isScrolled, child) {
            final topOpacity = isScrolled ? 1.0 : 0.0;
            return Stack(
              children: [
                child!,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: topOpacity,
                    duration: SurgeMotion.state,
                    child: appBar,
                  ),
                ),
              ],
            );
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                _isScrolledController.value =
                    notification.metrics.pixels > scrollThreshold;
              }
              return false;
            },
            child: widget.body,
          ),
        );
      }
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(48 + 6 + handleSize.height),
          child: sheetAppBar,
        ),
        body: widget.body,
      );
    }

    return CommonScaffold(appBar: appBar, body: widget.body);
  }
}
