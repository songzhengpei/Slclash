import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/popup.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chip.dart';
import 'inherited.dart';
import 'theme.dart';

typedef OnKeywordsUpdateCallback = void Function(List<String> keywords);

typedef AppBarSearchStateBuilder =
    AppBarSearchState? Function(AppBarSearchState? state);

class CommonScaffold extends StatefulWidget {
  final AppBar? appBar;
  final Widget body;
  final Color? backgroundColor;
  final String? title;
  final bool isLoading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final Widget? floatingActionButton;
  final AppBarEditState? editState;
  final AppBarSearchState? searchState;
  final OnKeywordsUpdateCallback? onKeywordsUpdate;
  final bool? resizeToAvoidBottomInset;

  const CommonScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.title,
    this.actions,
    this.centerTitle,
    this.editState,
    this.isLoading = false,
    this.searchState,
    this.floatingActionButton,
    this.onKeywordsUpdate,
    this.resizeToAvoidBottomInset,
  });

  @override
  State<CommonScaffold> createState() => CommonScaffoldState();
}

class CommonScaffoldState extends State<CommonScaffold> {
  late final ValueNotifier<AppBarState> _appBarState;
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isFabExtendedNotifier = ValueNotifier(true);
  final ValueNotifier<List<String>> _keywordsNotifier = ValueNotifier([]);
  final _textController = TextEditingController();

  bool get _isSearch {
    return _appBarState.value.searchState?.query != null;
  }

  bool get _isEdit {
    final editState = _appBarState.value.editState;
    if (editState == null) {
      return false;
    }
    return editState.editCount > 0;
  }

  @override
  void initState() {
    super.initState();
    _appBarState = ValueNotifier(
      AppBarState(editState: widget.editState, searchState: widget.searchState),
    );
    _loadingNotifier.value = widget.isLoading;
  }

  Future<void> _updateSearchState(AppBarSearchStateBuilder builder) async {
    _appBarState.value = _appBarState.value.copyWith(
      searchState: builder(_appBarState.value.searchState),
    );
  }

  void handleToSearch() {
    _updateSearchState((state) => state?.copyWith(query: ''));
  }

  Widget _buildSearchingAppBarTheme(Widget child) {
    final ThemeData theme = Theme.of(context);
    final surge = SurgeTheme.of(context);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: surge.card,
          iconTheme: theme.primaryIconTheme.copyWith(
            color: surge.textSecondary,
          ),
          titleTextStyle: theme.textTheme.titleLarge,
          toolbarTextStyle: theme.textTheme.bodyMedium,
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: theme.inputDecorationTheme.hintStyle,
          border: InputBorder.none,
        ),
      ),
      child: child,
    );
  }

  @override
  void didUpdateWidget(CommonScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editState != widget.editState) {
      _appBarState.value = _appBarState.value.copyWith(
        editState: widget.editState,
      );
    }
    if (oldWidget.searchState != widget.searchState) {
      _appBarState.value = _appBarState.value.copyWith(
        searchState: widget.searchState,
      );
    }
    if (oldWidget.isLoading != widget.isLoading) {
      _loadingNotifier.value = widget.isLoading;
    }
  }

  void _handleClearInput() {
    _textController.text = '';
    if (_appBarState.value.searchState != null) {
      _appBarState.value.searchState!.onSearch('');
    }
  }

  void _handleClear() {
    if (_textController.text.isNotEmpty) {
      _handleClearInput();
      return;
    }
    _updateSearchState((state) => state?.copyWith(query: null));
  }

  void handleExitSearching() {
    if (!_isSearch) {
      return;
    }
    _handleClearInput();
    _updateSearchState((state) => state?.copyWith(query: null));
  }

  @override
  void dispose() {
    _appBarState.dispose();
    _textController.dispose();
    _isFabExtendedNotifier.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  void addKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)..add(keyword);
    _keywordsNotifier.value = keywords;
  }

  void _deleteKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (!isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)
      ..remove(keyword);
    _keywordsNotifier.value = keywords;
  }

  Widget? _buildLeading(VoidCallback? backAction) {
    Widget buildLeadingButton({
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SoftOsActionButton(
            icon: normalizeSoftOsActionIcon(icon),
            onPressed: onPressed,
          ),
        ),
      );
    }

    if (_isEdit) {
      return buildLeadingButton(
        onPressed: _appBarState.value.editState?.onExit,
        icon: Icons.close,
      );
    }
    if (_isSearch) {
      return buildLeadingButton(
        onPressed: handleExitSearching,
        icon: Icons.arrow_back,
      );
    }
    if (backAction != null) {
      return buildLeadingButton(
        icon: Icons.arrow_back,
        onPressed: () {
          if (!mounted) {
            return;
          }
          backAction();
        },
      );
    }
    final route = ModalRoute.of(context);
    if (route?.impliesAppBarDismissal == true) {
      return buildLeadingButton(
        icon: Icons.arrow_back,
        onPressed: () {
          Navigator.of(context).maybePop();
        },
      );
    }
    return null;
  }

  Widget _buildTitle(AppBarSearchState? startState) {
    final appLocalizations = context.appLocalizations;
    return _isSearch
        ? TextField(
            autofocus: true,
            controller: _textController,
            style: context.textTheme.titleLarge,
            onChanged: (value) {
              if (startState != null) {
                startState.onSearch(value);
              }
            },
            decoration: InputDecoration(hintText: appLocalizations.search),
          )
        : Text(
            !_isEdit
                ? widget.title!
                : appLocalizations.selectedCountTitle(
                    '${_appBarState.value.editState?.editCount ?? 0}',
                  ),
          );
  }

  IconData _normalizeActionIcon(IconData icon) {
    return normalizeSoftOsActionIcon(icon);
  }

  IconData? _resolveIconData(Widget icon) {
    if (icon is Icon && icon.icon != null) {
      return _normalizeActionIcon(icon.icon!);
    }
    return null;
  }

  String? _resolveTextLabel(Widget? child) {
    if (child is Text) {
      return child.data;
    }
    return null;
  }

  _SoftOsScaffoldAction? _resolveAction(Widget action) {
    if (action is SizedBox && action.child == null) {
      return null;
    }
    if (action is CommonMinIconButtonTheme) {
      return _resolveAction(action.child);
    }
    if (action is CommonMinFilledButtonTheme) {
      return _resolveAction(action.child);
    }
    if (action is Consumer) {
      return _SoftOsScaffoldAction.consumer(action);
    }
    if (action is CommonPopupBox) {
      return _SoftOsScaffoldAction.popup(action.popup);
    }
    if (action is SurgeAddButton) {
      return _SoftOsScaffoldAction.text(
        label: action.label,
        onPressed: action.onPressed,
      );
    }
    if (action is ButtonStyleButton) {
      final label = _resolveTextLabel(action.child);
      if (label != null && label.isNotEmpty) {
        return _SoftOsScaffoldAction.text(
          label: label,
          onPressed: action.onPressed,
        );
      }
    }
    if (action is IconButton) {
      final icon = _resolveIconData(action.icon);
      return _SoftOsScaffoldAction(
        icon: icon,
        child: icon == null ? action.icon : null,
        onPressed: action.onPressed,
        tooltip: action.tooltip,
      );
    }
    if (action is SoftOsIconButton) {
      return _SoftOsScaffoldAction(
        icon: _normalizeActionIcon(action.icon),
        onPressed: action.onPressed,
      );
    }
    if (action is SoftOsActionButton) {
      return _SoftOsScaffoldAction(child: action, onPressed: null, raw: true);
    }
    return _SoftOsScaffoldAction(child: action, onPressed: null, raw: true);
  }

  Widget _buildActionTarget(
    _SoftOsScaffoldAction action, {
    required bool inDock,
  }) {
    if (action.consumer != null) {
      final consumer = action.consumer!;
      return Consumer(
        builder: (context, ref, child) {
          final resolved = _resolveAction(
            consumer.builder(context, ref, consumer.child),
          );
          if (resolved == null) {
            return const SizedBox.shrink();
          }
          return _buildActionTarget(resolved, inDock: inDock);
        },
      );
    }
    if (action.popup != null) {
      return CommonPopupBox(
        popup: action.popup!,
        targetBuilder: (open) {
          return inDock
              ? SoftOsActionDockButton(
                  icon: normalizeSoftOsActionIcon(Icons.more_vert),
                  onPressed: () {
                    open(offset: const Offset(0, 0));
                  },
                )
              : SoftOsActionButton(
                  icon: normalizeSoftOsActionIcon(Icons.more_vert),
                  onPressed: () {
                    open(offset: const Offset(0, 0));
                  },
                );
        },
      );
    }
    if (action.label != null) {
      return inDock
          ? SoftOsActionDockTextButton(
              label: action.label!,
              onPressed: action.onPressed,
              tooltip: action.tooltip,
            )
          : SoftOsActionTextButton(
              label: action.label!,
              onPressed: action.onPressed,
              tooltip: action.tooltip,
            );
    }
    if (action.raw) {
      return SizedBox.square(dimension: 48, child: Center(child: action.child));
    }
    return inDock
        ? SoftOsActionDockButton(
            icon: action.icon,
            onPressed: action.onPressed,
            tooltip: action.tooltip,
            child: action.child,
          )
        : SoftOsActionButton(
            icon: action.icon,
            onPressed: action.onPressed,
            tooltip: action.tooltip,
            child: action.child,
          );
  }

  Widget _buildSoftOsActions(List<_SoftOsScaffoldAction> actions) {
    if (actions.length == 1) {
      return _buildActionTarget(actions.first, inDock: false);
    }

    final children = <Widget>[];
    for (var index = 0; index < actions.length; index++) {
      final action = actions[index];
      if (index > 0) {
        children.add(const SoftOsActionDivider());
      }
      children.add(_buildActionTarget(action, inDock: true));
    }

    return SoftOsActionDock(children: children);
  }

  List<Widget> _buildActions(bool hasSearch, List<Widget> actions) {
    if (_isSearch) {
      return genActions([
        SoftOsActionButton(
          icon: normalizeSoftOsActionIcon(Icons.close),
          onPressed: _handleClear,
        ),
      ], endSpace: 16);
    }
    final resolvedActions = [
      if (hasSearch && widget.searchState?.autoAddSearch == true)
        _SoftOsScaffoldAction(
          icon: normalizeSoftOsActionIcon(Icons.search),
          onPressed: () {
            _updateSearchState((state) => state?.copyWith(query: ''));
          },
        ),
      ...actions.map(_resolveAction).nonNulls,
    ];
    if (resolvedActions.isEmpty) {
      return const [];
    }
    return genActions([_buildSoftOsActions(resolvedActions)], endSpace: 16);
  }

  Widget _buildAppBarWrap(Widget child) {
    final appBar = _isSearch ? _buildSearchingAppBarTheme(child) : child;
    if (_isEdit || _isSearch) {
      return SystemBackBlock(
        child: CommonPopScope(
          onPop: (context) {
            if (_isEdit || _isSearch) {
              handleExitSearching();
              _appBarState.value.editState?.onExit();
              return false;
            }
            return true;
          },
          child: appBar,
        ),
      );
    }
    return appBar;
  }

  PreferredSizeWidget _buildAppBar(VoidCallback? backAction) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          widget.appBar ??
              ValueListenableBuilder<AppBarState>(
                valueListenable: _appBarState,
                builder: (_, state, _) {
                  final leading = _buildLeading(backAction);
                  return _buildAppBarWrap(
                    AppBar(
                      automaticallyImplyLeading: false,
                      animateColor: true,
                      centerTitle: widget.centerTitle ?? false,
                      leading: leading,
                      leadingWidth: leading != null ? 64 : null,
                      title: _buildTitle(state.searchState),
                      actions: _buildActions(
                        state.searchState != null,
                        state.actions.isNotEmpty
                            ? state.actions
                            : widget.actions ?? [],
                      ),
                    ),
                  );
                },
              ),
          ValueListenableBuilder(
            valueListenable: _loadingNotifier,
            builder: (_, value, _) {
              return value == true
                  ? const LinearProgressIndicator()
                  : Container();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.appBar != null || widget.title != null);
    final backActionProvider = CommonScaffoldBackActionProvider.of(context);
    final body = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder(
            valueListenable: _keywordsNotifier,
            builder: (_, keywords, _) {
              if (widget.onKeywordsUpdate != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onKeywordsUpdate!(keywords);
                });
              }
              if (keywords.isEmpty) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    for (final keyword in keywords)
                      CommonChip(
                        label: keyword,
                        type: ChipType.delete,
                        onPressed: () {
                          _deleteKeyword(keyword);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(child: widget.body),
        ],
      ),
    );
    return Scaffold(
      appBar: _buildAppBar(backActionProvider?.backAction),
      body: NotificationListener<UserScrollNotification>(
        child: body,
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            _isFabExtendedNotifier.value = false;
          } else if (notification.direction == ScrollDirection.forward) {
            _isFabExtendedNotifier.value = true;
          }
          return true;
        },
      ),
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      backgroundColor: widget.backgroundColor,
      floatingActionButton: widget.floatingActionButton != null
          ? ValueListenableBuilder<bool>(
              valueListenable: _isFabExtendedNotifier,
              builder: (_, isExtended, child) {
                return CommonScaffoldFabExtendedProvider(
                  isExtended: isExtended,
                  child: child!,
                );
              },
              child: widget.floatingActionButton,
            )
          : null,
    );
  }
}

class _SoftOsScaffoldAction {
  const _SoftOsScaffoldAction({
    this.icon,
    this.child,
    this.label,
    this.consumer,
    this.popup,
    required this.onPressed,
    this.tooltip,
    this.raw = false,
  }) : assert(
         icon != null ||
             child != null ||
             label != null ||
             consumer != null ||
             popup != null,
       );

  const _SoftOsScaffoldAction.text({
    required this.label,
    required this.onPressed,
  }) : icon = null,
       child = null,
       consumer = null,
       popup = null,
       tooltip = null,
       raw = false;

  const _SoftOsScaffoldAction.consumer(this.consumer)
    : icon = null,
      child = null,
      label = null,
      popup = null,
      onPressed = null,
      tooltip = null,
      raw = false;

  const _SoftOsScaffoldAction.popup(this.popup)
    : icon = null,
      child = null,
      label = null,
      consumer = null,
      onPressed = null,
      tooltip = null,
      raw = false;

  final IconData? icon;
  final Widget? child;
  final String? label;
  final Consumer? consumer;
  final Widget? popup;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool raw;
}

List<Widget> genActions(
  List<Widget> actions, {
  double? space,
  double endSpace = 8,
}) {
  return <Widget>[
    ...actions.separated(SizedBox(width: space ?? 4)),
    SizedBox(width: endSpace),
  ];
}

class BaseScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;

  const BaseScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(body: body, title: title, actions: actions);
  }
}
