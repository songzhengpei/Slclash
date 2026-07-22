import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'item.dart';

@visibleForTesting
bool shouldRefreshConnectionsView({
  required bool appForeground,
  required bool isStart,
  required bool isSuspended,
  required PageLabel currentPageLabel,
  required bool isMobileView,
}) {
  return appForeground &&
      isStart &&
      !isSuspended &&
      (currentPageLabel == PageLabel.connections ||
          (isMobileView && currentPageLabel == PageLabel.tools));
}

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView> {
  static const _refreshInterval = Duration(seconds: 1);
  static const _surfaceBottomPadding = 8.0;

  final _connectionsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );
  final ScrollController _scrollController = ScrollController();

  Timer? _timer;
  bool _isUpdating = false;

  List<SlAppBarAction> _buildActions() {
    return [
      SlAppBarOverflowAction(
        tooltip: context.appLocalizations.more,
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              icon: SurgeIcons.deleteAll,
              label: context.appLocalizations.delete,
              onPressed: () async {
                coreController.closeConnections();
                await _updateConnections(force: true);
              },
            ),
          ],
        ),
      ),
    ];
  }

  void _onSearch(String value) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  bool get _shouldRefresh {
    return shouldRefreshConnectionsView(
      appForeground: ref.read(appForegroundProvider),
      isStart: ref.read(isStartProvider),
      isSuspended: ref.read(suspendProvider),
      currentPageLabel: ref.read(currentPageLabelProvider),
      isMobileView: ref.read(isMobileViewProvider),
    );
  }

  Future<void> _ensureRuntimeListener() async {
    if (!ref.read(isStartProvider) || ref.read(suspendProvider)) {
      return;
    }
    try {
      await coreController.startListener();
    } catch (e) {
      commonPrint.log(
        'start listener for connections failed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }

  void _syncRefreshTimer() {
    if (!_shouldRefresh) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    unawaited(_ensureRuntimeListener());
    unawaited(_updateConnections());
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (!_shouldRefresh) {
        _syncRefreshTimer();
        return;
      }
      unawaited(_updateConnections());
    });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(appForegroundProvider, (prev, next) {
      if (prev != next) {
        _syncRefreshTimer();
      }
    });
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _syncRefreshTimer();
      }
    });
    ref.listenManual(isStartProvider, (prev, next) {
      if (prev != next) {
        _syncRefreshTimer();
      }
    });
    ref.listenManual(isMobileViewProvider, (prev, next) {
      if (prev != next) {
        _syncRefreshTimer();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      if (prev != next) {
        _syncRefreshTimer();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncRefreshTimer();
      }
    });
  }

  Future<void> _updateConnections({bool force = false}) async {
    if (_isUpdating) return;
    if (!force && !_shouldRefresh) return;
    _isUpdating = true;
    final List<TrackerInfo> trackerInfos;
    try {
      trackerInfos = await coreController.getConnections();
    } catch (e) {
      commonPrint.log(
        'update connections failed: $e',
        logLevel: LogLevel.warning,
      );
      return;
    } finally {
      _isUpdating = false;
    }
    if (!mounted) return;
    if (!force && !_shouldRefresh) return;
    _connectionsStateNotifier.value = _connectionsStateNotifier.value.copyWith(
      trackerInfos: trackerInfos,
    );
  }

  Future<void> _handleBlockConnection(String id) async {
    await coreController.closeConnection(id);
    await _updateConnections(force: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectionsStateNotifier.dispose();
    _scrollController.dispose();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.connections,
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      appBarActions: _buildActions(),
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _connectionsStateNotifier,
        builder: (context, state, _) {
          final connections = state.list;
          if (connections.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
              illustration: const ConnectionEmptyIllustration(),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: _surfaceBottomPadding,
            ),
            child: SoftOsListSurface(
              child: SuperListView.builder(
                controller: _scrollController,
                itemBuilder: (context, index) {
                  final trackerInfo = connections[index];
                  return TrackerInfoItem(
                    key: Key(trackerInfo.id),
                    trackerInfo: trackerInfo,
                    showDivider: index != connections.length - 1,
                    onClickKeyword: (value) {
                      context.commonScaffoldState?.addKeyword(value);
                    },
                    trailing: SoftOsIconButton(
                      icon: SurgeIcons.block,
                      onPressed: () {
                        _handleBlockConnection(trackerInfo.id);
                      },
                      visualSize: 30,
                      tapSize: 44,
                      iconSize: 15,
                    ),
                    detailTitle: appLocalizations.details(
                      appLocalizations.connection,
                    ),
                  );
                },
                itemCount: connections.length,
              ),
            ),
          );
        },
      ),
    );
  }
}
