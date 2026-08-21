import 'package:fl_clash/common/network_diagnostics_models.dart';

class NetworkDiagnosticsStore {
  NetworkDiagnosticsStore({
    Iterable<NetworkDiagnosticTarget> targets = NetworkDiagnosticTarget.all,
  }) : states = {
         for (final target in targets)
           target.name: NetworkDiagnosticTargetState(target: target),
       };

  int generation = 0;
  int discarded = 0;
  final Map<String, NetworkDiagnosticTargetState> states;

  int beginRefresh({required bool routeChange}) {
    generation += 1;
    for (final name in states.keys) {
      final current = states[name]!;
      states[name] = current.copyWith(
        refreshing: true,
        generation: generation,
        latencyStatus: NetworkDiagnosticLatencyStatus.refreshing,
        routeStatus: routeChange
            ? NetworkDiagnosticRouteStatus.refreshing
            : current.routeStatus,
      );
    }
    return generation;
  }

  bool commitLatency({
    required String target,
    required int generation,
    required int? latencyMs,
    required DateTime measuredAt,
  }) {
    if (generation != this.generation) {
      discarded += 1;
      return false;
    }
    final current = states[target];
    if (current == null) return false;
    states[target] = current.copyWith(
      latencyMs: latencyMs,
      latencyStatus: latencyMs == null
          ? NetworkDiagnosticLatencyStatus.timeout
          : NetworkDiagnosticLatencyStatus.fresh,
      refreshing: true,
      generation: generation,
      measuredAt: measuredAt,
    );
    return true;
  }

  bool commitRoute({
    required String target,
    required int generation,
    String? countryCode,
    String? egressIp,
    String? routeName,
    required NetworkDiagnosticCountrySource countrySource,
    required NetworkDiagnosticConfidence countryConfidence,
    required DateTime measuredAt,
  }) {
    if (generation != this.generation) {
      discarded += 1;
      return false;
    }
    final current = states[target];
    if (current == null) return false;
    states[target] = current.copyWith(
      countryCode: countryCode,
      clearCountry: countryCode == null,
      egressIp: egressIp,
      clearEgress: egressIp == null,
      routeName: routeName,
      clearRoute: routeName == null,
      countrySource: countrySource,
      countryConfidence: countryConfidence,
      routeStatus: countryCode == null && routeName == null
          ? NetworkDiagnosticRouteStatus.unavailable
          : NetworkDiagnosticRouteStatus.fresh,
      refreshing: true,
      generation: generation,
      measuredAt: measuredAt,
    );
    return true;
  }

  bool finishTarget({
    required String target,
    required int generation,
    required bool routeChange,
    required bool gotRoute,
  }) {
    if (generation != this.generation) {
      discarded += 1;
      return false;
    }
    final current = states[target];
    if (current == null) return false;
    var next = current.copyWith(refreshing: false, generation: generation);
    if (current.latencyMs == null &&
        current.latencyStatus != NetworkDiagnosticLatencyStatus.fresh) {
      next = next.copyWith(
        latencyStatus: NetworkDiagnosticLatencyStatus.timeout,
      );
    }
    if (routeChange && !gotRoute) {
      next = next.copyWith(
        clearCountry: true,
        clearEgress: true,
        countrySource: NetworkDiagnosticCountrySource.unknown,
        countryConfidence: NetworkDiagnosticConfidence.unknown,
        routeStatus: NetworkDiagnosticRouteStatus.unavailable,
      );
    }
    states[target] = next;
    return true;
  }
}
