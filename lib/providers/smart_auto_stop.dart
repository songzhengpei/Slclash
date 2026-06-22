import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/network_matcher.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'action.dart';
import 'app.dart';
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

      // Get non-VPN IPv4 addresses
      final localIps = await _getLocalIpAddresses();

      // Do not act when we have no real address data — wait for next check
      // to avoid false resume on flaky network transitions.
      if (localIps.isEmpty) return;

      final isOnTrusted = localIps.any(
        (ip) => NetworkMatcher.matches(ip, vpnProps.smartAutoStopNetworks),
      );

      if (isOnTrusted && isRunning && !isSmartStopped) {
        // On trusted network and VPN is running — stop VPN
        await _smartStop();
      } else if (!isOnTrusted && isSmartStopped) {
        // Left trusted network — resume VPN
        await _smartResume();
      }
    } finally {
      _checking = false;
    }
  }

  /// Stop VPN via native smartStop (suspend TUN only, keep service alive),
  /// falling back to full stop/start if native call fails.
  Future<void> _smartStop() async {
    final s = service;
    if (s != null) {
      try {
        await s.setSmartStopped(true);
        await s.smartStop();
        // Sync Dart-side state: VPN is no longer "running" from UI perspective
        ref.read(isSmartStoppedProvider.notifier).set(true);
        ref.read(runTimeProvider.notifier).value = null;
        return;
      } catch (_) {
        // Native failed — fall through to phase 1 fallback
      }
    }
    // Fallback: full stop via setupAction
    final setupAction = ref.read(setupActionProvider.notifier);
    await setupAction.updateStatus(false);
    ref.read(isSmartStoppedProvider.notifier).set(true);
  }

  /// Resume VPN via native smartResume (resume TUN only, no service restart),
  /// falling back to full stop/start if native call fails.
  Future<void> _smartResume() async {
    final s = service;
    if (s != null) {
      try {
        await s.setSmartStopped(false);
        await s.smartResume();
        // Sync Dart-side state: VPN is "running" again
        ref.read(isSmartStoppedProvider.notifier).set(false);
        // Re-read runTime from native side
        final runTime = await s.getRunTime();
        ref.read(runTimeProvider.notifier).value =
            runTime?.millisecondsSinceEpoch;
        return;
      } catch (_) {
        // Native failed — fall through to phase 1 fallback
      }
    }
    // Fallback: full start via setupAction
    final setupAction = ref.read(setupActionProvider.notifier);
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
