import 'dart:async';

import 'package:fl_clash/services/providers/provider_readiness_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Provider {
  const _Provider(this.proxy);
  final bool proxy;
}

void main() {
  ProviderReadinessService<_Provider, int> service() =>
      ProviderReadinessService<_Provider, int>();

  Future<ProviderReadinessResult> run({
    ProviderReadinessService<_Provider, int>? instance,
    int target = 1,
    int? Function()? current,
    bool external = true,
    bool proxyDefinition = true,
    Future<bool> Function()? core,
    Future<void> Function()? apply,
    Future<List<_Provider>> Function()? providers,
    Future<List<int>> Function()? groups,
    Future<void> Function(List<_Provider>, List<int>)? commit,
    bool forceApply = true,
    Duration timeout = const Duration(milliseconds: 120),
  }) => (instance ?? service()).ensureCurrentProfileReady(
    targetProfileId: target,
    currentProfileId: current ?? () => target,
    readProviderDefinitions: () async =>
        (external: external, proxy: proxyDefinition),
    ensureCoreReady: core ?? () async => true,
    applyProfileForDisplay: apply ?? () async {},
    syncProviders: providers ?? () async => const [_Provider(true)],
    isProxyProvider: (value) => value.proxy,
    readGroups: groups ?? () async => const [1],
    groupsAreValid: (value) => value.isNotEmpty && value.every((e) => e > 0),
    commitReady: commit ?? (_, _) async {},
    forceApply: forceApply,
    timeout: timeout,
  );

  test('returns noProviders without connecting core', () async {
    var coreCalls = 0;
    final result = await run(
      external: false,
      core: () async {
        coreCalls++;
        return true;
      },
    );
    expect(result.status, ProviderReadinessStatus.noProviders);
    expect(coreCalls, 0);
  });

  test('connects core and initializes before loading', () async {
    var coreCalls = 0;
    final result = await run(core: () async => ++coreCalls == 1);
    expect(result.status, ProviderReadinessStatus.ready);
    expect(coreCalls, 1);
  });

  test('provider initially empty then appears', () async {
    var calls = 0;
    final result = await run(
      providers: () async => ++calls < 2 ? const [] : const [_Provider(true)],
      timeout: const Duration(seconds: 1),
    );
    expect(result.status, ProviderReadinessStatus.ready);
    expect(calls, 2);
  });

  test(
    'missing proxy Provider triggers one apply without forceApply',
    () async {
      var syncCalls = 0;
      var applyCalls = 0;
      final result = await run(
        forceApply: false,
        apply: () async => applyCalls++,
        providers: () async =>
            ++syncCalls == 1 ? const [] : const [_Provider(true)],
        timeout: const Duration(seconds: 1),
      );
      expect(result.status, ProviderReadinessStatus.ready);
      expect(applyCalls, 1);
      expect(syncCalls, 2);
    },
  );

  test('missing proxy Provider applies only once before timeout', () async {
    var applyCalls = 0;
    final result = await run(
      forceApply: false,
      apply: () async => applyCalls++,
      providers: () async => const [],
      timeout: const Duration(milliseconds: 40),
    );
    expect(result.status, ProviderReadinessStatus.timeout);
    expect(applyCalls, 1);
  });

  test(
    'profile change during missing Provider apply prevents commit',
    () async {
      var current = 1;
      var commits = 0;
      final result = await run(
        forceApply: false,
        current: () => current,
        providers: () async => const [],
        apply: () async => current = 2,
        commit: (_, _) async => commits++,
      );
      expect(result.status, ProviderReadinessStatus.profileChanged);
      expect(commits, 0);
    },
  );

  test('groups initially empty then become valid', () async {
    var calls = 0;
    var applyCalls = 0;
    final result = await run(
      apply: () async => applyCalls++,
      groups: () async => ++calls < 2 ? const [] : const [1],
      timeout: const Duration(seconds: 1),
    );
    expect(result.status, ProviderReadinessStatus.ready);
    expect(calls, 2);
    expect(applyCalls, greaterThanOrEqualTo(1));
  });

  test('returns timeout and does not commit incomplete groups', () async {
    var commits = 0;
    final result = await run(
      groups: () async => const [],
      commit: (_, _) async => commits++,
      timeout: const Duration(milliseconds: 40),
    );
    expect(result.status, ProviderReadinessStatus.timeout);
    expect(commits, 0);
  });

  test('returns coreUnavailable', () async {
    final result = await run(core: () async => false);
    expect(result.status, ProviderReadinessStatus.coreUnavailable);
  });

  test('profile change prevents old result commit', () async {
    var current = 1;
    var commits = 0;
    final result = await run(
      current: () => current,
      providers: () async {
        current = 2;
        return const [_Provider(true)];
      },
      commit: (_, _) async => commits++,
    );
    expect(result.status, ProviderReadinessStatus.profileChanged);
    expect(commits, 0);
  });

  test('same profile concurrent calls reuse one task', () async {
    final instance = service();
    final gate = Completer<void>();
    var calls = 0;
    Future<List<_Provider>> load() async {
      calls++;
      await gate.future;
      return const [_Provider(true)];
    }

    final first = run(instance: instance, providers: load);
    final second = run(instance: instance, providers: load);
    expect(identical(first, second), isTrue);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(
      results.map((e) => e.status),
      everyElement(ProviderReadinessStatus.ready),
    );
    expect(calls, 1);
  });

  test('different profiles do not share tasks', () async {
    final instance = service();
    var calls = 0;
    await Future.wait([
      run(
        instance: instance,
        target: 1,
        current: () => 1,
        providers: () async {
          calls++;
          return const [_Provider(true)];
        },
      ),
      run(
        instance: instance,
        target: 2,
        current: () => 2,
        providers: () async {
          calls++;
          return const [_Provider(true)];
        },
      ),
    ]);
    expect(calls, 2);
  });

  test('transient Provider API error is retried', () async {
    var calls = 0;
    final result = await run(
      providers: () async {
        if (++calls == 1) throw StateError('temporary');
        return const [_Provider(true)];
      },
      timeout: const Duration(seconds: 1),
    );
    expect(result.status, ProviderReadinessStatus.ready);
    expect(calls, 2);
  });

  test('successful result commits valid snapshot data', () async {
    List<int>? committed;
    final result = await run(commit: (_, groups) async => committed = groups);
    expect(result.status, ProviderReadinessStatus.ready);
    expect(committed, [1]);
  });

  test(
    'rule-only providers can become ready with valid inline groups',
    () async {
      final result = await run(
        proxyDefinition: false,
        providers: () async => const [],
        groups: () async => const [1],
      );
      expect(result.status, ProviderReadinessStatus.ready);
    },
  );
}
