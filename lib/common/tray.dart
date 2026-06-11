import 'package:fl_clash/models/models.dart';

class Tray {
  String get trayIconSuffix => 'png';

  String getTryIcon({required bool isStart, required bool tunEnable}) {
    if (!isStart) {
      return 'assets/images/icon/status_1.$trayIconSuffix';
    }
    if (!tunEnable) {
      return 'assets/images/icon/status_2.$trayIconSuffix';
    }
    return 'assets/images/icon/status_3.$trayIconSuffix';
  }

  Future<void> destroy() async {}

  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
  }) async {}

  Future<void> updateTrayTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  }) async {}
}

const Tray? tray = null;
