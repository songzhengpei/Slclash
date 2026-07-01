import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@visibleForTesting
bool shouldCollectCoreLogs({
  required bool openLogs,
  required bool appForeground,
  required PageLabel currentPageLabel,
}) {
  return openLogs && appForeground && currentPageLabel == PageLabel.logs;
}

@visibleForTesting
bool shouldCollectCoreRequests({
  required bool appForeground,
  required PageLabel currentPageLabel,
}) {
  return appForeground && currentPageLabel == PageLabel.requests;
}

class CoreManager extends ConsumerStatefulWidget {
  final Widget child;

  const CoreManager({super.key, required this.child});

  @override
  ConsumerState<CoreManager> createState() => _CoreContainerState();
}

class _CoreContainerState extends ConsumerState<CoreManager>
    with CoreEventListener {
  bool _logStreamRunning = false;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _syncCoreEventControls() {
    final shouldCollectLogs = shouldCollectCoreLogs(
      openLogs: ref.read(appSettingProvider.select((state) => state.openLogs)),
      appForeground: ref.read(appForegroundProvider),
      currentPageLabel: ref.read(currentPageLabelProvider),
    );
    final shouldCollectRequests = shouldCollectCoreRequests(
      appForeground: ref.read(appForegroundProvider),
      currentPageLabel: ref.read(currentPageLabelProvider),
    );

    coreEventManager.setEventTypeEnabled(CoreEventType.log, shouldCollectLogs);
    coreEventManager.setEventTypeEnabled(
      CoreEventType.request,
      shouldCollectRequests,
    );

    if (!coreController.isCompleted) {
      _logStreamRunning = false;
      return;
    }
    if (shouldCollectLogs && !_logStreamRunning) {
      _logStreamRunning = true;
      coreController.startLog();
    } else if (!shouldCollectLogs && _logStreamRunning) {
      _logStreamRunning = false;
      coreController.stopLog();
    }
  }

  @override
  void initState() {
    super.initState();
    coreEventManager.addListener(this);
    ref.listenManual(currentProfileIdProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(setupActionProvider.notifier).fullSetup();
        });
      }
    });
    ref.listenManual(updateParamsProvider, (prev, next) {
      if (prev != next) {
        ref.read(setupActionProvider.notifier).updateConfigDebounce();
      }
    });
    ref.listenManual(
      appSettingProvider.select((state) => state.openLogs),
      (prev, next) => _syncCoreEventControls(),
    );
    ref.listenManual(
      appForegroundProvider,
      (prev, next) => _syncCoreEventControls(),
    );
    ref.listenManual(
      currentPageLabelProvider,
      (prev, next) => _syncCoreEventControls(),
    );
    ref.listenManual(
      coreStatusProvider,
      (prev, next) => _syncCoreEventControls(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncCoreEventControls();
      }
    });
  }

  @override
  Future<void> dispose() async {
    coreEventManager.setEventTypeEnabled(CoreEventType.log, false);
    coreEventManager.setEventTypeEnabled(CoreEventType.request, false);
    if (_logStreamRunning && coreController.isCompleted) {
      coreController.stopLog();
    }
    _logStreamRunning = false;
    coreEventManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final proxiesAction = ref.read(proxiesActionProvider.notifier);
    proxiesAction.setDelay(delay);
    debouncer.call(FunctionTag.updateDelay, () async {
      proxiesAction.updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 5000));
  }

  @override
  void onLog(Log log) {
    onLogs([log]);
    super.onLog(log);
  }

  @override
  void onLogs(List<Log> logs) {
    if (!shouldCollectCoreLogs(
      openLogs: ref.read(appSettingProvider.select((state) => state.openLogs)),
      appForeground: ref.read(appForegroundProvider),
      currentPageLabel: ref.read(currentPageLabelProvider),
    )) {
      return;
    }
    ref.read(logsProvider.notifier).addAll(logs);
    for (final log in logs) {
      if (log.logLevel == LogLevel.error) {
        globalState.showNotifier(log.payload);
      }
    }
  }

  @override
  void onRequest(TrackerInfo trackerInfo) async {
    onRequests([trackerInfo]);
    super.onRequest(trackerInfo);
  }

  @override
  void onRequests(List<TrackerInfo> trackerInfos) {
    if (!shouldCollectCoreRequests(
      appForeground: ref.read(appForegroundProvider),
      currentPageLabel: ref.read(currentPageLabelProvider),
    )) {
      return;
    }
    ref.read(requestsProvider.notifier).addRequests(trackerInfos);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    final ref = globalState.container;
    ref
        .read(providersProvider.notifier)
        .setProvider(await coreController.getExternalProvider(providerName));
    debouncer.call(FunctionTag.loadedProvider, () async {
      ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    }, duration: const Duration(milliseconds: 1000));
    super.onLoaded(providerName);
  }

  @override
  Future<void> onCrash(String message) async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      context.showNotifier(message);
    }
    await coreController.shutdown(false);
    super.onCrash(message);
  }
}
