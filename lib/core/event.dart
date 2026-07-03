import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

abstract mixin class CoreEventListener {
  void onLog(Log log) {}

  void onLogs(List<Log> logs) {
    for (final log in logs) {
      onLog(log);
    }
  }

  void onDelay(Delay delay) {}

  void onRequest(TrackerInfo connection) {}

  void onRequests(List<TrackerInfo> connections) {
    for (final connection in connections) {
      onRequest(connection);
    }
  }

  void onLoaded(String providerName) {}

  void onCrash(String message) {}
}

@visibleForTesting
List<Log> parseCoreEventLogs(dynamic data) {
  return _parseCoreEventItems(data, Log.fromJson);
}

@visibleForTesting
List<TrackerInfo> parseCoreEventRequests(dynamic data) {
  return _parseCoreEventItems(data, TrackerInfo.fromJson);
}

List<T> _parseCoreEventItems<T>(
  dynamic data,
  T Function(Map<String, Object?> json) fromJson,
) {
  final rawItems = switch (data) {
    {'items': final List<dynamic> items} => items,
    {'events': final List<dynamic> events} => events,
    final List<dynamic> items => items,
    _ => [data],
  };
  return rawItems
      .whereType<Map>()
      .map((item) => fromJson(Map<String, Object?>.from(item)))
      .toList(growable: false);
}

class CoreEventManager {
  final _controller = StreamController<CoreEvent>();
  final Set<CoreEventType> _enabledEventTypes = {
    CoreEventType.delay,
    CoreEventType.loaded,
    CoreEventType.crash,
  };

  CoreEventManager._() {
    _controller.stream.listen((event) {
      if (!_enabledEventTypes.contains(event.type)) {
        return;
      }
      for (final CoreEventListener listener in _listeners) {
        switch (event.type) {
          case CoreEventType.log:
            listener.onLogs(parseCoreEventLogs(event.data));
            break;
          case CoreEventType.delay:
            listener.onDelay(Delay.fromJson(event.data));
            break;
          case CoreEventType.request:
            listener.onRequests(parseCoreEventRequests(event.data));
            break;
          case CoreEventType.loaded:
            listener.onLoaded(event.data);
            break;
          case CoreEventType.crash:
            listener.onCrash(event.data);
            break;
        }
      }
    });
  }

  static final CoreEventManager instance = CoreEventManager._();

  final ObserverList<CoreEventListener> _listeners =
      ObserverList<CoreEventListener>();

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void sendEvent(CoreEvent event) {
    _controller.add(event);
  }

  void setEventTypeEnabled(CoreEventType type, bool enabled) {
    if (enabled) {
      _enabledEventTypes.add(type);
    } else {
      _enabledEventTypes.remove(type);
    }
  }

  void addListener(CoreEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CoreEventListener listener) {
    _listeners.remove(listener);
  }
}

final coreEventManager = CoreEventManager.instance;
