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
/// **nextEligibleAt policy (fix: not advanced before execution)**
/// - Successful observation: advance by full [intervalMinutes].
/// - Core / profile / group temporarily unavailable: short retry (1–5 min).
/// - Already running: short retry (1 min).
///
/// **Health result persistence**
/// Results from app-level observations are written to [MediaCheckCache]
/// via [MediaCheckCacheStore], the same store used by the page-level UI.
/// This ensures historical-stable-node calculations reflect both sources.

@ProviderFor(HealthObservationScheduler)
final healthObservationSchedulerProvider =
    HealthObservationSchedulerProvider._();

/// App-level health observation scheduler.
///
/// Runs independently of widget lifecycle, page visibility, and VPN state.
/// Uses a lightweight 15-second tick timer only for condition checking.
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
  /// **nextEligibleAt policy (fix: not advanced before execution)**
  /// - Successful observation: advance by full [intervalMinutes].
  /// - Core / profile / group temporarily unavailable: short retry (1–5 min).
  /// - Already running: short retry (1 min).
  ///
  /// **Health result persistence**
  /// Results from app-level observations are written to [MediaCheckCache]
  /// via [MediaCheckCacheStore], the same store used by the page-level UI.
  /// This ensures historical-stable-node calculations reflect both sources.
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
    r'090cc3ea6cc88858058545d9a87b3db4786de0ae';

/// App-level health observation scheduler.
///
/// Runs independently of widget lifecycle, page visibility, and VPN state.
/// Uses a lightweight 15-second tick timer only for condition checking.
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
