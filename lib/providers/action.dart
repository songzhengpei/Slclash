import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/services/backup/restore_service.dart';
import 'package:fl_clash/services/backup/backup_file_guard.dart';
import 'package:fl_clash/services/backup/unified_backup_service.dart';
import 'package:fl_clash/services/providers/provider_readiness_service.dart';
import 'package:fl_clash/services/unified_backup_export/exporter.dart';
import 'package:fl_clash/services/unified_backup_export/models.dart';
import 'package:fl_clash/services/unified_backup_export/profile_materializer.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaml/yaml.dart';

part 'generated/action.g.dart';

/// Real-time traffic speed for speed text display.
/// Updated every 1s. Separate from [trafficsProvider] (chart data, 2-3s).
final currentSpeedNotifier = ValueNotifier<Traffic>(const Traffic());

class BackupRestoreOutcome {
  const BackupRestoreOutcome({
    required this.committed,
    required this.activationSucceeded,
    this.activationError,
    this.providerReadinessStatus,
  });

  final bool committed;
  final bool activationSucceeded;
  final String? activationError;
  final ProviderReadinessStatus? providerReadinessStatus;
}

Future<BackupRestoreOutcome> activateCommittedRestore({
  required Future<bool> Function() applyProfile,
  required Future<void> Function() updateGroups,
}) async {
  try {
    if (!await applyProfile()) {
      return const BackupRestoreOutcome(
        committed: true,
        activationSucceeded: false,
        activationError: 'The proxy core rejected the restored profile',
      );
    }
    await updateGroups();
    return const BackupRestoreOutcome(
      committed: true,
      activationSucceeded: true,
    );
  } catch (_) {
    return const BackupRestoreOutcome(
      committed: true,
      activationSucceeded: false,
      activationError: 'The proxy core could not reload the restored profile',
    );
  }
}

Future<bool> ensureRestoreValidationCoreReady({
  required bool isConnected,
  required Future<bool> Function() connectCore,
  required Future<bool> Function() isCoreInitialized,
  required Future<bool> Function() initializeCore,
}) async {
  if (!isConnected && !await connectCore()) return false;
  if (await isCoreInitialized()) return true;
  return initializeCore();
}

bool shouldFullSetupOnInit({required bool isRunning, required bool autoRun}) {
  return isRunning || autoRun;
}

bool shouldReconnectCoreOnResume({
  required bool isAndroid,
  required bool isRunning,
  required bool hasGroups,
}) {
  return isAndroid && (isRunning || !hasGroups);
}

bool hasExternalProviderDefinitions(ClashConfig config) {
  return config.proxyProviders.isNotEmpty || config.ruleProviders.isNotEmpty;
}

({bool external, bool proxy}) parseProfileProviderDefinitions(String source) {
  final document = loadYaml(source);
  if (document is! YamlMap) return (external: false, proxy: false);

  bool hasEntries(String key) {
    final value = document[key];
    return value is Map && value.isNotEmpty;
  }

  final proxy = hasEntries('proxy-providers');
  final rule = hasEntries('rule-providers');
  return (external: proxy || rule, proxy: proxy);
}

Future<({bool external, bool proxy})> readProfileProviderDefinitions(
  int profileId,
) async {
  final profilePath = await appPath.getProfilePath(profileId.toString());
  final source = await File(profilePath).readAsString();
  return parseProfileProviderDefinitions(source);
}

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  @override
  void build() {}

  void updateStart() {
    ref
        .read(setupActionProvider.notifier)
        .updateStatus(!ref.read(isStartProvider));
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  void updateRunTime() {
    final startTime = ref.read(setupActionProvider.notifier).startTime;
    if (startTime != null) {
      final startTimeStamp = startTime.millisecondsSinceEpoch;
      final nowTimeStamp = DateTime.now().millisecondsSinceEpoch;
      ref.read(runTimeProvider.notifier).value = nowTimeStamp - startTimeStamp;
    } else {
      ref.read(runTimeProvider.notifier).value = null;
    }
  }

  Future<void> updateTraffic() async {
    final onlyStatisticsProxy = ref.read(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    final snapshot = await coreController.getTrafficSnapshot(
      onlyStatisticsProxy,
    );
    ref.read(trafficsProvider.notifier).addTraffic(snapshot.traffic);
    // Diff check: only update totalTraffic if value actually changed
    final currentTotal = ref.read(totalTrafficProvider);
    if (snapshot.totalTraffic.up != currentTotal.up ||
        snapshot.totalTraffic.down != currentTotal.down) {
      ref.read(totalTrafficProvider.notifier).value = snapshot.totalTraffic;
    }
  }

  Future<void> autoCheckUpdate() async {
    if (!ref.read(appSettingProvider).autoCheckUpdate) return;
    final res = await request.checkForUpdate();
    checkUpdateResultHandle(data: res);
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool isUser = false,
  }) async {
    if (data != null) {
      final tagName = data['tag_name'];
      final body = data['body'];
      final submits = utils.parseReleaseBody(body);
      final res = await globalState.showCommonDialog<bool>(
        child: _UpdateAvailableDialog(
          tagName: tagName?.toString() ?? '',
          submits: submits,
          cancelText: isUser
              ? currentAppLocalizations.cancel
              : currentAppLocalizations.noLongerRemind,
        ),
      );
      if (res == true) {
        await _downloadAndInstallUpdate(data);
      } else if (!isUser && res == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
    } else if (isUser) {
      globalState.showCommonDialog<void>(
        child: _UpdateStatusDialog(
          title: currentAppLocalizations.checkUpdate,
          message: currentAppLocalizations.checkUpdateError,
          icon: SurgeIcons.verified,
        ),
      );
    }
  }

  Map<String, dynamic>? _resolveAndroidApkAsset(Map<String, dynamic> data) {
    final assets = data['assets'];
    if (assets is! List) return null;
    final apkAssets = assets.whereType<Map<String, dynamic>>().where((asset) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      final url = asset['browser_download_url']?.toString() ?? '';
      return name.endsWith('.apk') && url.isNotEmpty;
    }).toList();
    if (apkAssets.isEmpty) return null;
    return apkAssets.firstWhere(
      (asset) =>
          asset['name']?.toString().toLowerCase().contains('arm64-v8a') == true,
      orElse: () => apkAssets.first,
    );
  }

  Future<void> _downloadAndInstallUpdate(Map<String, dynamic> data) async {
    final asset = _resolveAndroidApkAsset(data);
    if (asset == null) {
      launchUrl(Uri.parse('https://github.com/$repository/releases/latest'));
      return;
    }

    final url = asset['browser_download_url']?.toString();
    final name = asset['name']?.toString() ?? 'SlClash-update.apk';
    if (url == null || url.isEmpty) {
      launchUrl(Uri.parse('https://github.com/$repository/releases/latest'));
      return;
    }

    final progress = ValueNotifier<double?>(0);
    final dialogContext = globalState.navigatorKey.currentContext!;
    var dialogClosed = false;
    void closeProgressDialog() {
      if (dialogClosed || !dialogContext.mounted) return;
      dialogClosed = true;
      Navigator.of(dialogContext).pop();
    }

    unawaited(
      globalState.showCommonDialog<void>(
        context: dialogContext,
        dismissible: false,
        child: _UpdateDownloadProgressDialog(progress: progress),
      ),
    );

    await globalState.safeRun<void>(
      () async {
        final cacheDir = await appPath.cacheDir.future;
        final updateDir = Directory(p.join(cacheDir.path, 'updates'));
        if (!updateDir.existsSync()) {
          updateDir.createSync(recursive: true);
        }
        for (final file in updateDir.listSync()) {
          if (file is File && file.path.endsWith('.apk')) {
            file.deleteSync();
          }
        }

        final apkPath = p.join(updateDir.path, name);
        await request.dio.download(
          url,
          apkPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              progress.value = (received / total).clamp(0, 1);
            } else {
              progress.value = null;
            }
          },
        );
        progress.value = 1;
        closeProgressDialog();
        final installed = await app?.installApk(apkPath) ?? false;
        if (!installed) {
          throw currentAppLocalizations.allowUnknownAppInstall;
        }
      },
      title: currentAppLocalizations.download,
      silence: false,
    );
    closeProgressDialog();
    progress.dispose();
  }
}

class _UpdateDownloadProgressDialog extends StatelessWidget {
  const _UpdateDownloadProgressDialog({required this.progress});

  final ValueNotifier<double?> progress;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return CommonDialog(
      title: currentAppLocalizations.downloadUpdate,
      overrideScroll: true,
      child: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, value, _) {
          final percent = value == null ? null : (value * 100).floor();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: surge.fill,
                  borderRadius: BorderRadius.circular(surge.radii.card),
                  border: Border.all(color: surge.separator, width: 0.5),
                ),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: value,
                            strokeWidth: 3,
                            color: surge.primary,
                            backgroundColor: surge.separator,
                          ),
                          Icon(
                            SurgeIcons.download,
                            size: 18,
                            color: surge.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        percent == null
                            ? currentAppLocalizations.downloadingApk
                            : currentAppLocalizations.downloadingApkProgress(
                                percent,
                              ),
                        maxLines: 2,
                        style: context.typography.rowTitle.copyWith(
                          color: surge.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: value,
                  color: surge.primary,
                  backgroundColor: surge.fill,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                currentAppLocalizations.apkInstallAfterDownload,
                style: context.typography.supporting.copyWith(
                  color: surge.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({
    required this.tagName,
    required this.submits,
    required this.cancelText,
  });

  final String tagName;
  final List<String> submits;
  final String cancelText;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return CommonDialog(
      title: currentAppLocalizations.discoverNewVersion,
      overrideScroll: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: surge.fill,
              borderRadius: BorderRadius.circular(surge.radii.card),
              border: Border.all(color: surge.separator, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(SurgeIcons.newRelease, color: surge.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tagName.takeFirstValid([
                      currentAppLocalizations.newVersion,
                    ]),
                    maxLines: 2,
                    style: context.typography.cardTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (submits.isNotEmpty) ...[
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: Scrollbar(
                thumbVisibility: false,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: submits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) =>
                      _UpdateChangeItem(text: submits[index]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SurgeDialogActionRow(
            cancelLabel: cancelText,
            submitLabel: currentAppLocalizations.download,
            onCancel: () => Navigator.of(context).pop(false),
            onSubmit: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

class _UpdateStatusDialog extends StatelessWidget {
  const _UpdateStatusDialog({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return CommonDialog(
      title: title,
      overrideScroll: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: surge.fill,
              borderRadius: BorderRadius.circular(surge.radii.card),
              border: Border.all(color: surge.separator, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(icon, color: surge.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: context.typography.body.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SurgeDialogActionButton(
                label: currentAppLocalizations.confirm,
                onPressed: () => Navigator.of(context).pop(),
                primary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateChangeItem extends StatelessWidget {
  const _UpdateChangeItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: surge.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: context.typography.supporting.copyWith(
              color: surge.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  static const _tickInterval = Duration(seconds: 1);
  static const _chartUpdateInterval = Duration(seconds: 2);
  static const _totalTrafficUpdateInterval = Duration(seconds: 5);
  static const _runtimeUpdateInterval = Duration(seconds: 5);

  Timer? _updateTimer;
  DateTime? startTime;
  bool _isUpdatingUiStats = false;
  DateTime? _lastChartUpdateAt;
  DateTime? _lastTotalTrafficUpdateAt;
  DateTime? _lastRuntimeUpdateAt;

  bool get isStart => startTime != null && startTime!.isBeforeNow;

  @override
  void build() {
    ref.listen(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _restartUiStatsTimerIfNeeded();
      }
    });
    ref.listen(appForegroundProvider, (prev, next) {
      if (prev == true && next == false) {
        cancelUiStatsTimer();
      } else if (prev == false && next == true) {
        resumeUiStatsTimerIfNeeded();
      }
    });
    ref.onDispose(() {
      _updateTimer?.cancel();
      _updateTimer = null;
    });
  }

  bool get _isDashboardActive {
    return ref.read(currentPageLabelProvider) == PageLabel.dashboard;
  }

  static bool _shouldRun(DateTime now, DateTime? lastAt, Duration interval) {
    return lastAt == null || now.difference(lastAt) >= interval;
  }

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    return SetupParams(selectedMap: selectedMap, testUrl: testUrl);
  }

  Future<bool> fullSetup() async {
    if (!ref.read(initProvider)) return false;
    ref.read(delayDataSourceProvider.notifier).value = {};
    final applied = await applyProfile(force: true);
    ref.read(logsProvider.notifier).value = FixedList(500);
    ref.read(requestsProvider.notifier).value = FixedList(500);
    return applied;
  }

  Future<bool> _handleStart() async {
    if (!ref.read(suspendProvider)) {
      final started = await coreController.startListener();
      if (!started) {
        startTime = null;
        ref.read(runTimeProvider.notifier).value = null;
        ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
        ref.read(realTunEnableProvider.notifier).value = false;
        return false;
      }
    }
    unawaited(_updateUiStats());
    _startUiStatsTimer();
    return true;
  }

  /// Full chain: fetch snapshot, update speed (1s), chart (2s), total (5s), runtime (5s).
  Future<void> _updateUiStats() async {
    // Visibility gate: only non-dashboard pages → skip everything except runtime at 5s
    if (!_isDashboardActive) {
      final now = DateTime.now();
      if (_shouldRun(now, _lastRuntimeUpdateAt, _runtimeUpdateInterval)) {
        ref.read(commonActionProvider.notifier).updateRunTime();
        _lastRuntimeUpdateAt = now;
      }
      return;
    }
    if (_isUpdatingUiStats) return;
    _isUpdatingUiStats = true;
    try {
      final now = DateTime.now();

      // Fetch snapshot once per tick (FFI call)
      final onlyStatisticsProxy = ref.read(
        appSettingProvider.select((state) => state.onlyStatisticsProxy),
      );
      final snapshot = await coreController.getTrafficSnapshot(
        onlyStatisticsProxy,
      );

      // 1. Speed text: every tick (1s) — lightweight ValueNotifier, no Provider rebuild
      currentSpeedNotifier.value = snapshot.traffic;

      // 2. Chart points: throttle to 2s
      if (_shouldRun(now, _lastChartUpdateAt, _chartUpdateInterval)) {
        ref.read(trafficsProvider.notifier).addTraffic(snapshot.traffic);
        _lastChartUpdateAt = now;
      }

      // 3. Total traffic: throttle to 5s + diff check
      if (_shouldRun(
        now,
        _lastTotalTrafficUpdateAt,
        _totalTrafficUpdateInterval,
      )) {
        final currentTotal = ref.read(totalTrafficProvider);
        if (snapshot.totalTraffic.up != currentTotal.up ||
            snapshot.totalTraffic.down != currentTotal.down) {
          ref.read(totalTrafficProvider.notifier).value = snapshot.totalTraffic;
        }
        _lastTotalTrafficUpdateAt = now;
      }

      // 4. Runtime: throttle to 5s
      if (_shouldRun(now, _lastRuntimeUpdateAt, _runtimeUpdateInterval)) {
        ref.read(commonActionProvider.notifier).updateRunTime();
        _lastRuntimeUpdateAt = now;
      }
    } catch (e) {
      commonPrint.log('update ui stats failed: $e', logLevel: LogLevel.warning);
    } finally {
      _isUpdatingUiStats = false;
    }
  }

  void _startUiStatsTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_tickInterval, (_) {
      unawaited(_updateUiStats());
    });
  }

  void _restartUiStatsTimerIfNeeded() {
    if (_updateTimer == null) return;
    if (!ref.read(isStartProvider) || ref.read(isSmartStoppedProvider)) {
      cancelUiStatsTimer();
      return;
    }
    _startUiStatsTimer();
  }

  /// Cancel the UI stats timer when app goes to background.
  /// Does NOT reset startTime, traffic, or core listener.
  void cancelUiStatsTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _lastChartUpdateAt = null;
    _lastTotalTrafficUpdateAt = null;
    _lastRuntimeUpdateAt = null;
  }

  /// Resume the UI stats timer when app returns to foreground.
  /// Only resumes if VPN is running and not smart-paused.
  void resumeUiStatsTimerIfNeeded() {
    final isRunning = ref.read(isStartProvider);
    final isSmartStopped = ref.read(isSmartStoppedProvider);
    if (!isRunning || isSmartStopped) return;
    // Refresh immediately
    unawaited(_updateUiStats());
    // Restore periodic timer (no-op if already running)
    if (_updateTimer == null) {
      _startUiStatsTimer();
    }
  }

  Future _updateStartTime() async {
    startTime = await service?.getRunTime();
  }

  Future handleStop() async {
    startTime = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    await coreController.stopListener();
    // P0+P1: 停代理后先关连接释放 buffer，再 GC 释放 Go 堆
    // 顺序执行，不阻塞 handleStop 调用者的后续 UI 重置
    unawaited(
      coreController.closeConnections().then((_) => coreController.requestGc()),
    );
  }

  /// Local-only stop for smart auto stop: cancel timer, stop listener,
  /// clear runTime in UI — but do NOT reset traffic or call native stopService.
  Future handleSmartStopLocal() async {
    startTime = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    await coreController.stopListener();
    ref.read(runTimeProvider.notifier).value = null;
  }

  /// Local-only resume for smart auto stop: restore startTime, restart
  /// runtime/traffic timer, resume core listener.
  Future handleSmartResumeLocal(DateTime nativeStartTime) async {
    startTime = nativeStartTime;
    ref.read(runTimeProvider.notifier).value =
        nativeStartTime.millisecondsSinceEpoch;
    unawaited(_updateUiStats());
    if (!ref.read(suspendProvider)) {
      await coreController.startListener();
    }
    _startUiStatsTimer();
  }

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      commonPrint.log('init status cancel');
      return;
    }
    commonPrint.log('init status');
    if (system.isAndroid) {
      await _updateStartTime();
    }
    final shouldFullSetup = shouldFullSetupOnInit(
      isRunning: isStart,
      autoRun: ref.read(appSettingProvider).autoRun,
    );
    if (shouldFullSetup) {
      final coreAction = ref.read(coreActionProvider.notifier);
      final connected = await coreAction.connectCore();
      if (!connected) {
        startTime = null;
        ref.read(runTimeProvider.notifier).value = null;
        return;
      }
      await coreAction.initCore();
      await updateStatus(true, isInit: true);
    } else {
      globalState.needInitStatus = false;
      ref.read(runTimeProvider.notifier).value = null;
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      commonPrint.log('init status skip full setup');
    }
  }

  Future<void> updateStatus(bool isStart, {bool isInit = false}) async {
    if (isStart) {
      if (!isInit) {
        final res = await ref
            .read(coreActionProvider.notifier)
            .tryStartCore(true);
        if (res) return;
        if (!ref.read(initProvider)) return;

        final started = await _handleStart();
        if (!started) return;

        final applied = await applyProfile(force: true, silence: true);
        if (!applied) {
          await handleStop();
          startTime = null;
          ref.read(runTimeProvider.notifier).value = null;
          return;
        }

        startTime ??= DateTime.now();
        ref.read(commonActionProvider.notifier).updateRunTime();
      } else {
        globalState.needInitStatus = false;
        try {
          var started = true;

          final applied = await applyProfile(
            force: true,
            preloadInvoke: () async {
              started = await _handleStart();
            },
          );

          if (!started || !applied) {
            startTime = null;
            ref.read(runTimeProvider.notifier).value = null;
            return;
          }

          startTime ??= DateTime.now();
          ref.read(runTimeProvider.notifier).value = 0;
          ref.read(commonActionProvider.notifier).updateRunTime();
        } catch (_) {
          startTime = null;
          ref.read(runTimeProvider.notifier).value = null;
        }
      }
    } else {
      // Clear smart auto stop manual override when user stops proxy.
      // This ensures the next start on a trusted network auto-stops again.
      ref.read(smartAutoStopManualOverrideProvider.notifier).clear();
      await handleStop();
      coreController.resetTraffic();
      ref.read(trafficsProvider.notifier).clear();
      ref.read(totalTrafficProvider.notifier).value = const Traffic();
      ref.read(runTimeProvider.notifier).value = null;
      ref.read(checkIpNumProvider.notifier).add();
    }
  }

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, () async {
      await globalState.safeRun(() async {
        final updateParams = ref.read(updateParamsProvider);
        final res = await _requestAdmin(updateParams.tun.enable);
        if (res.isError) return;
        final realTunEnable = ref.read(realTunEnableProvider);
        final message = await coreController.updateConfig(
          updateParams.copyWith.tun(enable: realTunEnable),
        );
        if (message.isNotEmpty) throw message;
      });
    });
  }

  void tryCheckIp() {
    final shouldRetry = ref.read(
      networkDetectionProvider.select(
        (state) =>
            state.hasChecked &&
            state.ipInfo == null &&
            state.isLoading == false,
      ),
    );
    if (!shouldRetry) return;
    ref.read(checkIpNumProvider.notifier).add();
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    debouncer.call(FunctionTag.applyProfile, (silence, force) {
      applyProfile(silence: silence, force: force);
    }, args: [silence, force]);
  }

  void changeMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
    ref.read(checkIpNumProvider.notifier).add();
  }

  void autoApplyProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyProfile();
    });
  }

  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    FutureOr<void> Function()? preloadInvoke,
  }) async {
    return _setupConfig(
      force: force,
      silence: silence,
      preloadInvoke: preloadInvoke,
      onUpdated: () async {
        final proxiesAction = ref.read(proxiesActionProvider.notifier);
        await proxiesAction.updateGroups();
        unawaited(proxiesAction.preheatComputedGroups());
        await ref.read(providersProvider.notifier).syncProviders();
      },
    );
  }

  Future<void> applyProfileForDisplay({bool silence = true}) async {
    final patchConfig = ref
        .read(patchClashConfigProvider)
        .copyWith
        .tun(enable: false);
    await _setupConfig(
      force: true,
      silence: silence,
      patchConfigOverride: patchConfig,
      requestAdmin: false,
    );
  }

  Future<VM2<String, String>> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) return const VM2('', '');
    final defaultUA = globalState.packageInfo.ua;
    final networkVM2 = ref.read(
      networkSettingProvider.select(
        (state) => VM2(state.appendSystemDns, state.routeMode),
      ),
    );
    final overrideDns = ref.read(overrideDnsProvider);
    final appendSystemDns = networkVM2.a;
    final routeMode = networkVM2.b;
    final configMap = await coreController.getConfig(profileId);
    String? scriptContent;
    final List<Rule> addedRules = [];
    final List<ProxyGroup> proxyGroups = [];
    final List<Rule> rules = [];
    if (setupState.overwriteType == OverwriteType.script) {
      scriptContent = await setupState.script?.content;
    } else if (setupState.overwriteType == OverwriteType.standard) {
      addedRules.addAll(setupState.addedRules);
    } else {
      proxyGroups.addAll(setupState.proxyGroups);
      rules.addAll(setupState.rules);
    }
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(routeMode),
    );
    Map<String, dynamic> rawConfig = configMap;
    if (scriptContent?.isNotEmpty == true) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    final res = makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: realPatchConfig,
        overrideDns: overrideDns,
        appendSystemDns: appendSystemDns,
        addedRules: addedRules,
        defaultUA: defaultUA,
      ),
    );
    return res;
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return res.a;
    } catch (e) {
      globalState.showNotifier(e.toString());
    }
    return '';
  }

  Future<Result<bool>> _requestAdmin(bool enableTun) async {
    final realTunEnable = ref.read(realTunEnableProvider);
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore();
      switch (code) {
        case AuthorizeCode.success:
          await ref.read(coreActionProvider.notifier).restartCore();
          return Result.error('');
        case AuthorizeCode.none:
          break;
        case AuthorizeCode.error:
          enableTun = false;
          break;
      }
    }
    ref.read(realTunEnableProvider.notifier).value = enableTun;
    return Result.success(enableTun);
  }

  Future<bool> _setupConfig({
    bool force = false,
    bool silence = false,
    FutureOr<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
    PatchClashConfig? patchConfigOverride,
    bool requestAdmin = true,
  }) async {
    var profile = ref.read(currentProfileProvider);
    final nextProfile = await profile?.checkAndUpdateAndCopy();
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    commonPrint.log('setup ===> ${profile?.id}');
    final PatchClashConfig patchConfig =
        patchConfigOverride ?? ref.read(patchClashConfigProvider);
    late final bool realTunEnable;
    if (requestAdmin) {
      final res = await _requestAdmin(patchConfig.tun.enable);
      if (res.isError) return false;
      realTunEnable = ref.read(realTunEnableProvider);
    } else {
      realTunEnable = false;
    }
    final realPatchConfig = patchConfig.copyWith.tun(enable: realTunEnable);
    final setupState = await ref.read(setupStateProvider(profile?.id).future);
    if (system.isAndroid) {
      globalState.lastVpnState = ref.read(vpnStateProvider);
      final sharedState = ref.read(sharedStateProvider);
      preferences.saveShareState(sharedState);
    }
    final vm2 = await getProfile(
      setupState: setupState,
      patchConfig: realPatchConfig,
    );
    final yamlString = vm2.a;
    final yamlMd5 = vm2.b;
    if (yamlMd5 == globalState.lastConfigMd5 && force == false) return true;
    var success = false;
    await globalState.loadingRun(
      () async {
        final configFilePath = await appPath.configFilePath;
        await File(configFilePath).safeWriteAsString(yamlString);
        final message = await coreController.setupConfig(
          setupState: setupState,
          params: _setupParams,
          preloadInvoke: preloadInvoke,
        );

        if (message.isNotEmpty) {
          commonPrint.log(
            'setupConfig failed: profileId=${setupState.profileId}, '
            'message="$message", ignoredIsEmpty=${message.endsWith('is empty')}',
            logLevel: LogLevel.warning,
          );

          if (message.endsWith('is empty')) {
            success = false;
            return;
          }

          throw message;
        }

        globalState.lastConfigMd5 = yamlMd5;
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
        success = true;
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
    return success;
  }
}

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  Future<String> backup() async {
    final profiles = ref.read(profilesProvider);
    final currentProfileId = ref.read(currentProfileIdProvider);
    final profilesPath = await appPath.profilesPath;
    final exportProfiles = <UnifiedExportProfile>[];
    for (final profile in profiles) {
      final file = File(join(profilesPath, '${profile.id}.yaml'));
      if (!await file.exists()) {
        throw StateError(
          'Cannot create backup: profile ${profile.id} is missing its YAML file',
        );
      }
      final info = profile.subscriptionInfo;
      final materializedYaml = await materializeProfileForUnifiedExport(
        profileId: profile.id,
        profileBytes: await file.readAsBytes(),
        profilesDirectory: profilesPath,
        normalizeProviderContent: (bytes) async {
          final ready = await ensureRestoreValidationCoreReady(
            isConnected: coreController.isCompleted,
            connectCore: ref.read(coreActionProvider.notifier).connectCore,
            isCoreInitialized: () async => coreController.isInit,
            initializeCore: () =>
                coreController.init(ref.read(versionProvider)),
          );
          if (!ready) {
            throw StateError(
              currentAppLocalizations.proxyCoreCannotReadProvider,
            );
          }
          return coreController.normalizeProviderContent(bytes);
        },
      );
      exportProfiles.add(
        UnifiedExportProfile(
          androidId: profile.id,
          name: profile.realLabel,
          sourceUrl: profile.url,
          yaml: materializedYaml.yaml,
          providerSourceYaml: materializedYaml.providerSourceYaml,
          updated:
              (profile.lastUpdateDate ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .millisecondsSinceEpoch ~/
              1000,
          autoUpdate: profile.realAutoUpdate,
          updateIntervalMinutes: profile.autoUpdateDuration.inMinutes,
          subscriptionInfo: info == null
              ? null
              : {
                  'upload': info.upload,
                  'download': info.download,
                  'total': info.total,
                  'expire': info.expire,
                },
          externalProvidersFlattened:
              materializedYaml.externalProvidersFlattened,
          localFile: profile.type == ProfileType.file,
        ),
      );
    }
    final importedArchiveFile = File(await appPath.workerUnifiedArchivePath);
    final trustedArchive = await importedArchiveFile.exists()
        ? await importedArchiveFile.readAsBytes()
        : null;
    final bytes = const UnifiedV1Exporter().build(
      UnifiedExportInput(
        profiles: exportProfiles,
        currentAndroidId: currentProfileId,
        trustedArchive: trustedArchive,
        generatorVersion: '1.0.0',
      ),
    );
    final target = File(await appPath.tempFilePath);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<BackupRestoreOutcome> restore() async {
    final restoreWatch = Stopwatch()..start();
    final restoreStrategy = ref.read(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    final backup = File(await appPath.backupFilePath);
    final archiveLength = await backup.length();
    commonPrint.log(
      'backup-restore:start strategy=${restoreStrategy.name} archiveBytes=$archiveLength',
    );
    await validateBackupArchiveFile(backup);
    commonPrint.log(
      'backup-restore:archive-validated elapsedMs=${restoreWatch.elapsedMilliseconds}',
    );
    final coreWatch = Stopwatch()..start();
    final coreReady = await ensureRestoreValidationCoreReady(
      isConnected: coreController.isCompleted,
      connectCore: ref.read(coreActionProvider.notifier).connectCore,
      isCoreInitialized: () async => coreController.isInit,
      initializeCore: () => coreController.init(ref.read(versionProvider)),
    );
    commonPrint.log(
      'backup-restore:core-ready elapsedMs=${coreWatch.elapsedMilliseconds} ready=$coreReady',
    );
    if (!coreReady) {
      throw StateError(currentAppLocalizations.proxyCoreCannotValidateBackup);
    }
    final result =
        await UnifiedBackupService(
          database: database,
          paths: RestorePaths(
            profilesDirectory: await appPath.profilesPath,
            scriptsDirectory: await appPath.scriptsDirPath,
            workerUnifiedArchivePath: await appPath.workerUnifiedArchivePath,
          ),
          validateProfileYaml: (profileId, bytes) async {
            final temporary = File(await appPath.tempFilePath);
            try {
              await temporary.writeAsBytes(bytes, flush: true);
              final message = await coreController.validateConfig(
                temporary.path,
              );
              if (message.isNotEmpty) throw message;
            } finally {
              await temporary.safeDelete();
            }
          },
          readConfig: preferences.getConfig,
          writeConfig: preferences.saveConfig,
          onProgress: (stage, profileCount) {
            commonPrint.log(
              'backup-restore:$stage elapsedMs=${restoreWatch.elapsedMilliseconds} '
              'profileCount=${profileCount ?? '-'}',
            );
          },
        ).restoreBytes(
          await backup.readAsBytes(),
          override: restoreStrategy == RestoreStrategy.override,
        );
    final restoredProfiles = await database.profilesDao.query().get();
    commonPrint.log(
      'backup-restore:state-reloaded elapsedMs=${restoreWatch.elapsedMilliseconds} '
      'profileCount=${restoredProfiles.length} currentProfileId=${result.currentProfileId}',
    );
    ref.read(profilesProvider.notifier).resetFromRestore(restoredProfiles);
    ref.read(providersProvider.notifier).clear();
    ref.read(groupsProvider.notifier).value = const [];
    ref.read(groupsOwnerProfileIdProvider.notifier).set(null);
    ref.read(proxyGroupsSnapshotProvider.notifier).none();
    ref.read(delayDataSourceProvider.notifier).value = const {};
    ref.read(currentProfileIdProvider.notifier).value = result.currentProfileId;
    if (result.config case final restoredConfig?) {
      ref.read(appSettingProvider.notifier).value =
          restoredConfig.appSettingProps;
      ref.read(windowSettingProvider.notifier).value =
          restoredConfig.windowProps;
      ref.read(vpnSettingProvider.notifier).value = restoredConfig.vpnProps;
      ref.read(networkSettingProvider.notifier).value =
          restoredConfig.networkProps;
      ref.read(themeSettingProvider.notifier).value = restoredConfig.themeProps;
      ref.read(davSettingProvider.notifier).value = restoredConfig.davProps;
      ref.read(overrideDnsProvider.notifier).value = restoredConfig.overrideDns;
      ref.read(hotKeyActionsProvider.notifier).value =
          restoredConfig.hotKeyActions;
      ref.read(proxiesStyleSettingProvider.notifier).value =
          restoredConfig.proxiesStyleProps;
      ref.read(patchClashConfigProvider.notifier).value =
          restoredConfig.patchClashConfig;
    }
    final readiness = await ref
        .read(proxiesActionProvider.notifier)
        .ensureCurrentProfileReady(forceApply: true);
    final succeeded =
        readiness.status == ProviderReadinessStatus.ready ||
        readiness.status == ProviderReadinessStatus.noProviders;
    commonPrint.log(
      'backup-restore:completed elapsedMs=${restoreWatch.elapsedMilliseconds} '
      'committed=true activation=${readiness.status.name} '
      'providerCount=${readiness.providerCount} groupCount=${readiness.groupCount}',
      logLevel: succeeded ? LogLevel.info : LogLevel.warning,
    );
    return BackupRestoreOutcome(
      committed: true,
      activationSucceeded: succeeded,
      activationError: succeeded
          ? null
          : readiness.error?.toString() ??
                'Provider and proxy groups are not ready yet',
      providerReadinessStatus: readiness.status,
    );
  }
}

@Riverpod(keepAlive: true)
class CoreAction extends _$CoreAction {
  Future<bool>? _connectCoreFuture;
  Future<bool>? _ensureCoreReadyFuture;

  @override
  void build() {}

  Future<void> initCore() async {
    final wasInitialized = await coreController.isInit;
    final ready = await ensureCoreReady();
    if (!ready) return;
    if (!wasInitialized) {
      final profileId = ref.read(currentProfileIdProvider);
      if (profileId != null) {
        ref.invalidate(clashConfigProvider(profileId));
        unawaited(
          ref
              .read(proxiesActionProvider.notifier)
              .ensureCurrentProfileReady(forceApply: true),
        );
      }
    } else {
      final profileId = ref.read(currentProfileIdProvider);
      final ownerId = ref.read(groupsOwnerProfileIdProvider);
      if (profileId != null &&
          (ownerId != profileId || ref.read(groupsProvider).isEmpty)) {
        ref.invalidate(clashConfigProvider(profileId));
        unawaited(
          ref
              .read(proxiesActionProvider.notifier)
              .ensureCurrentProfileReady(forceApply: true),
        );
      } else {
        await ref.read(proxiesActionProvider.notifier).updateGroups();
      }
    }
  }

  Future<bool> connectCore() async {
    final running = _connectCoreFuture;
    if (running != null) {
      commonPrint.log('core-connect:reuse');
      return running;
    }
    final future = _connectCore();
    _connectCoreFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_connectCoreFuture, future)) {
        _connectCoreFuture = null;
      }
    }
  }

  Future<bool> ensureCoreReady() async {
    final running = _ensureCoreReadyFuture;
    if (running != null) {
      commonPrint.log('core-ready:reuse');
      return running;
    }
    final future = _ensureCoreReady();
    _ensureCoreReadyFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_ensureCoreReadyFuture, future)) {
        _ensureCoreReadyFuture = null;
      }
    }
  }

  Future<bool> _ensureCoreReady() async {
    final watch = Stopwatch()..start();
    if (!coreController.isCompleted && !await connectCore()) return false;
    if (await coreController.isInit) {
      commonPrint.log(
        'core-ready:already-initialized elapsedMs=${watch.elapsedMilliseconds}',
      );
      return true;
    }
    final initialized = await coreController.init(ref.read(versionProvider));
    commonPrint.log(
      'core-ready:initialized elapsedMs=${watch.elapsedMilliseconds} '
      'success=$initialized',
      logLevel: initialized ? LogLevel.info : LogLevel.warning,
    );
    if (!initialized) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    }
    return initialized;
  }

  Future<bool> _connectCore() async {
    final watch = Stopwatch()..start();
    commonPrint.log('core-connect:start');
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    final result = await Future.wait([
      coreController.preload(),
      Future.delayed(const Duration(milliseconds: 300)),
    ]);
    final String message = result[0];
    if (message.isNotEmpty) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      globalState.showNotifier(message);
      commonPrint.log(
        'core-connect:failed elapsedMs=${watch.elapsedMilliseconds}',
        logLevel: LogLevel.error,
      );
      return false;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    commonPrint.log(
      'core-connect:ready elapsedMs=${watch.elapsedMilliseconds}',
    );
    return true;
  }

  Future<Result<bool>> requestAdmin(bool enableTun) async {
    final realTunEnable = ref.read(realTunEnableProvider);
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore();
      switch (code) {
        case AuthorizeCode.success:
          await restartCore();
          return Result.error('');
        case AuthorizeCode.none:
          break;
        case AuthorizeCode.error:
          enableTun = false;
          break;
      }
    }
    ref.read(realTunEnableProvider.notifier).value = enableTun;
    return Result.success(enableTun);
  }

  Future<bool> restartCore([bool start = false]) async {
    final isDisconnected =
        ref.read(coreStatusProvider) == CoreStatus.disconnected;
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await coreController.shutdown(!isDisconnected);
    final connected = await connectCore();
    if (!connected) return false;
    await initCore();
    if (start || ref.read(isStartProvider)) {
      await ref
          .read(setupActionProvider.notifier)
          .updateStatus(true, isInit: true);
    } else {
      await ref.read(setupActionProvider.notifier).applyProfile(force: true);
    }
    return true;
  }

  Future<bool> tryStartCore([bool start = false]) async {
    if (coreController.isCompleted) return false;
    return restartCore(start);
  }

  void handleCoreDisconnected() {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
  }
}

@Riverpod(keepAlive: true)
class SystemAction extends _$SystemAction {
  @override
  void build() {}

  Future<List<Package>> getPackages() async {
    if (ref.read(isMobileViewProvider)) {
      await Future.delayed(commonDuration);
    }
    if (ref.read(packagesProvider).isEmpty) {
      ref.read(packagesProvider.notifier).value =
          await app?.getPackages() ?? [];
    }
    return ref.read(packagesProvider);
  }

  Future<void> handleExit([bool needSave = false]) async {
    Future.delayed(const Duration(seconds: 3), () {
      system.exit();
    });
    try {
      await Future.wait([
        if (needSave) preferences.saveConfig(ref.read(configProvider)),
        if (proxy != null) proxy!.stopProxy(),
      ]);
      await coreController.destroy();
      commonPrint.log('exit');
    } finally {
      system.exit();
    }
  }

  Future<void> handleBackOrExit() async {
    if (ref.read(backBlockProvider)) return;
    if (ref.read(appSettingProvider).minimizeOnExit) {
      await system.back();
    } else {
      await handleExit();
    }
  }

  void updateTun() {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: !state.tun.enable));
  }

  void updateSystemProxy() {
    ref
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(systemProxy: !state.systemProxy));
  }

  void updateAutoLaunch() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoLaunch: !state.autoLaunch));
  }

  Future<void> updateLocalIp() async {
    ref.read(localIpProvider.notifier).value = null;
    await Future.delayed(commonDuration);
    ref.read(localIpProvider.notifier).value = await utils.getLocalIpAddress();
  }
}

@Riverpod(keepAlive: true)
class StoreAction extends _$StoreAction {
  @override
  void build() {}

  Future<void> shakingStore() async {
    final profileIds = ref.read(
      profilesProvider.select((state) => state.map((item) => item.id)),
    );
    final scriptIds = await ref.read(
      scriptsProvider.future.select(
        (state) async => (await state).map((item) => item.id),
      ),
    );
    final pathsToDelete = await shakingProfileTask(VM2(profileIds, scriptIds));
    if (pathsToDelete.isNotEmpty) {
      final deleteFutures = pathsToDelete.map((path) async {
        try {
          final res = await coreController.deleteFile(path);
          if (res.isNotEmpty) throw res;
        } catch (e) {
          rethrow;
        }
      });
      await Future.wait(deleteFutures);
    }
  }

  void savePreferencesDebounce() {
    debouncer.call(FunctionTag.savePreferences, () async {
      await preferences.saveConfig(ref.read(configProvider));
    });
  }

  Future handleClear() async {
    _resetConfigState();
    await preferences.clearPreferences();
    commonPrint.log('clear preferences');
    await database.close();
    await _clearDirectoryContents(Directory(await appPath.homeDirPath));
    await _clearDirectoryContents(await appPath.cacheDir.future);
    await preferences.clearPreferences();
    ref.read(systemActionProvider.notifier).handleExit(false);
  }

  void _resetConfigState() {
    ref.read(appSettingProvider.notifier).value = defaultAppSettingProps;
    ref.read(windowSettingProvider.notifier).value = defaultWindowProps;
    ref.read(vpnSettingProvider.notifier).value = defaultVpnProps;
    ref.read(networkSettingProvider.notifier).value = defaultNetworkProps;
    ref.read(themeSettingProvider.notifier).value = defaultThemeProps;
    ref.read(currentProfileIdProvider.notifier).value = null;
    ref.read(davSettingProvider.notifier).value = null;
    ref.read(overrideDnsProvider.notifier).value = false;
    ref.read(hotKeyActionsProvider.notifier).value = [];
    ref.read(proxiesStyleSettingProvider.notifier).value =
        defaultProxiesStyleProps;
    ref.read(patchClashConfigProvider.notifier).value = defaultClashConfig;
  }

  Future<void> _clearDirectoryContents(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      await entity.safeDelete(recursive: true);
    }
  }
}

@Riverpod(keepAlive: true)
class ThemeAction extends _$ThemeAction {
  @override
  void build() {}

  void updateBrightness() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(systemBrightnessProvider.notifier).value =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  void updateViewSize(Size size) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(viewSizeProvider.notifier).value = size;
    });
  }
}

@Riverpod(keepAlive: true)
class ProxiesAction extends _$ProxiesAction {
  final Map<int, Future<void>> _runningUpdateGroups = {};

  late final ProviderReadinessService<ExternalProvider, Group>
  _providerReadiness = ProviderReadinessService(
    log: (stage, result, elapsed) {
      commonPrint.log(
        '$stage profileId=${result.profileId} elapsedMs=${elapsed.inMilliseconds} '
        'providerCount=${result.providerCount} groupCount=${result.groupCount} '
        'status=${result.status.name} lastError=${result.error ?? '-'}',
        logLevel:
            result.status == ProviderReadinessStatus.failed ||
                result.status == ProviderReadinessStatus.timeout ||
                result.status == ProviderReadinessStatus.coreUnavailable
            ? LogLevel.warning
            : LogLevel.info,
      );
    },
  );

  @override
  void build() {}

  Future<ProviderReadinessResult> ensureCurrentProfileReady({
    bool forceApply = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final profileId = ref.read(currentProfileIdProvider);
    ref.read(proxyGroupsSnapshotProvider.notifier).refreshing();
    if (profileId != null && !coreController.isCompleted) {
      final connected = await ref
          .read(coreActionProvider.notifier)
          .connectCore();
      if (ref.read(currentProfileIdProvider) != profileId) {
        return ProviderReadinessResult(
          status: ProviderReadinessStatus.profileChanged,
          profileId: profileId,
        );
      }
      if (!connected) {
        const error = ProviderReadinessCoreUnavailable();
        ref.read(proxyGroupsSnapshotProvider.notifier).failed(error);
        commonPrint.log(
          'provider-readiness:core-unavailable-before-config profileId=$profileId',
          logLevel: LogLevel.warning,
        );
        return ProviderReadinessResult(
          status: ProviderReadinessStatus.coreUnavailable,
          profileId: profileId,
          error: error,
        );
      }
    }
    final result = await _providerReadiness.ensureCurrentProfileReady(
      targetProfileId: profileId,
      currentProfileId: () => ref.read(currentProfileIdProvider),
      readProviderDefinitions: () async {
        if (profileId == null) return (external: false, proxy: false);
        return readProfileProviderDefinitions(profileId);
      },
      ensureCoreReady: _ensureCoreReadyForDisplay,
      applyProfileForDisplay: () =>
          ref.read(setupActionProvider.notifier).applyProfileForDisplay(),
      syncProviders: coreController.getExternalProviders,
      isProxyProvider: (provider) => provider.type.toLowerCase() == 'proxy',
      readGroups: _readRuntimeGroups,
      groupsAreValid: _isSnapshotWritableGroups,
      commitReady: (providers, groups) =>
          _commitReady(profileId, providers, groups),
      forceApply: forceApply,
      timeout: timeout,
    );
    if (ref.read(currentProfileIdProvider) != profileId) return result;
    switch (result.status) {
      case ProviderReadinessStatus.ready:
        break;
      case ProviderReadinessStatus.noProviders:
        ref.read(providersProvider.notifier).clear();
        await updateGroups();
        break;
      case ProviderReadinessStatus.timeout:
        ref
            .read(proxyGroupsSnapshotProvider.notifier)
            .failed(const ProviderReadinessTimeout());
        break;
      case ProviderReadinessStatus.coreUnavailable:
        ref
            .read(proxyGroupsSnapshotProvider.notifier)
            .failed(const ProviderReadinessCoreUnavailable());
        break;
      case ProviderReadinessStatus.failed:
        ref
            .read(proxyGroupsSnapshotProvider.notifier)
            .failed(result.error ?? StateError('Provider readiness failed'));
        break;
      case ProviderReadinessStatus.profileChanged:
        break;
    }
    return result;
  }

  Future<bool> _ensureCoreReadyForDisplay() async {
    return ref.read(coreActionProvider.notifier).ensureCoreReady();
  }

  Future<List<Group>> _readRuntimeGroups() {
    final sortType = ref.read(
      proxiesStyleSettingProvider.select((state) => state.sortType),
    );
    final delayMap = ref.read(delayDataSourceProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    final selectedMap = ref.read(
      currentProfileProvider.select((state) => state?.selectedMap ?? {}),
    );
    return coreController.getProxiesGroups(
      selectedMap: selectedMap,
      sortType: sortType,
      delayMap: delayMap,
      defaultTestUrl: testUrl,
    );
  }

  Future<void> _commitReady(
    int? profileId,
    List<ExternalProvider> providers,
    List<Group> groups,
  ) async {
    if (profileId == null ||
        ref.read(currentProfileIdProvider) != profileId ||
        !_isSnapshotWritableGroups(groups)) {
      return;
    }
    ref.read(providersProvider.notifier).value = providers;
    ref.read(groupsProvider.notifier).value = groups;
    ref.read(groupsOwnerProfileIdProvider.notifier).set(profileId);
    ref.read(lastGroupsRefreshAtProvider.notifier).update();
    ref.read(proxyGroupsSnapshotProvider.notifier).fresh();
    final profile = _findProfileById(profileId);
    if (profile != null) {
      await _putProxyGroupsSnapshot(profile: profile, groups: groups);
    }
    if (ref.read(currentProfileIdProvider) == profileId) {
      _syncComputedSelectedMap(groups);
    }
  }

  bool _groupsEqual(List<Group> a, List<Group> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final ga = a[i];
      final gb = b[i];
      if (ga.name != gb.name ||
          ga.type != gb.type ||
          ga.now != gb.now ||
          ga.hidden != gb.hidden ||
          ga.testUrl != gb.testUrl ||
          ga.icon != gb.icon ||
          ga.all.length != gb.all.length) {
        return false;
      }
      for (var j = 0; j < ga.all.length; j++) {
        if (ga.all[j].name != gb.all[j].name ||
            ga.all[j].type != gb.all[j].type) {
          return false;
        }
      }
    }
    return true;
  }

  void _syncComputedSelectedMap(List<Group> groups) {
    final base = ref.read(currentProfileProvider)?.computedSelectedMap ?? {};
    final map = ref
        .read(computedSelectedCacheProvider.notifier)
        .syncFromGroups(groups, base: base);
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentComputedSelectedMap(map);
  }

  void updateGroupsDebounce([Duration? duration]) {
    debouncer.call(FunctionTag.updateGroups, updateGroups, duration: duration);
  }

  void changeProxyDebounce(String groupName, String proxyName) {
    debouncer.call(FunctionTag.changeProxy, (
      String groupName,
      String proxyName,
    ) async {
      await changeProxy(groupName: groupName, proxyName: proxyName);
      updateGroupsDebounce();
    }, args: [groupName, proxyName]);
  }

  Future<String?> _computeProfileFingerprint(Profile? profile) async {
    if (profile == null) return null;

    // 读取 profile config 文件 SHA-256 作为主依据
    String profileFileSha256 = '';
    try {
      final path = await appPath.getProfilePath(profile.id.toString());
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        profileFileSha256 = sha256.convert(bytes).toString();
      }
    } catch (e) {
      commonPrint.log('compute profile file sha256 failed: $e');
    }

    // selectedMap 稳定排序后计算 SHA-256
    final selectedEntries = profile.selectedMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final selectedMapStableJson = jsonEncode(Map.fromEntries(selectedEntries));
    final selectedMapSha256 = sha256
        .convert(utf8.encode(selectedMapStableJson))
        .toString();

    final parts = <Object?>[
      'snapshot_v$kProxyGroupsSnapshotVersion',
      profile.id,
      profileFileSha256,
      profile.overwriteType.index,
      profile.scriptId ?? 0,
      profile.lastUpdateDate?.millisecondsSinceEpoch ?? 0,
      selectedMapSha256,
    ];

    return sha256.convert(utf8.encode(parts.join('|'))).toString();
  }

  Profile? _findProfileById(int profileId) {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<bool> hydrateProxyGroupsSnapshot({
    int? profileId,
    bool allowStaleOnFingerprintMismatch = false,
  }) async {
    final targetProfileId = profileId ?? ref.read(currentProfileIdProvider);
    if (targetProfileId == null) {
      ref.read(proxyGroupsSnapshotProvider.notifier).none();
      return false;
    }

    try {
      final snapshot = await database.proxyGroupsSnapshotsDao.getSnapshot(
        targetProfileId,
      );

      if (snapshot == null || snapshot.groups.isEmpty) {
        if (profileId == null) {
          ref.read(proxyGroupsSnapshotProvider.notifier).none();
        }
        return false;
      }

      // profileId guard（只在无参调用时校验）
      if (profileId == null &&
          ref.read(currentProfileProvider)?.id != targetProfileId) {
        return false;
      }

      // version compatibility check
      if (snapshot.snapshotVersion > kProxyGroupsSnapshotVersion) {
        commonPrint.log('snapshot version incompatible, discarding');
        ref.read(proxyGroupsSnapshotProvider.notifier).none();
        return false;
      }

      // fingerprint 校验：不匹配则丢弃 snapshot
      final profile = _findProfileById(targetProfileId);
      if (profile == null) {
        ref.read(proxyGroupsSnapshotProvider.notifier).none();
        return false;
      }
      final currentFingerprint = await _computeProfileFingerprint(profile);
      if (snapshot.profileFingerprint == null ||
          snapshot.profileFingerprint != currentFingerprint) {
        commonPrint.log(
          'snapshot fingerprint mismatch: profileId=$targetProfileId, '
          'allowStale=$allowStaleOnFingerprintMismatch',
          logLevel: allowStaleOnFingerprintMismatch
              ? LogLevel.warning
              : LogLevel.info,
        );
        if (!allowStaleOnFingerprintMismatch) {
          return false;
        }
      }

      ref.read(groupsProvider.notifier).value = snapshot.groups;
      ref.read(groupsOwnerProfileIdProvider.notifier).set(targetProfileId);
      ref
          .read(proxyGroupsSnapshotProvider.notifier)
          .stale(updatedAt: snapshot.updatedAt);
      return true;
    } catch (e) {
      commonPrint.log('hydrateProxyGroupsSnapshot failed: $e');
      ref.read(proxyGroupsSnapshotProvider.notifier).none();
      return false;
    }
  }

  bool _isSnapshotWritableGroups(List<Group> groups) {
    return groups.isNotEmpty && groups.every((g) => g.all.isNotEmpty);
  }

  Future<void> _putProxyGroupsSnapshot({
    required Profile profile,
    required List<Group> groups,
  }) async {
    if (!_isSnapshotWritableGroups(groups)) return;
    final fingerprint = await _computeProfileFingerprint(profile);
    if (fingerprint == null) return;
    await database.proxyGroupsSnapshotsDao.putSnapshot(
      profileId: profile.id,
      groups: groups,
      profileFingerprint: fingerprint,
    );
  }

  Future<void> updateGroups() {
    final profileId = ref.read(currentProfileProvider)?.id;
    if (profileId == null) {
      commonPrint.log('update-groups:skipped reason=no-profile');
      return Future.value();
    }
    final running = _runningUpdateGroups[profileId];
    if (running != null) {
      commonPrint.log('update-groups:reuse profileId=$profileId');
      return running;
    }
    final future = _updateGroups(profileId);
    _runningUpdateGroups[profileId] = future;
    future.whenComplete(() {
      if (identical(_runningUpdateGroups[profileId], future)) {
        _runningUpdateGroups.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _updateGroups(int profileId) async {
    final watch = Stopwatch()..start();

    try {
      ref.read(proxyGroupsSnapshotProvider.notifier).refreshing();

      commonPrint.log('update-groups:start profileId=$profileId');
      final coreReady = await _ensureCoreReadyForDisplay();
      if (!coreReady) {
        final ownerProfileId = ref.read(groupsOwnerProfileIdProvider);
        final oldGroups = ref.read(groupsProvider);
        final hasSameProfileOldGroups =
            ownerProfileId == profileId && oldGroups.isNotEmpty;

        if (hasSameProfileOldGroups) {
          ref
              .read(proxyGroupsSnapshotProvider.notifier)
              .failed('connectCore failed');
          return;
        }

        final hydrated = await hydrateProxyGroupsSnapshot(
          profileId: profileId,
          allowStaleOnFingerprintMismatch: true,
        );

        if (hydrated) {
          commonPrint.log(
            'updateGroups connectCore failed, fallback to stale snapshot: profileId=$profileId',
            logLevel: LogLevel.warning,
          );
          ref
              .read(proxyGroupsSnapshotProvider.notifier)
              .failed('connectCore failed');
          return;
        }

        commonPrint.log(
          'updateGroups preserve empty fallback: profileId=$profileId, '
          'reason=connectCore failed, ownerProfileId=$ownerProfileId, '
          'oldGroups=${oldGroups.length}',
          logLevel: LogLevel.warning,
        );

        ref
            .read(proxyGroupsSnapshotProvider.notifier)
            .failed('connectCore failed');
        return;
      }
      Future<List<Group>> loadGroups() {
        return retry(
          task: () async {
            final sortType = ref.read(
              proxiesStyleSettingProvider.select((state) => state.sortType),
            );
            final delayMap = ref.read(delayDataSourceProvider);
            final testUrl = ref.read(
              appSettingProvider.select((state) => state.testUrl),
            );
            final selectedMap = ref.read(
              currentProfileProvider.select(
                (state) => state?.selectedMap ?? {},
              ),
            );
            return coreController.getProxiesGroups(
              selectedMap: selectedMap,
              sortType: sortType,
              delayMap: delayMap,
              defaultTestUrl: testUrl,
            );
          },
          retryIf: (res) => res.isEmpty || res.any((g) => g.all.isEmpty),
        );
      }

      var groups = await loadGroups();
      if (!_isSnapshotWritableGroups(groups)) {
        await ref.read(setupActionProvider.notifier).applyProfileForDisplay();
        groups = await loadGroups();
      }

      if (!_isSnapshotWritableGroups(groups)) {
        final ownerProfileId = ref.read(groupsOwnerProfileIdProvider);
        final oldGroups = ref.read(groupsProvider);

        if (ownerProfileId == profileId && oldGroups.isNotEmpty) {
          commonPrint.log(
            'updateGroups groups empty, preserve same-profile old groups: '
            'profileId=$profileId, oldGroups=${oldGroups.length}',
            logLevel: LogLevel.warning,
          );
          ref.read(proxyGroupsSnapshotProvider.notifier).failed('groups empty');
          return;
        }

        final hydrated = await hydrateProxyGroupsSnapshot(
          profileId: profileId,
          allowStaleOnFingerprintMismatch: true,
        );

        if (hydrated) {
          commonPrint.log(
            'updateGroups groups empty, fallback to stale snapshot: '
            'profileId=$profileId',
            logLevel: LogLevel.warning,
          );
          ref.read(proxyGroupsSnapshotProvider.notifier).failed('groups empty');
          return;
        }

        commonPrint.log(
          'updateGroups groups empty, no old groups or snapshot fallback: '
          'profileId=$profileId, ownerProfileId=$ownerProfileId, '
          'oldGroups=${oldGroups.length}',
          logLevel: LogLevel.error,
        );

        ref.read(proxyGroupsSnapshotProvider.notifier).failed('groups empty');
        return;
      }

      // profileId guard: user may have switched profile during async refresh
      if (ref.read(currentProfileProvider)?.id != profileId) return;

      // Equality check: skip UI rebuild + snapshot save if groups unchanged
      final oldGroups = ref.read(groupsProvider);
      if (_groupsEqual(oldGroups, groups)) {
        ref.read(lastGroupsRefreshAtProvider.notifier).update();
        ref.read(groupsOwnerProfileIdProvider.notifier).set(profileId);
        ref.read(proxyGroupsSnapshotProvider.notifier).fresh();
        _syncComputedSelectedMap(groups);
        return;
      }

      ref.read(groupsProvider.notifier).value = groups;
      ref.read(groupsOwnerProfileIdProvider.notifier).set(profileId);
      ref.read(proxyGroupsSnapshotProvider.notifier).fresh();
      ref.read(lastGroupsRefreshAtProvider.notifier).update();

      // Save snapshot
      final currentProfile = ref.read(currentProfileProvider);
      if (currentProfile != null) {
        await _putProxyGroupsSnapshot(profile: currentProfile, groups: groups);
      }

      _syncComputedSelectedMap(groups);
    } catch (e) {
      commonPrint.log(
        'update-groups:error profileId=$profileId '
        'elapsedMs=${watch.elapsedMilliseconds} error=$e',
        logLevel: LogLevel.error,
      );

      final ownerProfileId = ref.read(groupsOwnerProfileIdProvider);
      final oldGroups = ref.read(groupsProvider);
      final hasSameProfileOldGroups =
          ownerProfileId == profileId && oldGroups.isNotEmpty;

      if (hasSameProfileOldGroups) {
        ref.read(proxyGroupsSnapshotProvider.notifier).failed(e);
        return;
      }

      final hydrated = await hydrateProxyGroupsSnapshot(
        profileId: profileId,
        allowStaleOnFingerprintMismatch: true,
      );

      if (hydrated) {
        commonPrint.log(
          'updateGroups error fallback to stale snapshot: profileId=$profileId, error=$e',
          logLevel: LogLevel.warning,
        );
        ref.read(proxyGroupsSnapshotProvider.notifier).failed(e);
        return;
      }

      commonPrint.log(
        'updateGroups failed without fallback: profileId=$profileId, '
        'ownerProfileId=$ownerProfileId, oldGroups=${oldGroups.length}, error=$e',
        logLevel: LogLevel.error,
      );

      ref.read(proxyGroupsSnapshotProvider.notifier).failed(e);
    } finally {
      final ownerProfileId = ref.read(groupsOwnerProfileIdProvider);
      final groupCount = ownerProfileId == profileId
          ? ref.read(groupsProvider).length
          : 0;
      commonPrint.log(
        'update-groups:completed profileId=$profileId '
        'elapsedMs=${watch.elapsedMilliseconds} groupCount=$groupCount '
        'currentProfileId=${ref.read(currentProfileIdProvider)}',
      );
    }
  }

  final _prefetchingProfileIds = <int>{};

  Future<void> prefetchSnapshotForProfile(Profile profile) async {
    if (!_prefetchingProfileIds.add(profile.id)) return;
    try {
      final fingerprint = await _computeProfileFingerprint(profile);
      if (fingerprint == null) return;

      final sortType = ref.read(
        proxiesStyleSettingProvider.select((state) => state.sortType),
      );
      final delayMap = ref.read(delayDataSourceProvider);
      final testUrl = ref.read(
        appSettingProvider.select((state) => state.testUrl),
      );

      final profilePath = await appPath.getProfilePath(profile.id.toString());

      final groups = await coreController.materializeProfileSnapshotGroups(
        profilePath: profilePath,
        selectedMap: profile.selectedMap,
        sortType: sortType,
        delayMap: delayMap,
        defaultTestUrl: testUrl,
      );

      if (!_isSnapshotWritableGroups(groups)) return;

      final latestProfile = _findProfileById(profile.id);
      if (latestProfile == null) return;

      final latestFingerprint = await _computeProfileFingerprint(latestProfile);
      if (fingerprint != latestFingerprint) {
        commonPrint.log(
          'prefetchSnapshotForProfile skipped: fingerprint changed '
          'profileId=${profile.id}',
        );
        return;
      }

      await _putProxyGroupsSnapshot(profile: latestProfile, groups: groups);

      commonPrint.log(
        'prefetchSnapshotForProfile success: '
        'profileId=${profile.id}, groups=${groups.length}',
      );
    } catch (e) {
      commonPrint.log('prefetchSnapshotForProfile failed: $e');
    } finally {
      _prefetchingProfileIds.remove(profile.id);
    }
  }

  DateTime? _lastPreheatGroupsRefreshAt;

  Future<void> preheatComputedGroups() async {
    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) return;
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    try {
      await warmUpComputedGroupDelays(
        groups: groups,
        defaultTestUrl: testUrl,
        delayLoader: coreController.getDelay,
        onDelay: setDelay,
      );
      // Throttle: skip if last refresh was < 5s ago
      final now = DateTime.now();
      if (_lastPreheatGroupsRefreshAt != null &&
          now.difference(_lastPreheatGroupsRefreshAt!) <
              const Duration(seconds: 5)) {
        return;
      }
      _lastPreheatGroupsRefreshAt = now;
      updateGroupsDebounce();
    } catch (e) {
      commonPrint.log('preheatComputedGroups error: $e');
    }
  }

  void updateCurrentGroupName(String groupName) {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.currentGroupName == groupName) return;
    ref
        .read(profilesProvider.notifier)
        .put(profile.copyWith(currentGroupName: groupName));
  }

  void updateCurrentUnfoldSet(Set<String> value) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;
    ref
        .read(profilesProvider.notifier)
        .put(currentProfile.copyWith(unfoldSet: value));
  }

  void setDelay(Delay delay) {
    ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    await coreController.changeProxy(
      ChangeProxyParams(groupName: groupName, proxyName: proxyName),
    );
    if (ref.read(appSettingProvider).closeConnections) {
      await coreController.closeConnections();
    } else {
      await coreController.resetConnections();
    }
    ref.read(checkIpNumProvider.notifier).add();
  }

  Future<String> updateProvider(
    ExternalProvider provider, {
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(provider.updatingKey).notifier).value =
            true;
      }
      final message = await coreController.updateExternalProvider(
        providerName: provider.name,
      );
      if (message.isNotEmpty) return message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await coreController.getExternalProvider(provider.name));
      return '';
    } finally {
      ref.read(isUpdatingProvider(provider.updatingKey).notifier).value = false;
    }
  }
}

@Riverpod(keepAlive: true)
class ProfilesAction extends _$ProfilesAction {
  @override
  void build() {}

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final selectedMap = Map<String, String>.from(currentProfile.selectedMap)
        ..[groupName] = proxyName;
      ref
          .read(profilesProvider.notifier)
          .put(currentProfile.copyWith(selectedMap: selectedMap));
    }
  }

  void updateCurrentComputedSelectedMap(
    Map<String, String> computedSelectedMap,
  ) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;
    final next = Map<String, String>.from(computedSelectedMap);
    final current = currentProfile.computedSelectedMap;
    final sameLength = current.length == next.length;
    final sameContent =
        sameLength && current.entries.every((e) => next[e.key] == e.value);
    if (sameContent) return;
    ref
        .read(profilesProvider.notifier)
        .put(currentProfile.copyWith(computedSelectedMap: next));
  }

  Future<void> deleteProfile(int id) async {
    ref.read(profilesProvider.notifier).del(id);
    clearEffect(id);
    final currentProfileId = ref.read(currentProfileIdProvider);
    if (currentProfileId == id) {
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        ref.read(currentProfileIdProvider.notifier).value = updateId;
      } else {
        ref.read(currentProfileIdProvider.notifier).value = null;
        ref.read(setupActionProvider.notifier).updateStatus(false);
      }
    }
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(profile.autoUpdateDuration)
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString(), logLevel: LogLevel.warning);
      }
    }
  }

  void putProfile(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (ref.read(currentProfileIdProvider) != null) return;
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<void> updateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) continue;
      await updateProfile(profile);
    }
  }

  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = true;
      }
      ref.read(profilesProvider.notifier).put(profile);
      final newProfile = await profile.update();
      ref.read(profilesProvider.notifier).put(newProfile);
      if (newProfile.id == ref.read(currentProfileIdProvider)) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
      } else {
        // 非活跃 profile：异步预热快照
        unawaited(
          ref
              .read(proxiesActionProvider.notifier)
              .prefetchSnapshotForProfile(newProfile),
        );
      }
    } finally {
      ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = false;
    }
  }

  Future<void> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    final bytes = platformFile?.bytes;
    if (bytes == null) return;
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    ref.read(currentPageLabelProvider.notifier).toProfiles();
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return Profile.normal(label: platformFile?.name).saveFile(bytes);
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  Future<void> addProfileFormURL(
    String url, {
    String? label,
    bool autoUpdate = true,
    Duration autoUpdateDuration = defaultUpdateDuration,
  }) async {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        final normalizedLabel = label?.trim();
        final profile =
            Profile.normal(
              url: url,
              label: normalizedLabel?.isNotEmpty == true
                  ? normalizedLabel
                  : null,
            ).copyWith(
              autoUpdate: autoUpdate,
              autoUpdateDuration: autoUpdateDuration,
            );
        return profile.update();
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  void setProfileAndAutoApply(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (profile.id == ref.read(currentProfileIdProvider)) {
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    }
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    addProfileFormURL(url);
  }

  void reorder(List<Profile> profiles) {
    ref.read(profilesProvider.notifier).reorder(profiles);
  }

  Future<void> clearEffect(int profileId) async {
    final profilePath = await appPath.getProfilePath(profileId.toString());
    final providersDirPath = await appPath.getProvidersDirPath(
      profileId.toString(),
    );
    final profileFile = File(profilePath);
    final isExists = await profileFile.exists();
    if (isExists) {
      await profileFile.safeDelete(recursive: true);
    }
    await coreController.deleteFile(providersDirPath);
  }
}
