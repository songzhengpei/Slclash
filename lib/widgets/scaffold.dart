import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'chip.dart';
import 'inherited.dart';

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
    if (_isEdit) {
      return IconButton(
        onPressed: _appBarState.value.editState?.onExit,
        icon: const Icon(Icons.close),
      );
    }
    if (_isSearch) {
      return IconButton(
        onPressed: handleExitSearching,
        icon: const Icon(Icons.arrow_back),
      );
    }
    return backAction != null
        ? BackButton(
            onPressed: () {
              if (!mounted) {
                return;
              }
              backAction();
            },
          )
        : null;
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
    return switch (icon) {
      Icons.close => Icons.close_rounded,
      Icons.arrow_back => Icons.arrow_back_rounded,
      Icons.search => Icons.search_rounded,
      Icons.check => Icons.check_rounded,
      Icons.add => Icons.add_rounded,
      Icons.save_as_outlined => Icons.save_as_rounded,
      Icons.delete_sweep_outlined => Icons.delete_sweep_rounded,
      Icons.filter_alt_outlined => Icons.tune_rounded,
      Icons.settings_outlined => Icons.tune_rounded,
      _ => icon,
    };
  }

  IconData? _resolveIconData(Widget icon) {
    if (icon is Icon && icon.icon != null) {
      return _normalizeActionIcon(icon.icon!);
    }
    return null;
  }

  _SoftOsScaffoldAction? _resolveAction(Widget action) {
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

  Widget _buildSoftOsActions(List<_SoftOsScaffoldAction> actions) {
    if (actions.length == 1) {
      final action = actions.first;
      if (action.raw) {
        return SizedBox.square(
          dimension: 48,
          child: Center(child: action.child),
        );
      }
      return SoftOsActionButton(
        icon: action.icon,
        onPressed: action.onPressed,
        tooltip: action.tooltip,
        child: action.child,
      );
    }

    final children = <Widget>[];
    for (var index = 0; index < actions.length; index++) {
      final action = actions[index];
      if (index > 0) {
        children.add(const SoftOsActionDivider());
      }
      if (action.raw) {
        children.add(
          SizedBox.square(dimension: 48, child: Center(child: action.child)),
        );
      } else {
        children.add(
          SoftOsActionDockButton(
            icon: action.icon,
            onPressed: action.onPressed,
            tooltip: action.tooltip,
            child: action.child,
          ),
        );
      }
    }

    return SoftOsActionDock(children: children);
  }

  List<Widget> _buildActions(bool hasSearch, List<Widget> actions) {
    if (_isSearch) {
      return genActions([
        SoftOsActionButton(icon: Icons.close_rounded, onPressed: _handleClear),
      ]);
    }
    final resolvedActions = [
      if (hasSearch && widget.searchState?.autoAddSearch == true)
        _SoftOsScaffoldAction(
          icon: Icons.search_rounded,
          onPressed: () {
            _updateSearchState((state) => state?.copyWith(query: ''));
          },
        ),
      ...actions.map(_resolveAction).nonNulls,
    ];
    if (resolvedActions.isEmpty) {
      return const [];
    }
    return genActions([_buildSoftOsActions(resolvedActions)]);
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
                  return _buildAppBarWrap(
                    AppBar(
                      automaticallyImplyLeading: backAction != null
                          ? false
                          : true,
                      animateColor: true,
                      centerTitle: widget.centerTitle ?? false,
                      leading: _buildLeading(backAction),
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
    required this.onPressed,
    this.tooltip,
    this.raw = false,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool raw;
}

List<Widget> genActions(List<Widget> actions, {double? space}) {
  return <Widget>[
    ...actions.separated(SizedBox(width: space ?? 4)),
    const SizedBox(width: 8),
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
