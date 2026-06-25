import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/network_matcher.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'action.dart';
import 'config.dart';
import 'state.dart';

part 'generated/smart_auto_stop.g.dart';

/// Filter out loopback, VPN tunnel, and point-to-point interfaces.
const filteredInterfacePrefixes = ['lo', 'tun', 'utun', 'ppp', 'vpn'];

/// Returns `true` if [name] matches a known VPN/loopback interface prefix.
bool isFilteredNetworkInterface(String name) {
  final lower = name.toLowerCase();
  return filteredInterfacePrefixes.any(lower.startsWith);
}

/// Tracks whether smart auto stop is currently active (VPN was auto-stopped
/// because the device is on a trusted network).
@Riverpod(keepAlive: true)
class IsSmartStopped extends _$IsSmartStopped {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Tracks whether the user has manually resumed from a smart auto-stop
/// during the current trusted-network session.
///
/// When true, [SmartAutoStopManager._checkAndToggle] will NOT auto-stop
/// again until the user leaves the trusted network or manually stops the
/// proxy. This is a temporary per-session override, not a permanent
/// setting change.
@Riverpod(keepAlive: true)
class SmartAutoStopManualOverride extends _$SmartAutoStopManualOverride {
  @override
  bool build() => false;

  void set(bool value) => state = value;

  void clear() => state = false;
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
@Riverpod(keepAlive: true)
class SmartAutoStopManager extends _$SmartAutoStopManager {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;
  bool _checking = false;

  @override
  bool build() {
    ref.onDispose(_dispose);

    // Listen to connectivity changes
    _startListening();

    // Listen to smart auto stop config changes — trigger check when
    // smartAutoStop toggled or smartAutoStopNetworks modified.
    ref.listen(vpnSettingProvider, (prev, next) {
      final prevEnabled = prev?.smartAutoStop ?? false;
      final prevNetworks = prev?.smartAutoStopNetworks ?? [];
      final nextEnabled = next.smartAutoStop;
      final nextNetworks = next.smartAutoStopNetworks;

      final configChanged =
          prevEnabled != nextEnabled ||
          !_listEquals(prevNetworks, nextNetworks);

      if (!configChanged) return;

      // Clear manual resume override when Smart Auto Stop is disabled,
      // trusted networks are emptied, or the network list is modified.
      // This prevents stale override from persisting across config cycles.
      final smartAutoStopDisabled = prevEnabled && !nextEnabled;
      final trustedNetworksCleared = nextNetworks.isEmpty;
      final trustedNetworksChanged =
          prevNetworks.isNotEmpty && !_listEquals(prevNetworks, nextNetworks);
      if (smartAutoStopDisabled ||
          trustedNetworksCleared ||
          trustedNetworksChanged) {
        ref.read(smartAutoStopManualOverrideProvider.notifier).clear();
      }

      // If smartAutoStop was just disabled or networks emptied while
      // VPN was auto-stopped, resume immediately without waiting for
      // connectivity change.
      if ((!nextEnabled || nextNetworks.isEmpty) &&
          ref.read(isSmartStoppedProvider)) {
        _resumeFromSmartStop();
        return;
      }

      // Otherwise trigger a debounced check with the new config.
      if (nextEnabled && nextNetworks.isNotEmpty) {
        _debouncedCheck();
      }
    });

    // Initial check on manager startup (debounced so providers are settled).
    _debouncedCheck();

    return false;
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _debouncedCheck();
    });
  }

  void _debouncedCheck() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _checkAndToggle();
    });
  }

  Future<void> _checkAndToggle() async {
    if (_checking) return;
    _checking = true;
    try {
      final vpnProps = ref.read(vpnSettingProvider);
      if (!vpnProps.smartAutoStop) return;
      if (vpnProps.smartAutoStopNetworks.isEmpty) return;

      final isRunning = ref.read(isStartProvider);
      final isSmartStopped = ref.read(isSmartStoppedProvider);
      final manualOverride = ref.read(smartAutoStopManualOverrideProvider);

      // Get non-VPN IPv4 addresses
      final localIps = await _getLocalIpAddresses();

      // Do not act when we have no real address data — wait for next check
      // to avoid false resume on flaky network transitions.
      if (localIps.isEmpty) return;

      final isOnTrusted = localIps.any(
        (ip) => NetworkMatcher.matches(ip, vpnProps.smartAutoStopNetworks),
      );

      // Left trusted network while smart-stopped → resume VPN and clear
      // any lingering manual override.
      if (!isOnTrusted && isSmartStopped) {
        await _smartResume();
        ref.read(smartAutoStopManualOverrideProvider.notifier).clear();
        return;
      }

      // Left trusted network while running with manual override → clear
      // the override so future trusted-network visits auto-stop normally.
      if (!isOnTrusted && manualOverride) {
        ref.read(smartAutoStopManualOverrideProvider.notifier).clear();
        return;
      }

      // On trusted network, VPN running, not yet smart-stopped, and user
      // hasn't manually resumed this session → auto smart-stop.
      if (isOnTrusted && isRunning && !isSmartStopped && !manualOverride) {
        await _smartStop();
      }
    } finally {
      _checking = false;
    }
  }

  /// Stop VPN via native smartStop (suspend TUN only, keep service alive),
  /// falling back to full stop/start if native call fails.
  Future<void> _smartStop() async {
    final setupAction = ref.read(setupActionProvider.notifier);
    final s = service;
    if (s != null) {
      try {
        final success = await s.smartStop();
        if (success) {
          await s.setSmartStopped(true);
          // Mark provider BEFORE clearing runTime so UI listeners see
          // paused state before isStart flips to false.
          ref.read(isSmartStoppedProvider.notifier).set(true);
          // Local: cancel timer, stop listener, clear runTime
          await setupAction.handleSmartStopLocal();
          return;
        }
      } catch (_) {}
      // Native failed — fall through to phase 1 fallback
    }
    // Fallback: full stop via setupAction
    await setupAction.updateStatus(false);
    ref.read(isSmartStoppedProvider.notifier).set(true);
  }

  /// Resume VPN via native smartResume (resume TUN only, no service restart),
  /// falling back to full stop/start if native call fails.
  Future<void> _smartResume() async {
    final setupAction = ref.read(setupActionProvider.notifier);
    final s = service;
    if (s != null) {
      try {
        final success = await s.smartResume();
        if (success) {
          await s.setSmartStopped(false);
          // Read native startTime and sync local timer/listener
          final nativeStartTime = await s.getRunTime();
          if (nativeStartTime != null) {
            await setupAction.handleSmartResumeLocal(nativeStartTime);
          }
          ref.read(isSmartStoppedProvider.notifier).set(false);
          return;
        }
      } catch (_) {}
      // Native failed — fall through to phase 1 fallback
    }
    // Fallback: full start via setupAction
    await setupAction.updateStatus(true);
    ref.read(isSmartStoppedProvider.notifier).set(false);
  }

  /// Resume from smart stop triggered by config change (disable or empty rules).
  Future<void> _resumeFromSmartStop() async {
    if (_checking) return;
    _checking = true;
    try {
      await _smartResume();
    } finally {
      _checking = false;
    }
  }

  /// Public entry point for the Dashboard "Resume" button.
  /// Manually resumes VPN from smart stop state, reusing the same
  /// checking lock and fallback logic as internal resume.
  ///
  /// Sets [smartAutoStopManualOverrideProvider] to true after a successful
  /// resume so the next connectivity check won't immediately auto-stop
  /// again while the user is still on the trusted network.
  Future<void> resumeNow() async {
    await _resumeFromSmartStop();
    // Only set override if proxy actually started — skip if resume failed.
    if (ref.read(isStartProvider)) {
      ref.read(smartAutoStopManualOverrideProvider.notifier).set(true);
    }
  }

  Future<List<String>> _getLocalIpAddresses() async {
    try {
      final s = service;
      if (s != null) {
        return await s.getLocalIpAddresses();
      }
    } catch (_) {}
    // Fallback to Dart's NetworkInterface if native call fails
    return _getLocalIpViaDart();
  }

  Future<List<String>> _getLocalIpViaDart() async {
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: false);
      final addresses = <String>[];
      for (final intf in interfaces) {
        if (isFilteredNetworkInterface(intf.name)) continue;
        for (final addr in intf.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            addresses.add(addr.address);
          }
        }
      }
      return addresses;
    } catch (_) {
      return [];
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
