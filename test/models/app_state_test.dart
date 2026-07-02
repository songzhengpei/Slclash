import 'package:fl_clash/common/fixed.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppState defaults core status to disconnected', () {
    final appState = AppState(
      viewSize: Size.zero,
      brightness: Brightness.light,
      requests: FixedList(0),
      version: 0,
      logs: FixedList(0),
      traffics: FixedList(0),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: SystemUiOverlayStyle.light,
    );

    expect(appState.coreStatus, CoreStatus.disconnected);
  });
}
