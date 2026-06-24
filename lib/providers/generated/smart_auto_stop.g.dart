// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../smart_auto_stop.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks whether smart auto stop is currently active (VPN was auto-stopped
/// because the device is on a trusted network).

@ProviderFor(IsSmartStopped)
final isSmartStoppedProvider = IsSmartStoppedProvider._();

/// Tracks whether smart auto stop is currently active (VPN was auto-stopped
/// because the device is on a trusted network).
final class IsSmartStoppedProvider
    extends $NotifierProvider<IsSmartStopped, bool> {
  /// Tracks whether smart auto stop is currently active (VPN was auto-stopped
  /// because the device is on a trusted network).
  IsSmartStoppedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isSmartStoppedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isSmartStoppedHash();

  @$internal
  @override
  IsSmartStopped create() => IsSmartStopped();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isSmartStoppedHash() => r'01bc4dd8981626d9dc29334085f1002114c4edfc';

/// Tracks whether smart auto stop is currently active (VPN was auto-stopped
/// because the device is on a trusted network).

abstract class _$IsSmartStopped extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the smart auto stop lifecycle.
///
/// When enabled, listens to connectivity changes and checks if the device's
/// local IP matches any trusted network. If it does, the VPN is automatically
/// stopped. When the device leaves the trusted network, the VPN is resumed.
///
/// On Android, uses native smartStop/smartResume to suspend/resume TUN
/// without tearing down the service. Falls back to full stop/start on
/// non-Android or when native calls fail.

@ProviderFor(SmartAutoStopManager)
final smartAutoStopManagerProvider = SmartAutoStopManagerProvider._();

/// Manages the smart auto stop lifecycle.
///
/// When enabled, listens to connectivity changes and checks if the device's
/// local IP matches any trusted network. If it does, the VPN is automatically
/// stopped. When the device leaves the trusted network, the VPN is resumed.
///
/// On Android, uses native smartStop/smartResume to suspend/resume TUN
/// without tearing down the service. Falls back to full stop/start on
/// non-Android or when native calls fail.
final class SmartAutoStopManagerProvider
    extends $NotifierProvider<SmartAutoStopManager, bool> {
  /// Manages the smart auto stop lifecycle.
  ///
  /// When enabled, listens to connectivity changes and checks if the device's
  /// local IP matches any trusted network. If it does, the VPN is automatically
  /// stopped. When the device leaves the trusted network, the VPN is resumed.
  ///
  /// On Android, uses native smartStop/smartResume to suspend/resume TUN
  /// without tearing down the service. Falls back to full stop/start on
  /// non-Android or when native calls fail.
  SmartAutoStopManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smartAutoStopManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smartAutoStopManagerHash();

  @$internal
  @override
  SmartAutoStopManager create() => SmartAutoStopManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$smartAutoStopManagerHash() =>
    r'706dab159fdb9e4bcd94e7367c94fceef82f0035';

/// Manages the smart auto stop lifecycle.
///
/// When enabled, listens to connectivity changes and checks if the device's
/// local IP matches any trusted network. If it does, the VPN is automatically
/// stopped. When the device leaves the trusted network, the VPN is resumed.
///
/// On Android, uses native smartStop/smartResume to suspend/resume TUN
/// without tearing down the service. Falls back to full stop/start on
/// non-Android or when native calls fail.

abstract class _$SmartAutoStopManager extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
