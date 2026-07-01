import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'generated/action.g.dart';

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
    final traffic = await coreController.getTraffic(onlyStatisticsProxy);
    ref.read(trafficsProvider.notifier).addTraffic(traffic);
    ref.read(totalTrafficProvider.notifier).value = await coreController
        .getTotalTraffic(onlyStatisticsProxy);
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
          icon: Icons.verified_rounded,
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
          throw '请允许 SlClash 安装未知应用后，再次点击安装更新。';
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
    final textTheme = context.textTheme;
    return CommonDialog(
      title: '下载更新',
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
                            Icons.download_rounded,
                            size: 18,
                            color: surge.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        percent == null ? '正在下载 APK' : '正在下载 APK · $percent%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        strutStyle: const StrutStyle(
                          forceStrutHeight: true,
                          height: 1.2,
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          color: surge.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0,
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
                '下载完成后将自动打开系统安装界面。',
                style: textTheme.bodySmall?.copyWith(
                  color: surge.textSecondary,
                  height: 1.35,
                  letterSpacing: 0,
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
    final textTheme = context.textTheme;
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
                Icon(
                  Icons.new_releases_rounded,
                  color: surge.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tagName.takeFirstValid(['新版本']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    strutStyle: const StrutStyle(
                      forceStrutHeight: true,
                      height: 1.2,
                    ),
                    style: textTheme.titleMedium?.copyWith(
                      color: surge.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: 0,
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
            submitLabel: '下载',
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
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: surge.textPrimary,
                      height: 1.35,
                      letterSpacing: 0,
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
            style: context.textTheme.bodySmall?.copyWith(
              color: surge.textSecondary,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  static const _dashboardStatsInterval = Duration(seconds: 1);
  static const _backgroundPageStatsInterval = Duration(seconds: 3);

  Timer? _updateTimer;
  DateTime? startTime;
  bool _isUpdatingUiStats = false;

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

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    return SetupParams(selectedMap: selectedMap, testUrl: testUrl);
  }

  void fullSetup() {
    if (!ref.read(initProvider)) return;
    ref.read(delayDataSourceProvider.notifier).value = {};
    applyProfile(force: true);
    ref.read(logsProvider.notifier).value = FixedList(500);
    ref.read(requestsProvider.notifier).value = FixedList(500);
  }

  Future<void> _handleStart() async {
    startTime ??= DateTime.now();
    //The local status must be updated when performing the run task
    unawaited(_updateUiStats());
    if (!ref.read(suspendProvider)) {
      await coreController.startListener();
    }
    _startUiStatsTimer();
  }

  Duration get _uiStatsInterval {
    final isDashboard =
        ref.read(currentPageLabelProvider) == PageLabel.dashboard;
    return isDashboard ? _dashboardStatsInterval : _backgroundPageStatsInterval;
  }

  Future<void> _updateUiStats() async {
    ref.read(commonActionProvider.notifier).updateRunTime();
    if (_isUpdatingUiStats) return;
    _isUpdatingUiStats = true;
    try {
      await ref.read(commonActionProvider.notifier).updateTraffic();
    } catch (e) {
      commonPrint.log('update ui stats failed: $e', logLevel: LogLevel.warning);
    } finally {
      _isUpdatingUiStats = false;
    }
  }

  void _startUiStatsTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_uiStatsInterval, (_) {
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
    final status = isStart == true
        ? true
        : ref.read(appSettingProvider).autoRun;
    if (status == true) {
      await updateStatus(true, isInit: true);
    } else {
      await applyProfile(force: true);
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
        await _handleStart();
        applyProfileDebounce(force: true, silence: true);
      } else {
        globalState.needInitStatus = false;
        ref.read(runTimeProvider.notifier).value = 0;
        try {
          await applyProfile(
            force: true,
            preloadInvoke: () async {
              await _handleStart();
            },
          );
        } catch (_) {
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
    final isTimeout = ref.read(
      networkDetectionProvider.select(
        (state) => state.ipInfo == null && state.isLoading == false,
      ),
    );
    if (!isTimeout) return;
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

  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    VoidCallback? preloadInvoke,
  }) async {
    await _setupConfig(
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

  Future<void> _setupConfig({
    bool force = false,
    bool silence = false,
    VoidCallback? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    var profile = ref.read(currentProfileProvider);
    final nextProfile = await profile?.checkAndUpdateAndCopy();
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    commonPrint.log('setup ===> ${profile?.id}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final res = await _requestAdmin(patchConfig.tun.enable);
    if (res.isError) return;
    final realTunEnable = ref.read(realTunEnableProvider);
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
    if (yamlMd5 == globalState.lastConfigMd5 && force == false) return;
    await globalState.loadingRun(
      () async {
        final configFilePath = await appPath.configFilePath;
        await File(configFilePath).safeWriteAsString(yamlString);
        globalState.lastConfigMd5 = yamlMd5;
        final message = await coreController.setupConfig(
          setupState: setupState,
          params: _setupParams,
          preloadInvoke: preloadInvoke,
        );
        if (message.isNotEmpty && !message.endsWith('is empty')) {
          throw message;
        }
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
  }
}

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  Future<String> backup() async {
    final profileFileNames = await database.profilesDao.fileNames().get();
    final profiles = ref.read(profilesProvider);
    final currentProfileId = ref.read(currentProfileIdProvider);
    final appVersion = ref.read(versionProvider).toString();
    final profilesJson = profiles.map((p) {
      final json = p.toJson();
      // Remove fields that depend on external data
      json.remove('scriptId');
      json.remove('overwriteType');
      return json;
    }).toList();
    return backupProfilesOnlyTask(
      profilesJson,
      profileFileNames,
      currentProfileId,
      appVersion,
    );
  }

  Future<void> restore() async {
    final restoreDirPath = await appPath.restoreDirPath;
    final restoreDir = Directory(restoreDirPath);
    final restoreStrategy = ref.read(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    try {
      final restoreData = await restoreProfilesOnlyTask();
      if (!await restoreDir.exists()) {
        throw currentAppLocalizations.restoreException;
      }
      // Clean profiles: remove scriptId and overwriteType
      final profiles = restoreData.profiles.map((p) {
        final map = Map<String, dynamic>.from(p);
        map['scriptId'] = null;
        map['overwriteType'] = OverwriteType.standard.name;
        return map;
      }).toList();
      // Convert to Profile objects
      final profileList = <Profile>[];
      for (final p in profiles) {
        try {
          profileList.add(Profile.fromJson(p));
        } catch (_) {}
      }
      // Restore to database
      final isOverride = restoreStrategy == RestoreStrategy.override;
      await database.restoreProfilesOnly(profileList, isOverride: isOverride);
      // Restore currentProfileId
      final restoredIds = profileList.map((p) => p.id).toSet();
      final requestedId = restoreData.currentProfileId;
      if (requestedId != null && restoredIds.contains(requestedId)) {
        ref.read(currentProfileIdProvider.notifier).value = requestedId;
      } else if (profileList.isNotEmpty) {
        ref.read(currentProfileIdProvider.notifier).value =
            profileList.first.id;
      }
    } finally {
      await restoreDir.safeDelete(recursive: true);
    }
  }
}

@Riverpod(keepAlive: true)
class CoreAction extends _$CoreAction {
  @override
  void build() {}

  Future<void> initCore() async {
    final isInit = await coreController.isInit;

    final version = ref.read(versionProvider);
    if (!isInit) {
      final res = await coreController.init(version);
      commonPrint.log('init result: $res');
    } else {
      await ref.read(proxiesActionProvider.notifier).updateGroups();
    }
  }

  Future<void> connectCore() async {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    final result = await Future.wait([
      coreController.preload(),
      Future.delayed(const Duration(milliseconds: 300)),
    ]);
    final String message = result[0];
    if (message.isNotEmpty) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      globalState.showNotifier(message);
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
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

  Future<void> restartCore([bool start = false]) async {
    final isDisconnected =
        ref.read(coreStatusProvider) == CoreStatus.disconnected;
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await coreController.shutdown(!isDisconnected);
    await connectCore();
    await initCore();
    if (start || ref.read(isStartProvider)) {
      await ref
          .read(setupActionProvider.notifier)
          .updateStatus(true, isInit: true);
    } else {
      await ref.read(setupActionProvider.notifier).applyProfile(force: true);
    }
  }

  Future<bool> tryStartCore([bool start = false]) async {
    if (coreController.isCompleted) return false;
    await restartCore(start);
    return true;
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
  @override
  void build() {}

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

  Future<void> updateGroups() async {
    try {
      commonPrint.log('updateGroups');
      ref.read(groupsProvider.notifier).value = await retry(
        task: () async {
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
        },
        retryIf: (res) => res.isEmpty || res.any((g) => g.all.isEmpty),
      );
    } catch (e) {
      commonPrint.log('updateGroups error: $e');
      ref.read(groupsProvider.notifier).value = [];
    }
    // Sync computed group cache from the updated groups list.
    // This ensures the UI-only cache reflects the latest runtime state,
    // including after core restarts that reset computed group `now`.
    ref.read(computedSelectedCacheProvider.notifier)
        .syncFromGroups(ref.read(groupsProvider));
  }

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
      if (profile.id == ref.read(currentProfileIdProvider)) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
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
