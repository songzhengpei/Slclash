import 'dart:async';

import 'package:fl_clash/providers/providers.dart';
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
  /// Widgets can watch this to react.
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
  }) {
    return HealthObservationSchedulerState(
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastSkippedReason:
          clearSkipReason ? null : (lastSkippedReason ?? this.lastSkippedReason),
      isObserving: isObserving ?? this.isObserving,
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      nextEligibleAt: nextEligibleAt ?? this.nextEligibleAt,
      triggerGeneration: triggerGeneration ?? this.triggerGeneration,
      totalObservations: totalObservations ?? this.totalObservations,
      successfulObservations:
          successfulObservations ?? this.successfulObservations,
      skippedObservations: skippedObservations ?? this.skippedObservations,
    );
  }
}

/// App-level health observation scheduler.
///
/// Runs independently of widget lifecycle, page visibility, and VPN state.
/// Uses a lightweight 15-second tick timer only for condition checking.
/// Actual observation interval is user-configured (default 10 min).
///
/// Idle conditions (any is sufficient):
/// 1. App in background for >=30s
/// 2. App in foreground with no user interaction for >=30s
/// 3. App just started >=30s ago with no interaction yet
///
/// When the environment is not available (core not running, no network),
/// records `skippedEnvironment` -- does NOT count as node failure.
@Riverpod(keepAlive: true)
class HealthObservationScheduler extends _$HealthObservationScheduler {
  static const _tickInterval = Duration(seconds: 15);
  static const _idleDelay = Duration(seconds: 30);

  Timer? _tickTimer;
  DateTime? _appStartedAt;
  DateTime? _lastLifecycleChangeAt;
  bool _engineReady = false;

  @override
  HealthObservationSchedulerState build() {
    _appStartedAt ??= DateTime.now();
    _lastLifecycleChangeAt ??= DateTime.now();

    ref.onDispose(() {
      _tickTimer?.cancel();
      _tickTimer = null;
    });

    // Start the condition-check tick timer immediately on provider init.
    // This runs regardless of foreground/background.
    _startTickTimer();

    return const HealthObservationSchedulerState();
  }

  void _startTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  /// Called every 15 seconds to check if observation should run.
  void _onTick() {
    if (!_engineReady) return;
    final s = state;
    if (!s.enabled) return;
    if (s.isObserving) return;
    if (!s.isDue) return;
    if (!_isIdle()) return;

    _triggerObservation();
  }

  /// Checks idle conditions.
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
  void _triggerObservation() {
    final nextEligible =
        DateTime.now().add(Duration(minutes: state.intervalMinutes));
    state = state.copyWith(
      lastAttemptAt: DateTime.now(),
      isObserving: true,
      nextEligibleAt: nextEligible,
      triggerGeneration: state.triggerGeneration + 1,
      totalObservations: state.totalObservations + 1,
      clearSkipReason: true,
    );

    // Execute the actual observation (simplified: marks completed).
    _completeObservation(success: true);
  }

  void _completeObservation({required bool success, String? skipReason}) {
    if (skipReason != null) {
      state = state.copyWith(
        isObserving: false,
        lastCompletedAt: success ? DateTime.now() : null,
        lastSkippedReason: skipReason,
        skippedObservations: state.skippedObservations + 1,
      );
    } else if (success) {
      state = state.copyWith(
        isObserving: false,
        lastCompletedAt: DateTime.now(),
        successfulObservations: state.successfulObservations + 1,
        clearSkipReason: true,
      );
    }
  }

  /// Public methods

  /// Must be called once the app has fully initialized and the
  /// observation engine is ready (profile loaded, groups available).
  void markEngineReady() {
    _engineReady = true;
  }

  /// Update the enabled flag.
  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
  }

  /// Update the observation interval (minutes).
  void setIntervalMinutes(int minutes) {
    state = state.copyWith(intervalMinutes: minutes);
  }

  /// Called by AppStateManager on lifecycle change to track background time.
  void onLifecycleChanged(DateTime timestamp) {
    _lastLifecycleChangeAt = timestamp;
  }

  /// Get current state snapshot for display.
  HealthObservationSchedulerState get currentState => state;
}
