class AutoLaunch {
  Future<bool> get isEnable async => false;

  Future<bool> enable() async => false;

  Future<bool> disable() async => false;

  Future<void> updateStatus(bool isAutoLaunch) async {}
}

const AutoLaunch? autoLaunch = null;
