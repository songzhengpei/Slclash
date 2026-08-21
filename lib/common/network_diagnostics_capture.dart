import 'dart:async';

import 'package:fl_clash/common/network_diagnostics_match.dart';
import 'package:fl_clash/common/network_diagnostics_models.dart';
import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/event_lease.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

class CoreRouteCapture with CoreEventListener {
  CoreRouteCapture();

  NetworkDiagnosticTarget? _target;
  DateTime? _armedAt;
  Completer<TrackerInfo?>? _completer;
  TrackerInfo? _hit;
  var eventHits = 0;
  var _listening = false;

  TrackerInfo? get hit => _hit;

  void start({
    required NetworkDiagnosticTarget target,
    required DateTime armedAt,
  }) {
    stop();
    _target = target;
    _armedAt = armedAt;
    _hit = null;
    _completer = Completer<TrackerInfo?>();
    coreEventManager.addListener(this);
    CoreEventTypeLease.acquire(CoreEventType.request, this);
    _listening = true;
  }

  void stop() {
    if (!_listening) return;
    _listening = false;
    coreEventManager.removeListener(this);
    CoreEventTypeLease.release(CoreEventType.request, this);
    final pending = _completer;
    _completer = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(_hit);
    }
  }

  Future<TrackerInfo?> arm({
    required NetworkDiagnosticTarget target,
    required DateTime armedAt,
    required Duration wait,
  }) async {
    start(target: target, armedAt: armedAt);
    try {
      return await _completer!.future.timeout(wait, onTimeout: () => _hit);
    } finally {
      stop();
    }
  }

  @override
  void onRequest(TrackerInfo connection) {
    final target = _target;
    if (target == null || !_listening) {
      return;
    }
    if (!trackerMatchesTarget(connection, target)) {
      return;
    }
    final armedAt = _armedAt;
    if (armedAt != null &&
        connection.start.isBefore(armedAt.subtract(const Duration(seconds: 2)))) {
      return;
    }
    _hit = connection;
    eventHits += 1;
    final pending = _completer;
    if (pending != null && !pending.isCompleted) {
      pending.complete(connection);
    }
  }
}

TrackerInfo? pickFallbackConnection({
  required List<TrackerInfo> connections,
  required NetworkDiagnosticTarget target,
  required DateTime armedAt,
}) {
  for (final conn in connections) {
    if (!trackerMatchesTarget(conn, target)) continue;
    if (conn.start.isBefore(armedAt.subtract(const Duration(seconds: 2)))) {
      continue;
    }
    return conn;
  }
  return null;
}
