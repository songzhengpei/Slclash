class SystemProxy {
  Future<bool?> startProxy(int port, String bassDomain) async => false;

  Future<void> stopProxy() async {}
}

const SystemProxy? proxy = null;
