import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:flutter/material.dart';

import 'animated_cross_slide.dart';
import 'surge/surge_motion.dart';
import 'surge/surge_theme_extension.dart';

class CommonPopupRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  ValueNotifier<Offset> offsetNotifier;
  final bool belowTarget;

  CommonPopupRoute({
    required this.barrierLabel,
    required this.builder,
    required this.offsetNotifier,
    this.belowTarget = false,
  });

  @override
  String? barrierLabel;

  @override
  Color? get barrierColor => null;

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
    final align = belowTarget ? Alignment.topLeft : Alignment.topRight;
    final curveAnimation = CurvedAnimation(
      parent: animation,
      curve: SurgeMotion.enterCurve,
      reverseCurve: SurgeMotion.exitCurve,
    );
    final positioned = ValueListenableBuilder(
      valueListenable: offsetNotifier,
      builder: (_, value, child) {
        return Align(
          alignment: align,
          child: CustomSingleChildLayout(
            delegate: OverflowAwareLayoutDelegate(
              offset: belowTarget ? value : value.translate(48, -8),
              alignToLeft: belowTarget,
            ),
            child: child,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, child) {
          return FadeTransition(
            opacity: curveAnimation,
            child: ScaleTransition(
              alignment: align,
              scale: curveAnimation.drive(Tween(begin: 0.88, end: 1.0)),
              child: SlideTransition(
                position: curveAnimation.drive(
                  Tween(begin: const Offset(0, -0.035), end: Offset.zero),
                ),
                child: child,
              ),
            ),
          );
        },
        child: builder(context),
      ),
    );
    return belowTarget ? positioned : SafeArea(child: positioned);
  }

  @override
  Duration get transitionDuration => SurgeMotion.container;

  @override
  Duration get reverseTransitionDuration => SurgeMotion.state;
}

class PopupController extends ValueNotifier<bool> {
  PopupController() : super(false);

  void open() {
    value = true;
  }

  void close() {
    value = false;
  }
}

typedef PopupOpen = Function({Offset offset});

class CommonPopupBox extends StatefulWidget {
  final Widget Function(PopupOpen open) targetBuilder;
  final Widget popup;
  final bool belowTarget;

  const CommonPopupBox({
    super.key,
    required this.targetBuilder,
    required this.popup,
    this.belowTarget = false,
  });

  @override
  State<CommonPopupBox> createState() => _CommonPopupBoxState();
}

class _CommonPopupBoxState extends State<CommonPopupBox> {
  bool _isOpen = false;
  final _targetOffsetValueNotifier = ValueNotifier<Offset>(Offset.zero);
  Offset _offset = Offset.zero;

  void _open({Offset offset = Offset.zero}) {
    _offset = offset;
    _updateOffset();
    _isOpen = true;
    Navigator.of(context)
        .push(
          CommonPopupRoute(
            barrierLabel: utils.id,
            builder: (BuildContext context) {
              return widget.popup;
            },
            offsetNotifier: _targetOffsetValueNotifier,
            belowTarget: widget.belowTarget,
          ),
        )
        .then((_) {
          _isOpen = false;
        });
  }

  void _updateOffset() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final viewPadding = MediaQuery.viewPaddingOf(context);
    if (widget.belowTarget) {
      final bottomLeft = renderBox.localToGlobal(
        Offset(0, renderBox.size.height),
      );
      _targetOffsetValueNotifier.value = Offset(
        bottomLeft.dx + _offset.dx,
        bottomLeft.dy + _offset.dy,
      );
    } else {
      _targetOffsetValueNotifier.value = renderBox
          .localToGlobal(
            Offset.zero.translate(viewPadding.right, viewPadding.top),
          )
          .translate(_offset.dx, _offset.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isOpen) {
            _updateOffset();
          }
        });
        return widget.targetBuilder(_open);
      },
    );
  }
}

class OverflowAwareLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset offset;
  final bool alignToLeft;

  OverflowAwareLayoutDelegate({required this.offset, this.alignToLeft = false});

  @override
  Size getSize(BoxConstraints constraints) {
    return Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const safeOffset = Offset(16, 16);
    final double x = (alignToLeft ? offset.dx : offset.dx - childSize.width)
        .clamp(0, size.width - safeOffset.dx - childSize.width);
    final double y = (offset.dy).clamp(
      0,
      size.height - safeOffset.dy - childSize.height,
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant OverflowAwareLayoutDelegate oldDelegate) {
    return oldDelegate.offset != offset ||
        oldDelegate.alignToLeft != alignToLeft;
  }
}

class CommonPopupMenu extends StatelessWidget {
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double minItemVerticalPadding;

  const CommonPopupMenu({
    super.key,
    required this.items,
    this.minWidth = 0,
    this.minItemVerticalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = surge.radii.menuRow;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: surge.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        elevation: 0,
        color: surge.elevatedCard,
        clipBehavior: Clip.antiAlias,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: surge.separator.withValues(alpha: 0.72),
            width: 0.5,
          ),
        ),
        child: IntrinsicWidth(
          child: _CommonPopupMenuItems(
            items: items,
            minWidth: minWidth,
            minItemVerticalPadding: minItemVerticalPadding,
          ),
        ),
      ),
    );
  }
}

class _CommonPopupMenuItems extends StatefulWidget {
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double minItemVerticalPadding;

  const _CommonPopupMenuItems({
    required this.items,
    required this.minWidth,
    required this.minItemVerticalPadding,
  });

  @override
  State<_CommonPopupMenuItems> createState() => _CommonPopupMenuItemsState();
}

class _CommonPopupMenuItemsState extends State<_CommonPopupMenuItems> {
  List<PopupMenuItemData> _nextItems = [];
  String? _subTitle;
  bool _status = false;

  Widget _popupMenuItem(
    BuildContext context, {
    required PopupMenuItemData item,
    required int index,
  }) {
    final onPressed = item.subItems.isNotEmpty
        ? () {
            _nextItems = item.subItems;
            _subTitle = item.label;
            setState(() {
              _status = true;
            });
          }
        : item.onPressed;
    final disabled = onPressed == null;
    final surge = SurgeTheme.of(context);
    final color = item.danger ? surge.red : surge.textPrimary;
    final foregroundColor = disabled ? color.opacity30 : color;
    final backgroundColor = item.danger
        ? surge.red.withValues(alpha: 0.08)
        : Colors.transparent;
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: LinearBorder.none,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        overlayColor: foregroundColor.withValues(alpha: 0.07),
      ),
      onPressed: onPressed != null
          ? () {
              if (item.subItems.isEmpty) {
                Navigator.of(context).pop();
              }
              onPressed();
            }
          : null,
      child: Container(
        constraints: BoxConstraints(minWidth: widget.minWidth),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: widget.minItemVerticalPadding,
          bottom: widget.minItemVerticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 18, color: foregroundColor),
              const SizedBox(width: 16),
            ],
            Flexible(
              child: Text(
                item.label,
                style: context.typography.controlLabel.copyWith(
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems(List<PopupMenuItemData> items) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items.asMap().entries) ...[
          _popupMenuItem(context, item: item.value, index: item.key),
          if (item.value != items.last)
            Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 12,
              endIndent: 12,
              color: SurgeTheme.of(context).separator.withValues(alpha: 0.58),
            ),
        ],
      ],
    );
  }

  Widget _buildSubMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2),
          child: Row(
            spacing: 4,
            children: [
              IconButton(
                icon: Icon(
                  SurgeIcons.back,
                  color: context.colorScheme.onSurfaceVariant.opacity80,
                ),
                onPressed: () {
                  setState(() {
                    _status = false;
                  });
                },
                iconSize: 18,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: WidgetStatePropertyAll(Size.zero),
                  padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
                ),
              ),
              if (_subTitle != null)
                Text(
                  _subTitle!,
                  style: context.typography.supporting.copyWith(
                    color: context.colorScheme.onSurfaceVariant.opacity80,
                  ),
                ),
            ],
          ),
        ),
        _CommonPopupMenuItems(
          items: _nextItems,
          minWidth: widget.minWidth,
          minItemVerticalPadding: widget.minItemVerticalPadding,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossSlide(
      secondCurve: Curves.easeOut,
      firstChild: _buildItems(widget.items),
      secondChild: _nextItems.isEmpty ? Container() : _buildSubMenu(),
      crossSlideState: _status
          ? CrossSlideState.showSecond
          : CrossSlideState.showFirst,
      duration: const Duration(milliseconds: 250),
    );
  }
}
