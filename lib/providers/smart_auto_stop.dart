import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/network_matcher.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'action.dart';
import 'config.dart';
import 'state.dart';

part 'generated/smart_auto_stop.g.dart';

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
@Riverpod(keepAlive: true)
class SmartAutoStopManager extends _$SmartAutoStopManager {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;

  @override
  bool build() {
    ref.onDispose(_dispose);
    _startListening();
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
    final vpnProps = ref.read(vpnSettingProvider);
    if (!vpnProps.smartAutoStop) return;
    if (vpnProps.smartAutoStopNetworks.isEmpty) return;

    final isRunning = ref.read(isStartProvider);
    final isSmartStopped = ref.read(isSmartStoppedProvider);

    // Get non-VPN IPv4 addresses
    final localIps = await _getLocalIpAddresses();
    final isOnTrusted = localIps.any(
      (ip) => NetworkMatcher.matches(ip, vpnProps.smartAutoStopNetworks),
    );

    if (isOnTrusted && isRunning && !isSmartStopped) {
      // On trusted network and VPN is running — stop VPN
      final setupAction = ref.read(setupActionProvider.notifier);
      await setupAction.handleStop();
      ref.read(isSmartStoppedProvider.notifier).set(true);
    } else if (!isOnTrusted && isSmartStopped) {
      // Left trusted network — resume VPN
      final setupAction = ref.read(setupActionProvider.notifier);
      await setupAction.updateStatus(true);
      ref.read(isSmartStoppedProvider.notifier).set(false);
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
        for (final addr in intf.addresses) {
          if (addr.isIPv4 && !addr.isLoopback) {
            addresses.add(addr.address);
          }
        }
      }
      return addresses;
    } catch (_) {
      return [];
    }
  }

  void _dispose() {
    _subscription?.cancel();
    _subscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
