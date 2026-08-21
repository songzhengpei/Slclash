import 'dart:async';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/plugins/tile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Listener with TileListener {
  int smartStopCalls = 0;

  @override
  void onSmartStop() {
    smartStopCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('external smartStop channel dispatches the Flutter callback', () async {
    final listener = _Listener();
    Tile.instance.addListener(listener);
    addTearDown(() => Tile.instance.removeListener(listener));

    final reply = Completer<void>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          '$methodChannelPrefix/tile',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('smartStop'),
          ),
          (_) => reply.complete(),
        );
    await reply.future;

    expect(listener.smartStopCalls, 1);
  });
}
