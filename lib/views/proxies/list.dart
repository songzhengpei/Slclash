import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';
import 'empty.dart';

typedef GroupNameProxiesMap = Map<String, List<Proxy>>;

const _collapsedGroupGap = 8.0;
const _expandedGroupGap = 12.0;
const _expandedTopGap = 8.0;
const _expandedProxyGap = 5.0;
const _expandedBottomGap = 8.0;
const _collapseGrace = Duration(milliseconds: 160);

enum _ProxyListItemType { header, proxy, gap }

class _ProxyListItem {
  const _ProxyListItem._({
    required this.type,
    required this.height,
    this.group,
    this.proxy,
    this.proxyIndex = 0,
    this.proxyCount = 0,
    this.cardType,
    this.isExpand = false,
    this.isExpandedSurface = false,
    this.collapsing = false,
  });

  factory _ProxyListItem.header({
    required Group group,
    required bool isExpand,
    required bool isExpandedSurface,
  }) {
    return _ProxyListItem._(
      type: _ProxyListItemType.header,
      height: listHeaderHeight,
      group: group,
      isExpand: isExpand,
      isExpandedSurface: isExpandedSurface,
    );
  }

  factory _ProxyListItem.proxy({
    required Group group,
    required Proxy proxy,
    required int proxyIndex,
    required int proxyCount,
    required ProxyCardType cardType,
    required bool collapsing,
  }) {
    final top = proxyIndex == 0 ? _expandedTopGap : 0.0;
    final bottom = proxyIndex == proxyCount - 1
        ? _expandedBottomGap
        : _expandedProxyGap;
    return _ProxyListItem._(
      type: _ProxyListItemType.proxy,
      height: top + getProxyTileHeight() + bottom,
      group: group,
      proxy: proxy,
      proxyIndex: proxyIndex,
      proxyCount: proxyCount,
      cardType: cardType,
      collapsing: collapsing,
    );
  }

  factory _ProxyListItem.gap(double height) {
    return _ProxyListItem._(type: _ProxyListItemType.gap, height: height);
  }

  final _ProxyListItemType type;
  final double height;
  final Group? group;
  final Proxy? proxy;
  final int proxyIndex;
  final int proxyCount;
  final ProxyCardType? cardType;
  final bool isExpand;
  final bool isExpandedSurface;
  final bool collapsing;
}

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends State<ProxiesListView> {
  final _controller = ScrollController();
  final _headerStateNotifier = ValueNotifier<ProxiesListHeaderSelectorState?>(
    null,
  );
  final _collapsingGroupNames = <String>{};
  List<double> _headerOffset = [];
  double containerHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_adjustHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  ProxiesListHeaderSelectorState _getProxiesListHeaderSelectorState(
    double initOffset,
  ) {
    if (_headerOffset.isEmpty) {
      return const ProxiesListHeaderSelectorState(offset: 0, currentIndex: 0);
    }
    final index = _headerOffset
        .findInterval(initOffset)
        .clamp(0, _headerOffset.length - 1);
    final currentIndex = index;
    double headerOffset = 0.0;
    if (index + 1 <= _headerOffset.length - 1) {
      final endOffset = _headerOffset[index + 1];
      final startOffset = endOffset - listHeaderHeight - 8;
      if (initOffset > startOffset && initOffset < endOffset) {
        headerOffset = initOffset - startOffset;
      }
    }
    return ProxiesListHeaderSelectorState(
      offset: max(headerOffset, 0),
      currentIndex: currentIndex,
    );
  }

  void _adjustHeader() {
    _headerStateNotifier.value = _getProxiesListHeaderSelectorState(
      !_controller.hasClients ? 0 : _controller.offset,
    );
  }

  @override
  void dispose() {
    _headerStateNotifier.dispose();
    _controller.removeListener(_adjustHeader);
    _controller.dispose();
    super.dispose();
  }

  void _handleChange(Set<String> currentUnfoldSet, String groupName) {
    final willExpand = !currentUnfoldSet.contains(groupName);
    if (willExpand) {
      _collapsingGroupNames.remove(groupName);
      _autoScrollToGroup(groupName);
    } else {
      setState(() {
        _collapsingGroupNames.add(groupName);
      });
      Future.delayed(_collapseGrace, () {
        if (!mounted) {
          return;
        }
        setState(() {
          _collapsingGroupNames.remove(groupName);
        });
        _adjustHeader();
      });
    }
    final tempUnfoldSet = Set<String>.from(currentUnfoldSet);
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
    } else {
      tempUnfoldSet.add(groupName);
    }
    updateCurrentUnfoldSet(tempUnfoldSet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustHeader();
    });
  }

  Set<String> _sanitizeUnfoldSet({
    required List<Group> groups,
    required Set<String> currentUnfoldSet,
  }) {
    final groupNames = groups.map((group) => group.name).toSet();
    final sanitized = currentUnfoldSet
        .where((groupName) => groupNames.contains(groupName))
        .toSet();
    _collapsingGroupNames.removeWhere(
      (groupName) => !groupNames.contains(groupName),
    );
    if (sanitized.length != currentUnfoldSet.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        updateCurrentUnfoldSet(sanitized);
      });
    }
    return sanitized;
  }

  List<double> _getItemHeightList(List<_ProxyListItem> items) {
    final itemHeightList = <double>[];
    final List<double> headerOffset = [];
    double currentHeight = 0;
    for (final item in items) {
      if (item.type == _ProxyListItemType.header) {
        headerOffset.add(currentHeight);
      }
      final itemHeight = item.height;
      itemHeightList.add(itemHeight);
      currentHeight = currentHeight + itemHeight;
    }
    _headerOffset = headerOffset;
    return itemHeightList;
  }

  List<_ProxyListItem> _buildItems(
    WidgetRef ref, {
    required List<Group> groups,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
  }) {
    final items = <_ProxyListItem>[];
    for (final group in groups) {
      final groupName = group.name;
      final isExpand = currentUnfoldSet.contains(groupName);
      final isCollapsing = _collapsingGroupNames.contains(groupName);
      final showExpandedBody = isExpand || isCollapsing;
      items.add(
        _ProxyListItem.header(
          group: group,
          isExpand: isExpand,
          isExpandedSurface: showExpandedBody,
        ),
      );
      if (showExpandedBody) {
        final proxies = group.all;
        final proxyItems = proxies.asMap().entries.map<_ProxyListItem>((entry) {
          final index = entry.key;
          final proxy = entry.value;
          return _ProxyListItem.proxy(
            group: group,
            proxy: proxy,
            proxyIndex: index,
            proxyCount: proxies.length,
            cardType: cardType,
            collapsing: isCollapsing,
          );
        });
        items.addAll(proxyItems);
        items.add(_ProxyListItem.gap(_expandedGroupGap));
      } else {
        items.add(_ProxyListItem.gap(_collapsedGroupGap));
      }
    }
    return items;
  }

  Widget _buildHeader(
    WidgetRef ref, {
    required Group group,
    required Set<String> currentUnfoldSet,
  }) {
    final groupName = group.name;
    final isExpand = currentUnfoldSet.contains(groupName);
    return SizedBox(
      height: listHeaderHeight,
      child: ListHeader(
        enterAnimated: false,
        onScrollToSelected: _scrollToGroupSelected,
        key: Key(groupName),
        isExpand: isExpand,
        group: group,
        onChange: (String groupName) {
          _handleChange(currentUnfoldSet, groupName);
        },
      ),
    );
  }

  double _getGroupOffset(String groupName) {
    if (!_controller.hasClients || _controller.position.maxScrollExtent == 0) {
      return 0;
    }
    final currentGroups = getCurrentGroups();
    final findIndex = currentGroups.indexWhere(
      (item) => item.name == groupName,
    );
    final index = findIndex != -1 ? findIndex : 0;
    if (index < 0 || index >= _headerOffset.length) {
      return 0;
    }
    return _headerOffset[index];
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start;
      }
    }

    targetScrollOffset = targetScrollOffset.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    _controller.jumpTo(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    if (!_controller.hasClients) {
      return;
    }
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + listHeaderHeight,
    );
  }

  void _scrollToGroupSelected(String groupName) {
    final currentInitOffset = _getGroupOffset(groupName);
    final currentGroups = getCurrentGroups();
    final proxies = currentGroups.getGroup(groupName)?.all;
    _jumpTo(
      currentInitOffset +
          listHeaderHeight +
          _expandedTopGap +
          getScrollToSelectedOffset(
            groupName: groupName,
            proxies: proxies ?? [],
            focusPadding: max(88, containerHeight * 0.42),
            itemGap: _expandedProxyGap,
          ),
    );
  }

  void _jumpTo(double offset) {
    if (mounted && _controller.hasClients) {
      _controller.animateTo(
        offset.clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  Widget _buildItem(
    _ProxyListItem item, {
    required Set<String> currentUnfoldSet,
  }) {
    return switch (item.type) {
      _ProxyListItemType.header => ListHeader(
        onScrollToSelected: _scrollToGroupSelected,
        isExpand: item.isExpand,
        embedded: item.isExpandedSurface,
        group: item.group!,
        onChange: (String groupName) {
          _handleChange(currentUnfoldSet, groupName);
        },
      ),
      _ProxyListItemType.proxy => _ExpandedProxyRow(
        isFirst: item.proxyIndex == 0,
        isLast: item.proxyIndex == item.proxyCount - 1,
        collapsing: item.collapsing,
        child: SizedBox(
          height: getProxyTileHeight(),
          child: ProxyCard(
            embedded: true,
            testUrl: item.group!.testUrl,
            type: item.cardType!,
            groupType: item.group!.type,
            key: ValueKey(
              '${item.group!.name}.${item.proxyIndex}.${item.proxy!.name}',
            ),
            proxy: item.proxy!,
            groupName: item.group!.name,
          ),
        ),
      ),
      _ProxyListItemType.gap => SizedBox(height: item.height),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Consumer(
      builder: (_, ref, _) {
        final state = ref.watch(proxiesListStateProvider);
        ref.watch(themeSettingProvider.select((state) => state.textScale));
        if (state.groups.isEmpty) {
          return ProxiesEmptyState(
            label: appLocalizations.nullTip(appLocalizations.proxies),
          );
        }
        final currentUnfoldSet = _sanitizeUnfoldSet(
          groups: state.groups,
          currentUnfoldSet: state.currentUnfoldSet,
        );
        final items = _buildItems(
          ref,
          groups: state.groups,
          currentUnfoldSet: currentUnfoldSet,
          cardType: state.proxyCardType,
        );
        final itemsOffset = _getItemHeightList(items);
        return CommonScrollBar(
          controller: _controller,
          thumbVisibility: true,
          trackVisibility: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: HiddenBarScrollBehavior(),
                  child: ListView.builder(
                    key: proxiesListStoreKey,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      112 + MediaQuery.paddingOf(context).bottom,
                    ),
                    controller: _controller,
                    itemExtentBuilder: (index, _) {
                      return itemsOffset[index];
                    },
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      return _buildItem(
                        items[index],
                        currentUnfoldSet: currentUnfoldSet,
                      );
                    },
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (_, container) {
                  containerHeight = container.maxHeight;
                  return ValueListenableBuilder(
                    valueListenable: _headerStateNotifier,
                    builder: (_, headerState, _) {
                      if (headerState == null) {
                        return const SizedBox();
                      }
                      final index =
                          headerState.currentIndex > state.groups.length - 1
                          ? 0
                          : headerState.currentIndex;
                      if (index < 0 || state.groups.isEmpty) {
                        return Container();
                      }
                      final stickyGroup = state.groups[index];
                      if (currentUnfoldSet.contains(stickyGroup.name) ||
                          _collapsingGroupNames.contains(stickyGroup.name)) {
                        return const SizedBox();
                      }
                      return Stack(
                        children: [
                          Positioned(
                            top: -headerState.offset,
                            child: Container(
                              width: container.maxWidth,
                              color: SurgeTheme.of(context).background,
                              padding: const EdgeInsets.only(
                                top: 16,
                                left: 16,
                                right: 16,
                                bottom: 8,
                              ),
                              child: _buildHeader(
                                ref,
                                group: stickyGroup,
                                currentUnfoldSet: currentUnfoldSet,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpandedProxyRow extends StatelessWidget {
  const _ExpandedProxyRow({
    required this.child,
    required this.isFirst,
    required this.isLast,
    required this.collapsing,
  });

  final Widget child;
  final bool isFirst;
  final bool isLast;
  final bool collapsing;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = surge.radii.card;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: collapsing ? 1 : 0, end: collapsing ? 0 : 1),
      duration: SurgeMotion.reveal,
      curve: SurgeMotion.stateCurve,
      builder: (_, value, child) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(isLast ? radius : 0),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: surge.card),
            child: Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * -3),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    10,
                    isFirst ? _expandedTopGap : 0,
                    10,
                    isLast ? _expandedBottomGap : _expandedProxyGap,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _HeaderSurface extends StatelessWidget {
  const _HeaderSurface({
    super.key,
    required this.child,
    required this.embedded,
    required this.onTap,
  });

  final Widget child;
  final bool embedded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    if (!embedded) {
      return SurgeCard(
        key: key,
        padding: EdgeInsets.zero,
        shadow: false,
        borderRadius: surge.radii.card,
        onTap: onTap,
        child: child,
      );
    }
    final radius = surge.radii.card;
    return Material(
      key: key,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      child: Ink(
        decoration: BoxDecoration(
          color: surge.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        ),
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class ListHeader extends StatefulWidget {
  final Group group;

  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;

  final bool enterAnimated;
  final bool embedded;

  const ListHeader({
    super.key,
    this.enterAnimated = true,
    this.embedded = false,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
  });

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  var isLock = false;

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  String get groupType => widget.group.type.name;

  bool get isExpand => widget.isExpand;

  Future<void> _delayTest() async {
    if (isLock) return;
    isLock = true;
    await delayTest(widget.group.all, widget.group.testUrl);
    isLock = false;
  }

  void _handleChange(String groupName) {
    widget.onChange(groupName);
  }

  String _resolveSelectedLabel({
    required List<Group> groups,
    required Map<String, String> selectedMap,
    required String proxyName,
    int depth = 0,
  }) {
    if (proxyName.isEmpty || depth > 4) {
      return proxyName;
    }
    final group = groups.getGroup(proxyName);
    if (group == null) {
      return proxyName;
    }
    final nextName = group.getCurrentSelectedName(selectedMap[proxyName] ?? '');
    if (nextName.isEmpty || nextName == proxyName) {
      return proxyName;
    }
    final leafName = _resolveSelectedLabel(
      groups: groups,
      selectedMap: selectedMap,
      proxyName: nextName,
      depth: depth + 1,
    );
    return '$proxyName: $leafName';
  }

  Widget _buildIcon() {
    return Consumer(
      builder: (_, ref, child) {
        final surge = SurgeTheme.of(context);
        final iconStyle = ref.watch(
          proxiesStyleSettingProvider.select((state) => state.iconStyle),
        );
        return switch (iconStyle) {
          ProxiesIconStyle.standard => LayoutBuilder(
            builder: (_, constraints) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(5.ap),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: surge.textSecondary.withValues(alpha: 0.08),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IconTheme.merge(
                      data: IconThemeData(size: constraints.maxHeight - 12.ap),
                      child: CommonTargetIcon(src: icon),
                    ),
                  ),
                ),
              );
            },
          ),
          ProxiesIconStyle.icon => Container(
            margin: const EdgeInsets.only(right: 12),
            child: LayoutBuilder(
              builder: (_, constraints) {
                return IconTheme.merge(
                  data: IconThemeData(size: constraints.maxHeight - 8.ap),
                  child: CommonTargetIcon(src: icon),
                );
              },
            ),
          ),
          ProxiesIconStyle.none => Container(),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                _buildIcon(),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmojiText(
                        groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: surge.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        flex: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              groupType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: surge.textSecondary,
                                fontSize: 12,
                                letterSpacing: 0,
                              ),
                            ),
                            Flexible(
                              flex: 1,
                              child: Consumer(
                                builder: (_, ref, _) {
                                  final proxyName = ref
                                      .watch(
                                        selectedProxyNameProvider(groupName),
                                      )
                                      .takeFirstValid([]);
                                  final selectedMap = ref.watch(
                                    currentProfileProvider.select(
                                      (state) => state?.selectedMap ?? {},
                                    ),
                                  );
                                  final selectedLabel = _resolveSelectedLabel(
                                    groups: getGroups(),
                                    selectedMap: selectedMap,
                                    proxyName: proxyName,
                                  );
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (selectedLabel.isNotEmpty) ...[
                                        Flexible(
                                          flex: 1,
                                          child: EmojiText(
                                            '  $selectedLabel',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: surge.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (isExpand) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(1),
                  onPressed: () {
                    widget.onScrollToSelected(groupName);
                  },
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: WidgetStatePropertyAll(
                      surge.textSecondary,
                    ),
                  ),
                  iconSize: 18,
                  icon: const Icon(Icons.adjust),
                ),
                IconButton(
                  iconSize: 19,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(1),
                  onPressed: _delayTest,
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: WidgetStatePropertyAll(
                      surge.textSecondary,
                    ),
                  ),
                  icon: const Icon(Icons.network_ping_rounded),
                ),
                const SizedBox(width: 4),
              ] else
                const SizedBox(width: 4),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(1),
                iconSize: 22,
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: WidgetStatePropertyAll(
                    surge.textSecondary.withValues(alpha: 0.12),
                  ),
                  foregroundColor: WidgetStatePropertyAll(surge.textPrimary),
                ),
                onPressed: () {
                  _handleChange(groupName);
                },
                icon: CommonExpandIcon(expand: isExpand),
              ),
            ],
          ),
        ],
      ),
    );
    final card = _HeaderSurface(
      key: widget.key,
      embedded: widget.embedded,
      onTap: () {
        _handleChange(groupName);
      },
      child: content,
    );
    return widget.enterAnimated ? FadeScaleEnterBox(child: card) : card;
  }
}
