import 'package:fl_clash/models/config.dart';

class Window {
  Future<void> init(int version, WindowProps props) async {}

  Future<void> show() async {}

  Future<bool> get isVisible async => false;

  Future<void> close() async {}

  void forceExit() {}

  Future<void> hide() async {}
}

const Window? window = null;
