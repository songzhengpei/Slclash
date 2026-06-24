// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../health_observation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(HealthObservationScheduler)
final healthObservationSchedulerProvider =
    HealthObservationSchedulerProvider._();

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
final class HealthObservationSchedulerProvider
    extends
        $NotifierProvider<
          HealthObservationScheduler,
          HealthObservationSchedulerState
        > {
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
  HealthObservationSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healthObservationSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healthObservationSchedulerHash();

  @$internal
  @override
  HealthObservationScheduler create() => HealthObservationScheduler();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealthObservationSchedulerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealthObservationSchedulerState>(
        value,
      ),
    );
  }
}

String _$healthObservationSchedulerHash() =>
    r'7d584412f0c6ac8eebf8236a4ec5d5f856e9d89a';

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

abstract class _$HealthObservationScheduler
    extends $Notifier<HealthObservationSchedulerState> {
  HealthObservationSchedulerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              HealthObservationSchedulerState,
              HealthObservationSchedulerState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                HealthObservationSchedulerState,
                HealthObservationSchedulerState
              >,
              HealthObservationSchedulerState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
