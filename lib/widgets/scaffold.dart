import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_bar/sl_app_bar.dart';
import 'app_bar/sl_app_bar_action.dart';
import 'app_bar/sl_app_bar_buttons.dart';
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
  final List<SlAppBarAction> appBarActions;
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
    this.appBarActions = const [],
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
  final _searchFocusNode = FocusNode(debugLabel: 'common_scaffold_search');

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isSearch) _searchFocusNode.requestFocus();
    });
  }

  Widget _buildSearchingAppBarTheme(Widget child) {
    final ThemeData theme = Theme.of(context);
    final surge = SurgeTheme.of(context);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: surge.background,
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
    _searchFocusNode.unfocus();
    _handleClearInput();
    _updateSearchState((state) => state?.copyWith(query: null));
  }

  @override
  void dispose() {
    _appBarState.dispose();
    _textController.dispose();
    _searchFocusNode.dispose();
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
    final appLocalizations = context.appLocalizations;

    Widget buildLeadingButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SlAppBarIconButton(
          icon: icon,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      );
    }

    if (_isEdit) {
      return buildLeadingButton(
        onPressed: _appBarState.value.editState?.onExit,
        icon: SurgeIcons.close,
        tooltip: appLocalizations.cancel,
      );
    }
    if (_isSearch) {
      return buildLeadingButton(
        onPressed: handleExitSearching,
        icon: SurgeIcons.back,
        tooltip: appLocalizations.exit,
      );
    }
    if (backAction != null) {
      return buildLeadingButton(
        icon: SurgeIcons.back,
        tooltip: appLocalizations.exit,
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
        icon: SurgeIcons.back,
        tooltip: appLocalizations.exit,
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
            autofocus: false,
            focusNode: _searchFocusNode,
            controller: _textController,
            style: context.typography.appBarTitle,
            onChanged: (value) {
              if (startState != null) {
                startState.onSearch(value);
              }
            },
            onTapOutside: (_) => _searchFocusNode.unfocus(),
            decoration: InputDecoration(hintText: appLocalizations.search),
          )
        : Text(
            !_isEdit
                ? widget.title!
                : appLocalizations.selectedCountTitle(
                    '${_appBarState.value.editState?.editCount ?? 0}',
                  ),
            style: context.typography.appBarTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          );
  }

  List<SlAppBarAction> _buildActions(List<SlAppBarAction> appBarActions) {
    final hasSearch = widget.searchState != null;
    final appLocalizations = context.appLocalizations;
    final searchAction = hasSearch && widget.searchState?.autoAddSearch == true
        ? SlAppBarIconAction(
            icon: SurgeIcons.search,
            tooltip: appLocalizations.search,
            onPressed: handleToSearch,
          )
        : null;
    final allActions = [
      ?searchAction,
      ...appBarActions,
    ];
    if (allActions.length > 2) {
      throw FlutterError(
        'CommonScaffold supports at most 2 app bar actions, '
        'including auto-added search. Got ${allActions.length}.',
      );
    }
    return allActions;
  }

  Widget _buildAppBarWrap(Widget child) {
    final appBar = _isSearch ? _buildSearchingAppBarTheme(child) : child;
    if (_isEdit || _isSearch) {
      return SystemBackBlock(
        child: CommonPopScope(
          onPop: (context) {
            if (_isSearch && MediaQuery.viewInsetsOf(context).bottom > 0) {
              _searchFocusNode.unfocus();
              return false;
            }
            if (_isEdit || _isSearch) {
              if (_isSearch) handleExitSearching();
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
                  final Widget actionsWidget;
                  if (_isSearch) {
                    final appLocalizations = context.appLocalizations;
                    actionsWidget = SlAppBarActionsRenderer(
                      actions: [
                        SlAppBarIconAction(
                          icon: SurgeIcons.close,
                          tooltip: appLocalizations.cancel,
                          onPressed: _handleClear,
                        ),
                      ],
                    );
                  } else {
                    final finalActions = _buildActions(
                      widget.appBarActions,
                    );
                    actionsWidget = SlAppBarActionsRenderer(
                      actions: finalActions,
                    );
                  }
                  return _buildAppBarWrap(
                    AppBar(
                      automaticallyImplyLeading: false,
                      animateColor: true,
                      centerTitle: widget.centerTitle ?? false,
                      leading: leading,
                      leadingWidth: leading != null ? 56 : null,
                      title: _buildTitle(state.searchState),
                      actions: [actionsWidget],
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
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _searchFocusNode.unfocus,
              child: widget.body,
            ),
          ),
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
