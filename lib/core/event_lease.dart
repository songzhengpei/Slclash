import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/foundation.dart';

/// Reference-counted Core event enablement. Page owners and diagnostics
/// share [CoreEventType.request] without blindly disabling each other.
class CoreEventTypeLease {
  CoreEventTypeLease._();

  static final Map<CoreEventType, Set<Object>> _owners = {};

  static void acquire(CoreEventType type, Object owner) {
    final set = _owners.putIfAbsent(type, () => <Object>{});
    set.add(owner);
    coreEventManager.setEventTypeEnabled(type, true);
  }

  static void release(CoreEventType type, Object owner) {
    final set = _owners[type];
    set?.remove(owner);
    if (set == null || set.isEmpty) {
      coreEventManager.setEventTypeEnabled(type, false);
    }
  }

  static bool hasOwner(CoreEventType type) {
    return _owners[type]?.isNotEmpty ?? false;
  }

  @visibleForTesting
  static void resetForTest() {
    _owners.clear();
  }
}
