import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView> {
  static const _pageLabel = PageLabel.connections;
  static const _refreshInterval = Duration(seconds: 1);

  final _connectionsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );
  final ScrollController _scrollController = ScrollController();

  Timer? _timer;
  bool _isUpdating = false;

  List<Widget> _buildActions() {
    return [
      IconButton(
        onPressed: () async {
          coreController.closeConnections();
          await _updateConnections(force: true);
        },
        icon: const Icon(Icons.delete_sweep_outlined),
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
    return ref.read(appForegroundProvider) &&
        ref.read(currentPageLabelProvider) == _pageLabel;
  }

  void _syncRefreshTimer() {
    if (!_shouldRefresh) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
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
    final trackerInfos = await coreController.getConnections();
    _isUpdating = false;
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
      actions: _buildActions(),
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
          return SuperListView.builder(
            controller: _scrollController,
            itemBuilder: (context, index) {
              final trackerInfo = connections[index];
              return TrackerInfoItem(
                key: Key(trackerInfo.id),
                trackerInfo: trackerInfo,
                onClickKeyword: (value) {
                  context.commonScaffoldState?.addKeyword(value);
                },
                trailing: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(minimumSize: Size.zero),
                  icon: const Icon(Icons.block),
                  onPressed: () {
                    _handleBlockConnection(trackerInfo.id);
                  },
                ),
                detailTitle: appLocalizations.details(
                  appLocalizations.connection,
                ),
              );
            },
            itemCount: connections.length,
          );
        },
      ),
    );
  }
}
