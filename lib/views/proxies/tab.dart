import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';
import 'empty.dart';

typedef ProxyGroupViewKeyMap =
    Map<String, GlobalObjectKey<_ProxyGroupViewState>>;

class ProxiesTabView extends ConsumerStatefulWidget {
  const ProxiesTabView({super.key});

  static Map<String, PageStorageKey> pageListStoreMap = {};

  @override
  ConsumerState<ProxiesTabView> createState() => ProxiesTabViewState();
}

class ProxiesTabViewState extends ConsumerState<ProxiesTabView>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _hasMoreButtonNotifier = ValueNotifier<bool>(false);
  ProxyGroupViewKeyMap _keyMap = {};

  @override
  void initState() {
    super.initState();
    ref.listenManual(proxiesTabControllerStateProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      if (!stringListEquality.equals(prev?.a, next.a)) {
        _destroyTabController();
        final groupNames = next.a;
        final currentGroupName = next.b;
        final index = groupNames.indexWhere((item) => item == currentGroupName);
        _updateTabController(groupNames.length, index);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _destroyTabController();
    super.dispose();
  }

  void scrollToGroupSelected() {
    final currentGroupName = getCurrentGroupName();
    _keyMap[currentGroupName]?.currentState?.scrollToSelected();
  }

  Future<void> delayTestCurrentGroup() async {
    final currentGroupName = getCurrentGroupName();
    final currentState = _keyMap[currentGroupName]?.currentState;
    await delayTest(currentState?.currentProxies ?? [], currentState?.testUrl);
  }

  Widget _buildMoreButton() {
    return Consumer(
      builder: (_, ref, _) {
        final isMobileView = ref.watch(isMobileViewProvider);
        return IconButton(
          onPressed: _showMoreMenu,
          icon: isMobileView
              ? const Icon(Icons.expand_more)
              : const Icon(Icons.chevron_right),
        );
      },
    );
  }

  void _showMoreMenu() {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: false),
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (_, ref, _) {
                final state = ref.watch(proxiesTabControllerStateProvider);
                final groupNames = state.a;
                final currentGroupName = state.b;
                return SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      for (final groupName in groupNames)
                        SettingTextCard(
                          groupName,
                          onPressed: () {
                            final index = groupNames.indexWhere(
                              (item) => item == groupName,
                            );
                            if (index == -1) return;
                            _tabController?.animateTo(index);
                            updateCurrentGroupName(groupName);
                            Navigator.of(context).pop();
                          },
                          isSelected: groupName == currentGroupName,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          title: context.appLocalizations.proxyGroup,
        );
      },
    );
  }

  void _tabControllerListener([int? index]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      int? groupIndex = index;
      if (groupIndex == -1) {
        return;
      }
      if (groupIndex == null) {
        final currentIndex = _tabController?.index;
        groupIndex = currentIndex;
      }
      final currentGroups = getCurrentGroups();
      if (groupIndex == null || groupIndex > currentGroups.length) {
        return;
      }
      final currentGroup = currentGroups[groupIndex];
      updateCurrentGroupName(currentGroup.name);
    });
  }

  void _destroyTabController() {
    _tabController?.removeListener(_tabControllerListener);
    _tabController?.dispose();
    _tabController = null;
  }

  void _updateTabController(int length, int index) {
    _destroyTabController();
    if (length == 0) {
      return;
    }
    final realIndex = index == -1 ? 0 : index;
    _tabController ??= TabController(
      length: length,
      initialIndex: realIndex,
      vsync: this,
    );
    _tabControllerListener(realIndex);
    _tabController?.addListener(_tabControllerListener);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    ref.watch(themeSettingProvider.select((state) => state.textScale));
    final state = ref.watch(proxiesTabStateProvider.select((state) => state));
    final groups = state.groups;
    if (groups.isEmpty || _tabController == null) {
      return ProxiesEmptyState(
        label: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }
    _keyMap = {};
    return ColoredBox(
      color: surge.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (scrollNotification) {
              _hasMoreButtonNotifier.value =
                  scrollNotification.metrics.maxScrollExtent > 0;
              return false;
            },
            child: ValueListenableBuilder(
              valueListenable: _hasMoreButtonNotifier,
              builder: (_, value, child) {
                return Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [
                    TabBar(
                      controller: _tabController,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16 + (value ? 16 : 0),
                        top: 8,
                        bottom: 8,
                      ),
                      dividerColor: Colors.transparent,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: surge.primary,
                      unselectedLabelColor: surge.textSecondary,
                      indicator: BoxDecoration(
                        color: surge.card,
                        borderRadius: BorderRadius.circular(surge.radii.button),
                        border: Border.all(color: surge.separator, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: surge.shadow.withValues(alpha: 0.55),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                      overlayColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      tabs: [
                        for (final group in groups)
                          Tab(
                            child: Builder(
                              builder: (context) {
                                return EmojiText(
                                  group.name,
                                  style: DefaultTextStyle.of(context).style,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    if (value) Positioned(right: 0, child: child!),
                  ],
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      surge.background.withValues(alpha: 0.1),
                      surge.background,
                    ],
                    stops: const [0.0, 0.1],
                  ),
                ),
                child: _buildMoreButton(),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final group in groups)
                  ProxyGroupView(
                    key: _keyMap.updateCacheValue(
                      group.name,
                      () => GlobalObjectKey<_ProxyGroupViewState>(group.name),
                    ),
                    group: group,
                    cardType: state.proxyCardType,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProxyGroupView extends ConsumerStatefulWidget {
  final Group group;
  final ProxyCardType cardType;

  const ProxyGroupView({
    super.key,
    required this.group,
    required this.cardType,
  });

  @override
  ConsumerState<ProxyGroupView> createState() => _ProxyGroupViewState();
}

class _ProxyGroupViewState extends ConsumerState<ProxyGroupView> {
  late final ScrollController _controller;

  List<Proxy> currentProxies = [];
  String? testUrl;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  PageStorageKey _getPageStorageKey() {
    final profile = globalState.container.read(currentProfileProvider);
    final key =
        '${profile?.id}_${ScrollPositionCacheKey.proxiesTabList.name}_${widget.group.name}';
    return ProxiesTabView.pageListStoreMap.updateCacheValue(
      key,
      () => PageStorageKey(key),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void scrollToSelected() {
    if (_controller.position.maxScrollExtent == 0) {
      return;
    }
    _controller.animateTo(
      min(
        16 +
            getScrollToSelectedOffset(
              groupName: widget.group.name,
              proxies: currentProxies,
            ),
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final proxies = group.all;
    testUrl = group.testUrl;
    currentProxies = proxies;
    return Consumer(
      builder: (_, ref, _) {
        final selectedProxyName = ref
            .watch(selectedProxyNameProvider(group.name))
            .takeFirstValid([]);
        return CommonScrollBar(
          controller: _controller,
          child: CustomScrollView(
            key: _getPageStorageKey(),
            controller: _controller,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _PolicyGroupSummary(
                    group: group,
                    selectedProxyName: selectedProxyName,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  112 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.builder(
                  itemCount: currentProxies.length,
                  itemBuilder: (_, index) {
                    final proxy = currentProxies[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == currentProxies.length - 1 ? 0 : 6,
                      ),
                      child: SizedBox(
                        height: getProxyTileHeight(),
                        child: ProxyCard(
                          testUrl: group.testUrl,
                          groupType: group.type,
                          type: widget.cardType,
                          proxy: proxy,
                          groupName: group.name,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PolicyGroupSummary extends StatelessWidget {
  const _PolicyGroupSummary({
    required this.group,
    required this.selectedProxyName,
  });

  final Group group;
  final String selectedProxyName;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shadow: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiText(
                  group.name,
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
                EmojiText(
                  selectedProxyName.isEmpty
                      ? group.type.name
                      : 'Current: $selectedProxyName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: selectedProxyName.isEmpty
                        ? surge.textSecondary
                        : surge.primary,
                    fontSize: 12,
                    fontWeight: selectedProxyName.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: surge.primary, size: 20),
        ],
      ),
    );
  }
}

class DelayTestButton extends StatefulWidget {
  final Future Function() onClick;

  const DelayTestButton({super.key, required this.onClick});

  @override
  State<DelayTestButton> createState() => _DelayTestButtonState();
}

class _DelayTestButtonState extends State<DelayTestButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Future<void> _healthcheck() async {
    if (_controller.isAnimating) {
      return;
    }
    _controller.forward();
    await widget.onClick();
    if (mounted) {
      _controller.reverse();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    return AnimatedBuilder(
      animation: _controller.view,
      builder: (_, child) {
        return FadeTransition(
          opacity: _animation,
          child: ScaleTransition(scale: _animation, child: child),
        );
      },
      child: FloatingActionButton.extended(
        onPressed: _healthcheck,
        backgroundColor: surge.primary,
        foregroundColor: surge.onPrimary,
        elevation: 2,
        label: Text(appLocalizations.delayTest),
        icon: const Icon(Icons.network_ping_rounded),
      ),
    );
  }
}
