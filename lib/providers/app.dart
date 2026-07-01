import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/app.g.dart';

@riverpod
class RealTunEnable extends _$RealTunEnable with AutoDisposeNotifierMixin {
  @override
  bool build() {
    return false;
  }
}

@Riverpod(keepAlive: true)
class Logs extends _$Logs with AutoDisposeNotifierMixin {
  static const _batchInterval = Duration(seconds: 1);
  static const _maxBatchSize = 100;

  final List<Log> _pendingLogs = [];
  Timer? _flushTimer;
  int _droppedLogs = 0;

  @override
  FixedList<Log> build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      _flushTimer = null;
      _pendingLogs.clear();
    });
    return FixedList(0);
  }

  void add(Log value) {
    addAll([value]);
  }

  void addAll(Iterable<Log> values) {
    if (!ref.mounted) {
      return;
    }
    for (final value in values) {
      if (_pendingLogs.length >= _maxBatchSize) {
        _droppedLogs++;
        continue;
      }
      _pendingLogs.add(value);
    }
    if (_pendingLogs.isNotEmpty) {
      _flushTimer ??= Timer(_batchInterval, _flushLogs);
    }
  }

  void _flushLogs() {
    _flushTimer = null;
    if (_pendingLogs.isEmpty || !ref.mounted) {
      return;
    }
    final batch = List<Log>.of(_pendingLogs);
    _pendingLogs.clear();
    value = state.copyWith()..addAll(batch);
  }

  int get droppedLogs => _droppedLogs;

  Future<bool> exportLogs() async {
    _flushTimer?.cancel();
    _flushLogs();
    final logString = await encodeLogsTask(value.list);
    final tempFilePath = await appPath.tempFilePath;
    final file = File(tempFilePath);
    await file.safeWriteAsString(logString);
    bool res = false;
    res = await picker.saveFileWithPath(utils.logFile, tempFilePath) != null;
    return res;
  }
}

@Riverpod(keepAlive: true)
class Requests extends _$Requests with AutoDisposeNotifierMixin {
  static const _batchInterval = Duration(seconds: 1);
  static const _maxBatchSize = 50;

  final List<TrackerInfo> _pendingRequests = [];
  Timer? _flushTimer;
  int _droppedRequests = 0;

  @override
  FixedList<TrackerInfo> build() {
    ref.onDispose(() {
      _flushTimer?.cancel();
      _flushTimer = null;
      _pendingRequests.clear();
    });
    return FixedList(0);
  }

  void addRequest(TrackerInfo value) {
    addRequests([value]);
  }

  void addRequests(Iterable<TrackerInfo> values) {
    if (!ref.mounted) {
      return;
    }
    for (final value in values) {
      if (_pendingRequests.length >= _maxBatchSize) {
        _droppedRequests++;
        continue;
      }
      _pendingRequests.add(value);
    }
    if (_pendingRequests.isNotEmpty) {
      _flushTimer ??= Timer(_batchInterval, _flushRequests);
    }
  }

  void _flushRequests() {
    _flushTimer = null;
    if (_pendingRequests.isEmpty || !ref.mounted) {
      return;
    }
    final batch = List<TrackerInfo>.of(_pendingRequests);
    _pendingRequests.clear();
    value = state.copyWith()..addAll(batch);
  }

  int get droppedRequests => _droppedRequests;
}

@Riverpod(keepAlive: true)
class Providers extends _$Providers with AutoDisposeNotifierMixin {
  @override
  List<ExternalProvider> build() {
    return [];
  }

  void setProvider(ExternalProvider? provider) {
    if (provider == null) return;
    final index = value.indexWhere((item) => item.name == provider.name);
    if (index == -1) return;
    final newState = List<ExternalProvider>.from(value)..[index] = provider;
    value = newState;
  }

  Future<void> syncProviders() async {
    value = await coreController.getExternalProviders();
  }
}

@Riverpod(keepAlive: true)
class Packages extends _$Packages with AutoDisposeNotifierMixin {
  @override
  List<Package> build() {
    return [];
  }
}

@Riverpod(keepAlive: true)
class SystemBrightness extends _$SystemBrightness
    with AutoDisposeNotifierMixin {
  @override
  Brightness build() {
    return Brightness.dark;
  }
}

@Riverpod(keepAlive: true)
class Traffics extends _$Traffics with AutoDisposeNotifierMixin {
  @override
  FixedList<Traffic> build() {
    return FixedList(0);
  }

  void addTraffic(Traffic value) {
    this.value = state.copyWith()..add(value);
  }

  void clear() {
    value = FixedList(state.maxLength);
  }
}

@Riverpod(keepAlive: true)
class TotalTraffic extends _$TotalTraffic with AutoDisposeNotifierMixin {
  @override
  Traffic build() {
    return const Traffic();
  }
}

@Riverpod(keepAlive: true)
class LocalIp extends _$LocalIp with AutoDisposeNotifierMixin {
  @override
  String? build() {
    return null;
  }
}

@Riverpod(keepAlive: true)
class RunTime extends _$RunTime with AutoDisposeNotifierMixin {
  @override
  int? build() {
    return null;
  }
}

@Riverpod(keepAlive: true)
class ViewSize extends _$ViewSize with AutoDisposeNotifierMixin {
  @override
  Size build() {
    return Size.zero;
  }
}

@Riverpod(keepAlive: true)
class SideWidth extends _$SideWidth with AutoDisposeNotifierMixin {
  @override
  double build() {
    return 0;
  }
}

@Riverpod(keepAlive: true)
double viewWidth(Ref ref) {
  return ref.watch(viewSizeProvider).width;
}

@Riverpod(keepAlive: true)
ViewMode viewMode(Ref ref) {
  return utils.getViewMode(ref.watch(viewWidthProvider));
}

@Riverpod(keepAlive: true)
bool isMobileView(Ref ref) {
  return ref.watch(viewModeProvider) == ViewMode.mobile;
}

@Riverpod(keepAlive: true)
class Init extends _$Init with AutoDisposeNotifierMixin {
  @override
  bool build() {
    return false;
  }
}

@Riverpod(keepAlive: true)
class CurrentPageLabel extends _$CurrentPageLabel
    with AutoDisposeNotifierMixin {
  @override
  PageLabel build() {
    return PageLabel.dashboard;
  }

  void toPage(PageLabel pageLabel) {
    value = pageLabel;
  }

  void toProfiles() {
    toPage(PageLabel.profiles);
  }
}

@Riverpod(keepAlive: true)
class SortNum extends _$SortNum with AutoDisposeNotifierMixin {
  @override
  int build() {
    return 0;
  }

  int add() => state++;
}

@Riverpod(keepAlive: true)
class CheckIpNum extends _$CheckIpNum with AutoDisposeNotifierMixin {
  @override
  int build() {
    return 0;
  }

  int add() => state++;
}

@Riverpod(keepAlive: true)
class BackBlock extends _$BackBlock with AutoDisposeNotifierMixin {
  @override
  bool build() {
    return false;
  }

  void backBlock() {
    value = true;
  }

  void unBackBlock() {
    value = false;
  }
}

@Riverpod(keepAlive: true)
class Version extends _$Version with AutoDisposeNotifierMixin {
  @override
  int build() {
    return 0;
  }
}

@Riverpod(keepAlive: true)
class Groups extends _$Groups with AutoDisposeNotifierMixin {
  @override
  List<Group> build() {
    return [];
  }
}

@Riverpod(keepAlive: true)
class DelayDataSource extends _$DelayDataSource with AutoDisposeNotifierMixin {
  @override
  DelayMap build() {
    return {};
  }

  void setDelay(Delay delay) {
    if (state[delay.url]?[delay.name] != delay.value) {
      final DelayMap newDelayMap = Map.from(state);
      if (newDelayMap[delay.url] == null) {
        newDelayMap[delay.url] = {};
      }
      newDelayMap[delay.url]![delay.name] = delay.value;
      value = newDelayMap;
    }
  }
}

@Riverpod(keepAlive: true)
class SystemUiOverlayStyleState extends _$SystemUiOverlayStyleState
    with AutoDisposeNotifierMixin {
  @override
  SystemUiOverlayStyle build() {
    return const SystemUiOverlayStyle();
  }
}

@Riverpod(name: 'coreStatusProvider', keepAlive: true)
class _CoreStatus extends _$CoreStatus with AutoDisposeNotifierMixin {
  @override
  CoreStatus build() {
    return CoreStatus.disconnected;
  }
}

/// Tracks whether the app is in the foreground (resumed).
@Riverpod(keepAlive: true)
class AppForeground extends _$AppForeground with AutoDisposeNotifierMixin {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// Tracks the last time the user interacted with the app (touch/mouse).
@Riverpod(keepAlive: true)
class LastUserInteractionAt extends _$LastUserInteractionAt
    with AutoDisposeNotifierMixin {
  @override
  DateTime? build() => null;

  void touch() => state = DateTime.now();
}

/// Whether UI auto-refresh tasks should be active.
/// Derived: foreground is the primary gate.
@Riverpod(keepAlive: true)
class UiAutoRefreshEnabled extends _$UiAutoRefreshEnabled
    with AutoDisposeNotifierMixin {
  @override
  bool build() {
    final isForeground = ref.watch(appForegroundProvider);
    return isForeground;
  }
}

/// Tracks the profile ID selected in the media check page for
/// background health observation. Persisted to preferences so the
/// scheduler can continue observing even after the page is closed.
@Riverpod(keepAlive: true)
class MediaCheckSelectedProfileId extends _$MediaCheckSelectedProfileId
    with AutoDisposeNotifierMixin {
  static const _key = 'media-check-selected-profile-id';

  @override
  int? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final id = await preferences.getInt(_key);
    if (id != null) state = id;
  }

  Future<void> select(int profileId) async {
    state = profileId;
    await preferences.setInt(_key, profileId);
  }
}

@riverpod
class Query extends _$Query with AutoDisposeNotifierMixin {
  @override
  String build(QueryTag tag) {
    return '';
  }
}

@Riverpod(keepAlive: true)
class Loading extends _$Loading with AutoDisposeNotifierMixin {
  DateTime? _start;
  Timer? _timer;

  @override
  bool build(LoadingTag tag) {
    return false;
  }

  void start() {
    _timer?.cancel();
    _timer = null;
    _start = DateTime.now();
    value = true;
  }

  Future<void> stop() async {
    if (_start == null) {
      value = false;
      return;
    }
    final startedAt = _start!;
    final elapsed = DateTime.now().difference(_start!).inMilliseconds;
    const minDuration = 1000;
    if (elapsed >= minDuration) {
      value = false;
      return;
    }
    _timer = Timer(Duration(milliseconds: minDuration - elapsed), () {
      if (_start != startedAt) {
        return;
      }
      value = false;
    });
  }
}

@riverpod
class Items extends _$Items with AutoDisposeNotifierMixin {
  @override
  Set<dynamic> build(String key) {
    return {};
  }
}

@riverpod
class Item extends _$Item with AutoDisposeNotifierMixin {
  @override
  dynamic build(String key) {
    return null;
  }
}

@riverpod
class IsUpdating extends _$IsUpdating with AutoDisposeNotifierMixin {
  @override
  bool build(String name) {
    return false;
  }
}

@Riverpod(keepAlive: true)
class NetworkDetection extends _$NetworkDetection
    with AutoDisposeNotifierMixin {
  static const _timeoutDisplayDelay = Duration(seconds: 2);

  bool? _preIsStart;
  CancelToken? _cancelToken;
  Timer? _timeoutTimer;
  int _checkVersion = 0;

  @override
  NetworkDetectionState build() {
    ref.onDispose(() {
      _resetCheckSession(null);
    });
    return const NetworkDetectionState(isLoading: true, ipInfo: null);
  }

  void startCheck() {
    debouncer.call(FunctionTag.checkIp, () {
      _checkIp();
    }, duration: commonDuration);
  }

  Future<void> _checkIp() async {
    final isInit = ref.read(initProvider);
    if (!isInit) {
      return;
    }
    final isStart = ref.read(isStartProvider);
    if (!isStart && _preIsStart == false && state.ipInfo != null) {
      return;
    }
    final cancelToken = CancelToken();
    final version = _resetCheckSession(cancelToken);
    commonPrint.log('checkIp start');
    state = state.copyWith(isLoading: true, ipInfo: null);
    _preIsStart = isStart;
    final res = await request.checkIp(cancelToken: cancelToken);
    commonPrint.log('checkIp res: $res');

    if (!ref.mounted ||
        version != _checkVersion ||
        cancelToken != _cancelToken) {
      return;
    }
    final ipInfo = res.data;
    if (ipInfo == null) {
      _delayTimeoutDisplay(version);
      return;
    }
    state = state.copyWith(isLoading: false, ipInfo: ipInfo);
  }

  int _resetCheckSession(CancelToken? cancelToken) {
    _cancelTimeoutTimer();
    final version = ++_checkVersion;
    final previousCancelToken = _cancelToken;
    _cancelToken = cancelToken;
    previousCancelToken?.cancel();
    return version;
  }

  void _delayTimeoutDisplay(int version) {
    _cancelTimeoutTimer();
    _timeoutTimer = Timer(_timeoutDisplayDelay, () {
      _timeoutTimer = null;
      if (!ref.mounted || version != _checkVersion || state.ipInfo != null) {
        return;
      }
      state = state.copyWith(isLoading: false, ipInfo: null);
    });
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }
}

List<Override> buildAppStateOverrides(AppState appState) {
  return [
    initProvider.overrideWithBuild((_, _) => appState.isInit),
    backBlockProvider.overrideWithBuild((_, _) => appState.backBlock),
    currentPageLabelProvider.overrideWithBuild((_, _) => appState.pageLabel),
    packagesProvider.overrideWithBuild((_, _) => appState.packages),
    sortNumProvider.overrideWithBuild((_, _) => appState.sortNum),
    viewSizeProvider.overrideWithBuild((_, _) => appState.viewSize),
    sideWidthProvider.overrideWithBuild((_, _) => appState.sideWidth),
    delayDataSourceProvider.overrideWithBuild((_, _) => appState.delayMap),
    groupsProvider.overrideWithBuild((_, _) => appState.groups),
    checkIpNumProvider.overrideWithBuild((_, _) => appState.checkIpNum),
    systemBrightnessProvider.overrideWithBuild((_, _) => appState.brightness),
    runTimeProvider.overrideWithBuild((_, _) => appState.runTime),
    providersProvider.overrideWithBuild((_, _) => appState.providers),
    localIpProvider.overrideWithBuild((_, _) => appState.localIp),
    requestsProvider.overrideWithBuild((_, _) => appState.requests),
    versionProvider.overrideWithBuild((_, _) => appState.version),
    logsProvider.overrideWithBuild((_, _) => appState.logs),
    trafficsProvider.overrideWithBuild((_, _) => appState.traffics),
    totalTrafficProvider.overrideWithBuild((_, _) => appState.totalTraffic),
    realTunEnableProvider.overrideWithBuild((_, _) => appState.realTunEnable),
    systemUiOverlayStyleStateProvider.overrideWithBuild(
      (_, _) => appState.systemUiOverlayStyle,
    ),
    coreStatusProvider.overrideWithBuild((_, _) => appState.coreStatus),
  ];
}
