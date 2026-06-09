import 'package:flutter/services.dart';

enum WifiSsidPermission {
  granted,
  denied,
  permanentlyDenied,
}

class WifiSsidManager {
  WifiSsidManager._();

  static final WifiSsidManager instance = WifiSsidManager._();

  final MethodChannel _channel = const MethodChannel('wifi_ssid');

  /// Returns the current WiFi SSID, or null if not connected to WiFi.
  Future<String?> getSsid() async {
    return await _channel.invokeMethod<String>('getSsid');
  }

  /// Checks whether location permission has been granted.
  Future<WifiSsidPermission> checkPermission() async {
    final result = await _channel.invokeMethod<int>('checkPermission');
    return WifiSsidPermission.values[result ?? 1];
  }

  /// Requests location permission from the user.
  Future<WifiSsidPermission> requestPermission() async {
    final result = await _channel.invokeMethod<int>('requestPermission');
    return WifiSsidPermission.values[result ?? 1];
  }
}

final wifiSsidManager = WifiSsidManager.instance;
