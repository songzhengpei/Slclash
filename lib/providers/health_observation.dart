import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/health_observation.g.dart';

/// Immutable state snapshot for the health observation scheduler.
class HealthObservationSchedulerState {
  const HealthObservationSchedulerState({
    this.lastAttemptAt,
    this.lastCompletedAt,
    this.lastSkippedReason,
    this.isObserving = false,
    this.enabled = false,
    this.intervalMinutes = 10,
    this.nextEligibleAt,
    this.triggerGeneration = 0,
    this.totalObservations = 0,
    this.successfulObservations = 0,
    this.skippedObservations = 0,
  });

  /// Last time the scheduler attempted an observation (any outcome).
  final DateTime? lastAttemptAt;

  /// Last time an observation completed successfully.
  final DateTime? lastCompletedAt;

  /// Reason for the most recent skip, if any.
  final String? lastSkippedReason;

  /// Whether an observation run is currently in progress.
  final bool isObserving;

  /// Whether health observation is enabled.
  final bool enabled;

  /// Configured observation interval in minutes.
  final int intervalMinutes;

  /// Earliest time the next observation is eligible.
  final DateTime? nextEligibleAt;

  /// Incremented each time a new observation is triggered.
  final int triggerGeneration;

  /// Total observation attempts made.
  final int totalObservations;

  /// Successful observations.
  final int successfulObservations;

  /// Skipped observations (environment not available).
  final int skippedObservations;

  bool get isDue {
    if (nextEligibleAt == null) return true;
    return DateTime.now().isAfter(nextEligibleAt!);
  }

  HealthObservationSchedulerState copyWith({
    DateTime? lastAttemptAt,
    DateTime? lastCompletedAt,
    String? lastSkippedReason,
    bool? isObserving,
    bool? enabled,
    int? intervalMinutes,
    DateTime? nextEligibleAt,
    int? triggerGeneration,
    int? totalObservations,
    int? successfulObservations,
    int? skippedObservations,
    bool clearSkipReason = false,
    bool clearNextEligibleAt = false,
  }) {
    return HealthObservationSchedulerState(
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastSkippedReason: clearSkipReason
          ? null
          : (lastSkippedReason ?? this.lastSkippedReason),
      isObserving: isObserving ?? this.isObserving,
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      nextEligibleAt: clearNextEligibleAt
          ? null
          : (nextEligibleAt ?? this.nextEligibleAt),
      triggerGeneration: triggerGeneration ?? this.triggerGeneration,
      totalObservations: totalObservations ?? this.totalObservations,
      successfulObservations:
          successfulObservations ?? this.successfulObservations,
      skippedObservations: skippedObservations ?? this.skippedObservations,
    );
  }
}

@visibleForTesting
Duration? healthObservationOneShotDelay({
  required bool enabled,
  required DateTime now,
  DateTime? nextEligibleAt,
  Duration? retryDelay,
}) {
  if (!enabled) return null;
  if (retryDelay != null) return retryDelay;
  final next = nextEligibleAt;
  if (next == null || !next.isAfter(now)) return Duration.zero;
  return next.difference(now);
}

@visibleForTesting
int healthObservationWorkerCount({
  required int eligibleProxyCount,
  required bool appForeground,
  bool cellular = false,
  bool screenOn = true,
  bool powerSaveMode = false,
}) {
  if (eligibleProxyCount <= 0 || powerSaveMode) return 0;
  if (!screenOn || cellular) return 1;
  final maxWorkers = appForeground ? 5 : 2;
  return math.min(maxWorkers, eligibleProxyCount);
}

/// App-level health observation scheduler.
///
/// Runs independently of widget lifecycle, page visibility, and VPN state.
/// Uses a one-shot timer scheduled to the next eligible observation time.
/// Actual observation interval is user-configured (default 10 min).
///
/// **nextEligibleAt policy (fix: not advanced before execution)**
/// - Successful observation: advance by full [intervalMinutes].
/// - Core / profile / group temporarily unavailable: short retry (1–5 min).
/// - Already running: short retry (1 min).
///
/// **Health result persistence**
/// Results from app-level observations are written to [MediaCheckCache]
/// via [MediaCheckCacheStore], the same store used by the page-level UI.
/// This ensures historical-stable-node calculations reflect both sources.
@Riverpod(keepAlive: true)
class HealthObservationScheduler extends _$HealthObservationScheduler {
  static const _idleDelay = Duration(seconds: 30);
  static const _idleRetryDelay = Duration(seconds: 30);
  static const _mediaCheckTimeout = Duration(seconds: 15);
  static const _observeSettingsKey = 'media-check-observe-settings-v1';

  // ── Retry intervals for different skip reasons ─────────────────────────
  static const _retryCoreUnavailable = Duration(minutes: 2);
  static const _retryNoProfile = Duration(minutes: 3);
  static const _retryNoProxies = Duration(minutes: 5);
  static const _retryNoNetwork = Duration(minutes: 2);

  Timer? _timer;
  DateTime? _appStartedAt;
  DateTime? _lastLifecycleChangeAt;
  bool _engineReady = false;
  final _cacheStore = MediaCheckCacheStore();

  @override
  HealthObservationSchedulerState build() {
    _appStartedAt ??= DateTime.now();
    _lastLifecycleChangeAt ??= DateTime.now();

    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    _loadSettings();

    // ── Reactive triggers ──────────────────────────────────────────────

    // 1. Smart-auto-stop changes should not block observation; if overdue,
    // request a near-term run so the cache reflects the current network.
    ref.listen(isSmartStoppedProvider, (prev, next) {
      if (prev != next && isOverdue) {
        requestSoon();
      }
    });

    // 2. App returns to foreground + observation is overdue → request soon.
    ref.listen(appForegroundProvider, (prev, next) {
      if (prev == false && next == true && isOverdue) {
        requestSoon();
      }
    });

    // 3. Core reconnects (network recovery / VPN restored) + overdue → request soon.
    ref.listen(coreStatusProvider, (prev, next) {
      if (prev != CoreStatus.connected &&
          next == CoreStatus.connected &&
          isOverdue) {
        requestSoon();
      }
    });

    return const HealthObservationSchedulerState();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleNext({Duration? retryDelay}) {
    _cancelTimer();
    if (!_engineReady || state.isObserving) {
      return;
    }
    final delay = healthObservationOneShotDelay(
      enabled: state.enabled,
      now: DateTime.now(),
      nextEligibleAt: state.nextEligibleAt,
      retryDelay: retryDelay,
    );
    if (delay == null) return;
    _timer = Timer(delay, _onTick);
  }

  /// Reload scheduler settings from preferences (enabled, intervalMinutes).
  Future<void> _loadSettings() async {
    try {
      final raw = await preferences.getString(_observeSettingsKey);
      if (raw == null || raw.isEmpty) {
        _scheduleNext();
        return;
      }
      final settings = MediaCheckObserveSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (state.enabled != settings.enabled ||
          state.intervalMinutes != settings.intervalMinutes) {
        state = state.copyWith(
          enabled: settings.enabled,
          intervalMinutes: settings.intervalMinutes,
        );
      }
      _scheduleNext();
    } catch (_) {
      // Ignore parse errors — keep current settings
      _scheduleNext();
    }
  }

  /// Called by the one-shot timer when the scheduler should check whether an
  /// observation can run.
  void _onTick() {
    _timer = null;
    if (!_engineReady) return;
    final s = state;
    if (!s.enabled) return;
    if (s.isObserving) return;
    if (!s.isDue) {
      _scheduleNext();
      return;
    }
    if (!_isIdle()) {
      _scheduleNext(retryDelay: _idleRetryDelay);
      return;
    }

    _triggerObservation();
  }

  /// Checks idle conditions (any is sufficient):
  /// 1. App in background for >=30s
  /// 2. App in foreground with no user interaction for >=30s
  /// 3. App started >=30s ago with no interaction yet
  bool _isIdle() {
    final now = DateTime.now();
    final isForeground = ref.read(appForegroundProvider);
    final lastInteraction = ref.read(lastUserInteractionAtProvider);

    // Condition 1: background for >=30s
    if (!isForeground) {
      if (_lastLifecycleChangeAt != null &&
          now.difference(_lastLifecycleChangeAt!) >= _idleDelay) {
        return true;
      }
    }

    // Condition 2: foreground with no interaction for >=30s
    if (isForeground && lastInteraction != null) {
      if (now.difference(lastInteraction) >= _idleDelay) {
        return true;
      }
    }

    // Condition 3: app started >=30s ago with no interaction yet
    if (lastInteraction == null &&
        _appStartedAt != null &&
        now.difference(_appStartedAt!) >= _idleDelay) {
      return true;
    }

    return false;
  }

  /// Initiate an observation run.
  ///
  /// Sets isObserving immediately to prevent concurrent runs, but does NOT
  /// advance nextEligibleAt here — that decision is deferred to
  /// [_completeObservation] so that skips receive a short retry instead of
  /// the full interval.
  void _triggerObservation() {
    state = state.copyWith(
      lastAttemptAt: DateTime.now(),
      isObserving: true,
      triggerGeneration: state.triggerGeneration + 1,
      totalObservations: state.totalObservations + 1,
      clearSkipReason: true,
    );

    _performObservation();
  }

  /// Execute the health observation batch.
  ///
  /// 1. Resolves target profile (from persisted selection or current active).
  /// 2. Loads runtime ProxiesData and enumerates all real leaf proxies.
  /// 3. Tests every non-cooled proxy via coreController.mediaCheck() in
  ///    healthOnly mode.
  /// 4. Parses each result and writes to [MediaCheckCache] via
  ///    [MediaCheckCacheStore] so historical-stable-node data stays current.
  ///
  /// Environment unavailability is recorded as a skip with a short retry —
  /// it does NOT pollute node health scores and does NOT push the next
  /// observation far into the future.
  Future<void> _performObservation() async {
    // ── Pre-checks ──────────────────────────────────────────────────────
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus != CoreStatus.connected) {
      _completeObservation(skipReason: 'coreUnavailable');
      return;
    }

    // ── Resolve target profile ──────────────────────────────────────────
    final selectedProfileId = ref.read(mediaCheckSelectedProfileIdProvider);
    Profile? profile;

    if (selectedProfileId != null) {
      profile = _findProfileById(selectedProfileId);
    }
    profile ??= ref.read(currentProfileProvider);

    if (profile == null) {
      _completeObservation(skipReason: 'noSelectedProfile');
      return;
    }

    // ── Load runtime leaf proxies ───────────────────────────────────────
    List<Proxy> allProxies;
    try {
      allProxies = await coreController.getRuntimeLeafProxies();
    } catch (_) {
      _completeObservation(skipReason: 'coreUnavailable');
      return;
    }

    if (allProxies.isEmpty) {
      _completeObservation(skipReason: 'noProxies');
      return;
    }

    // ── Load current cache for merging health results ───────────────────
    MediaCheckCache cache;
    try {
      cache = await _cacheStore.load();
    } catch (_) {
      cache = const MediaCheckCache(entries: {});
    }

    final targetProfile = profile;
    final eligibleProxies = allProxies.where((proxy) {
      final entry = cache.entries['${targetProfile.id}::${proxy.name}'];
      return entry == null || !entry.isObservationCoolingDown();
    }).toList();

    if (eligibleProxies.isEmpty) {
      _completeObservation(success: true);
      return;
    }
    final workerCount = healthObservationWorkerCount(
      eligibleProxyCount: eligibleProxies.length,
      appForeground: ref.read(appForegroundProvider),
    );

    if (workerCount <= 0) {
      _completeObservation(skipReason: 'observationPaused');
      return;
    }

    // ── Test all eligible proxies with bounded concurrency ──────────────
    var observedCount = 0;
    var nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < eligibleProxies.length) {
        final proxy = eligibleProxies[nextIndex++];
        final proxyName = proxy.name;
        MediaCheckResult result;
        String? rawResult;
        String? error;

        try {
          rawResult = await coreController
              .mediaCheck(
                proxyName,
                profileId: targetProfile.id,
                healthOnly: true,
                mode: 'health',
              )
              .timeout(_mediaCheckTimeout);
        } catch (e) {
          error = '$e';
        }

        if (rawResult != null && rawResult.isNotEmpty) {
          try {
            result =
                MediaCheckResult.fromJson(
                  json.decode(rawResult) as Map<String, dynamic>,
                ).copyWith(
                  profileId: targetProfile.id,
                  profileLabel: targetProfile.realLabel,
                );
          } catch (e) {
            result = MediaCheckResult.failed(
              proxyName,
              '$e',
              profileId: targetProfile.id,
              profileLabel: targetProfile.realLabel,
            );
          }
        } else {
          result = MediaCheckResult.failed(
            proxyName,
            error ?? 'empty result',
            profileId: targetProfile.id,
            profileLabel: targetProfile.realLabel,
          );
        }

        cache = cache.addHealthResult(
          key: '${targetProfile.id}::$proxyName',
          profileId: targetProfile.id,
          profileLabel: targetProfile.realLabel,
          proxyName: proxyName,
          result: result,
        );
        observedCount++;
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    // ── Persist updated cache ───────────────────────────────────────────
    if (observedCount > 0) {
      try {
        await _cacheStore.save(cache);
      } catch (_) {
        // Persistence failure is non-fatal; health data is already
        // collected and will be written on the next successful run.
      }
    }

    _completeObservation(success: observedCount > 0);
  }

  /// Find a [Profile] by [id] from the profiles provider.
  Profile? _findProfileById(int id) {
    final profiles = ref.read(profilesProvider);
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Finalize the observation attempt.
  ///
  /// **nextEligibleAt policy (the key fix):**
  /// - Success: advance by full [intervalMinutes].
  /// - Skip with known reason: short retry based on reason type.
  /// - Ran but all proxies failed: short retry (network may be down).
  void _completeObservation({bool success = false, String? skipReason}) {
    final now = DateTime.now();

    if (skipReason != null) {
      final retryAfter = _retryForSkipReason(skipReason);
      state = state.copyWith(
        isObserving: false,
        lastSkippedReason: skipReason,
        skippedObservations: state.skippedObservations + 1,
        nextEligibleAt: now.add(retryAfter),
      );
    } else if (success) {
      state = state.copyWith(
        isObserving: false,
        lastCompletedAt: now,
        successfulObservations: state.successfulObservations + 1,
        nextEligibleAt: now.add(Duration(minutes: state.intervalMinutes)),
        clearSkipReason: true,
      );
    } else {
      // Observation ran but all proxy checks failed.
      // Retry sooner — the network or core may be temporarily degraded.
      state = state.copyWith(
        isObserving: false,
        nextEligibleAt: now.add(_retryNoNetwork),
      );
    }
    _scheduleNext();
  }

  /// Map a skip reason to its retry duration.
  Duration _retryForSkipReason(String reason) {
    return switch (reason) {
      'coreUnavailable' => _retryCoreUnavailable,
      'noSelectedProfile' => _retryNoProfile,
      'noProxies' => _retryNoProxies,
      _ => _retryNoNetwork, // fallback
    };
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Must be called once the app has fully initialized.
  void markEngineReady() {
    _engineReady = true;
    _scheduleNext();
  }

  /// Update the enabled flag.
  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    _scheduleNext();
  }

  /// Update the observation interval (minutes).
  void setIntervalMinutes(int minutes) {
    state = state.copyWith(intervalMinutes: minutes);
    _scheduleNext();
  }

  /// Called by AppStateManager on lifecycle change to track background time.
  void onLifecycleChanged(DateTime timestamp) {
    _lastLifecycleChangeAt = timestamp;
  }

  /// Make the next observation eligible immediately.
  ///
  /// Use this when:
  /// - Smart auto stop resumes (VPN restored).
  /// - App returns to foreground and observation is overdue.
  /// - Network changes and observation is overdue.
  void requestSoon() {
    state = state.copyWith(nextEligibleAt: DateTime.now());
    _scheduleNext();
  }

  /// Make the next observation eligible immediately (stronger signal).
  /// Sets nextEligibleAt to null so isDue returns true unconditionally.
  void markDue() {
    state = state.copyWith(clearNextEligibleAt: true);
    _scheduleNext();
  }

  /// Whether the scheduler's last successful observation is overdue
  /// (elapsed > intervalMinutes since lastCompletedAt).
  bool get isOverdue {
    final last = state.lastCompletedAt;
    if (last == null) return true;
    final elapsed = DateTime.now().difference(last);
    return elapsed.inMinutes >= state.intervalMinutes;
  }

  /// Get current state snapshot for display.
  HealthObservationSchedulerState get currentState => state;
}
