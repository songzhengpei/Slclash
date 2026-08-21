import 'package:fl_clash/manager/tile_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tile full stop accepts running and smart-paused sessions only', () {
    expect(
      shouldHandleTileFullStop(isStart: true, isSmartStopped: false),
      isTrue,
    );
    expect(
      shouldHandleTileFullStop(isStart: false, isSmartStopped: true),
      isTrue,
    );
    expect(
      shouldHandleTileFullStop(isStart: false, isSmartStopped: false),
      isFalse,
    );
  });
}
