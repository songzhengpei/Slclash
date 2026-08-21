import 'package:flutter/foundation.dart';

/// Lightweight route/refresh generation. Old probes must discard if stale.
class NetworkDiagnosticsRevision {
  NetworkDiagnosticsRevision._();

  static int value = 0;
  static final ObserverList<VoidCallback> _listeners =
      ObserverList<VoidCallback>();

  static int bump({String reason = ''}) {
    value += 1;
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
    return value;
  }

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @visibleForTesting
  static void resetForTest() {
    value = 0;
    _listeners.clear();
  }
}
