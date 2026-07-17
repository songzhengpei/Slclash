import 'dart:async';

enum ProviderReadinessStatus {
  ready,
  noProviders,
  timeout,
  coreUnavailable,
  profileChanged,
  failed,
}

class ProviderReadinessResult {
  const ProviderReadinessResult({
    required this.status,
    required this.profileId,
    this.providerCount = 0,
    this.groupCount = 0,
    this.error,
  });

  final ProviderReadinessStatus status;
  final int? profileId;
  final int providerCount;
  final int groupCount;
  final Object? error;
}

class ProviderReadinessTimeout implements Exception {
  const ProviderReadinessTimeout();

  @override
  String toString() => 'Provider 尚未加载完成，请检查网络后重试';
}

class ProviderReadinessCoreUnavailable implements Exception {
  const ProviderReadinessCoreUnavailable();

  @override
  String toString() => '代理内核暂不可用';
}

typedef ProviderReadinessLog =
    void Function(
      String stage,
      ProviderReadinessResult result,
      Duration elapsed,
    );

/// The single bounded, profile-guarded orchestration for loading providers and
/// displayable proxy groups. UI/provider-specific state writes belong in
/// [commitReady] and therefore occur only after the final profile guard.
class ProviderReadinessService<P, G> {
  ProviderReadinessService({this.log});

  final ProviderReadinessLog? log;
  final Map<int, Future<ProviderReadinessResult>> _runningTasks = {};

  Future<ProviderReadinessResult> ensureCurrentProfileReady({
    required int? targetProfileId,
    required int? Function() currentProfileId,
    required Future<({bool external, bool proxy})> Function()
    readProviderDefinitions,
    required Future<bool> Function() ensureCoreReady,
    required Future<void> Function() applyProfileForDisplay,
    required Future<List<P>> Function() syncProviders,
    required bool Function(P provider) isProxyProvider,
    required Future<List<G>> Function() readGroups,
    required bool Function(List<G> groups) groupsAreValid,
    required Future<void> Function(List<P> providers, List<G> groups)
    commitReady,
    bool forceApply = false,
    Duration timeout = const Duration(seconds: 10),
  }) {
    if (targetProfileId == null) {
      return Future.value(
        const ProviderReadinessResult(
          status: ProviderReadinessStatus.noProviders,
          profileId: null,
        ),
      );
    }
    final running = _runningTasks[targetProfileId];
    if (running != null) return running;
    final future = _run(
      targetProfileId: targetProfileId,
      currentProfileId: currentProfileId,
      readProviderDefinitions: readProviderDefinitions,
      ensureCoreReady: ensureCoreReady,
      applyProfileForDisplay: applyProfileForDisplay,
      syncProviders: syncProviders,
      isProxyProvider: isProxyProvider,
      readGroups: readGroups,
      groupsAreValid: groupsAreValid,
      commitReady: commitReady,
      forceApply: forceApply,
      timeout: timeout,
    );
    _runningTasks[targetProfileId] = future;
    future.whenComplete(() {
      if (_runningTasks[targetProfileId] == future) {
        _runningTasks.remove(targetProfileId);
      }
    });
    return future;
  }

  Future<ProviderReadinessResult> _run({
    required int targetProfileId,
    required int? Function() currentProfileId,
    required Future<({bool external, bool proxy})> Function()
    readProviderDefinitions,
    required Future<bool> Function() ensureCoreReady,
    required Future<void> Function() applyProfileForDisplay,
    required Future<List<P>> Function() syncProviders,
    required bool Function(P provider) isProxyProvider,
    required Future<List<G>> Function() readGroups,
    required bool Function(List<G> groups) groupsAreValid,
    required Future<void> Function(List<P> providers, List<G> groups)
    commitReady,
    required bool forceApply,
    required Duration timeout,
  }) async {
    final watch = Stopwatch()..start();
    Object? lastError;
    var providerCount = 0;
    var groupCount = 0;

    ProviderReadinessResult result(ProviderReadinessStatus status) =>
        ProviderReadinessResult(
          status: status,
          profileId: targetProfileId,
          providerCount: providerCount,
          groupCount: groupCount,
          error: lastError,
        );
    bool changed() => currentProfileId() != targetProfileId;
    ProviderReadinessResult changedResult() {
      final value = result(ProviderReadinessStatus.profileChanged);
      log?.call('provider-readiness:profile-changed', value, watch.elapsed);
      return value;
    }

    log?.call(
      'provider-readiness:start',
      result(ProviderReadinessStatus.failed),
      watch.elapsed,
    );
    try {
      final definitions = await readProviderDefinitions();
      if (changed()) return changedResult();
      if (!definitions.external) {
        final value = result(ProviderReadinessStatus.noProviders);
        log?.call('provider-readiness:no-providers', value, watch.elapsed);
        return value;
      }
      if (!await ensureCoreReady()) {
        lastError = const ProviderReadinessCoreUnavailable();
        final value = result(ProviderReadinessStatus.coreUnavailable);
        log?.call('provider-readiness:core-unavailable', value, watch.elapsed);
        return value;
      }
      if (changed()) return changedResult();
      log?.call(
        'provider-readiness:core-ready',
        result(ProviderReadinessStatus.failed),
        watch.elapsed,
      );

      if (forceApply) {
        await applyProfileForDisplay();
        if (changed()) return changedResult();
        log?.call(
          'provider-readiness:profile-applied',
          result(ProviderReadinessStatus.failed),
          watch.elapsed,
        );
      }

      var appliedForMissingProviders = forceApply;
      var appliedAfterEmptyGroups = forceApply;
      var interval = const Duration(milliseconds: 250);
      while (watch.elapsed < timeout) {
        if (changed()) return changedResult();
        List<P> providers = const [];
        try {
          providers = await syncProviders();
          providerCount = providers.length;
          if (changed()) return changedResult();
          final proxyProviders = providers.where(isProxyProvider).length;
          log?.call(
            'provider-readiness:providers-synced',
            result(ProviderReadinessStatus.failed),
            watch.elapsed,
          );
          if (definitions.proxy &&
              proxyProviders == 0 &&
              !appliedForMissingProviders) {
            if (changed()) return changedResult();
            await applyProfileForDisplay();
            appliedForMissingProviders = true;
            appliedAfterEmptyGroups = true;
            if (changed()) return changedResult();
            log?.call(
              'provider-readiness:profile-applied-for-missing-providers',
              result(ProviderReadinessStatus.failed),
              watch.elapsed,
            );
            continue;
          }
          if (!definitions.proxy || proxyProviders > 0) {
            final groups = await readGroups();
            groupCount = groups.length;
            if (changed()) return changedResult();
            if (groupsAreValid(groups)) {
              await commitReady(providers, groups);
              if (changed()) return changedResult();
              final value = result(ProviderReadinessStatus.ready);
              log?.call(
                'provider-readiness:groups-ready',
                value,
                watch.elapsed,
              );
              return value;
            }
            if (!appliedAfterEmptyGroups) {
              await applyProfileForDisplay();
              appliedAfterEmptyGroups = true;
              if (changed()) return changedResult();
              continue;
            }
          }
        } catch (error) {
          lastError = error;
        }
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) break;
        await Future<void>.delayed(interval < remaining ? interval : remaining);
        final nextMs = (interval.inMilliseconds * 1.5).round().clamp(250, 1000);
        interval = Duration(milliseconds: nextMs);
      }
      lastError ??= const ProviderReadinessTimeout();
      final value = result(ProviderReadinessStatus.timeout);
      log?.call('provider-readiness:timeout', value, watch.elapsed);
      return value;
    } catch (error) {
      lastError = error;
      final value = result(ProviderReadinessStatus.failed);
      log?.call('provider-readiness:failed', value, watch.elapsed);
      return value;
    }
  }
}
