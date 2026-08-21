import 'dart:async';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class TileListener {
  FutureOr<void> onStart() {}

  FutureOr<void> onStop() {}

  FutureOr<void> onSmartStop() {}

  FutureOr<void> onSmartResume() {}

  FutureOr<void> onSync() {}

  FutureOr<void> onDetached() {}
}

class Tile {
  final MethodChannel _channel = const MethodChannel(
    '$methodChannelPrefix/tile',
  );

  Tile._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  static final Tile instance = Tile._();

  final ObserverList<TileListener> _listeners = ObserverList<TileListener>();

  Future<void> _methodCallHandler(MethodCall call) async {
    for (final TileListener listener in _listeners) {
      switch (call.method) {
        case 'start':
          await listener.onStart();
          break;
        case 'stop':
          await listener.onStop();
          break;
        case 'smartStop':
          await listener.onSmartStop();
          break;
        case 'smartResume':
          await listener.onSmartResume();
          break;
        case 'sync':
          await listener.onSync();
          break;
        case 'detached':
          await listener.onDetached();
          break;
      }
    }
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(TileListener listener) {
    _listeners.add(listener);
  }

  void removeListener(TileListener listener) {
    _listeners.remove(listener);
  }
}

final tile = system.isAndroid ? Tile.instance : null;
