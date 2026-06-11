import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/services.dart';

class System {
  static System? _instance;

  System._internal();

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  bool get isDesktop => false;

  bool get isWindows => false;

  bool get isMacOS => false;

  bool get isAndroid => true;

  bool get isLinux => false;

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.version.sdkInt;
  }

  Future<bool> checkIsAdmin() async => true;

  Future<AuthorizeCode> authorizeCore() async => AuthorizeCode.error;

  Future<void> back() async {
    await app?.moveTaskToBack();
  }

  Future<void> exit() async {
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    }
  }
}

final system = System();

class Windows {
  bool runas(String command, String arguments) => false;
}

const Windows? windows = null;

class MacOS {
  Future<void> updateDns(bool restore) async {}
}

const MacOS? macOS = null;
