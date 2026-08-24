import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('UI stats timer desired state', () {
    const cases =
        <
          ({
            String name,
            bool foreground,
            bool running,
            bool smartPaused,
            bool expected,
          })
        >[
          (
            name: 'A RUNNING foreground',
            foreground: true,
            running: true,
            smartPaused: false,
            expected: true,
          ),
          (
            name: 'B RUNNING background',
            foreground: false,
            running: true,
            smartPaused: false,
            expected: false,
          ),
          (
            name: 'C background session reconcile',
            foreground: false,
            running: true,
            smartPaused: false,
            expected: false,
          ),
          (
            name: 'D RUNNING returns to foreground',
            foreground: true,
            running: true,
            smartPaused: false,
            expected: true,
          ),
          (
            name: 'E PAUSED foreground',
            foreground: true,
            running: false,
            smartPaused: true,
            expected: false,
          ),
          (
            name: 'F STOPPED foreground',
            foreground: true,
            running: false,
            smartPaused: false,
            expected: false,
          ),
          (
            name: 'G foreground RUNNING to PAUSED',
            foreground: true,
            running: false,
            smartPaused: true,
            expected: false,
          ),
          (
            name: 'H PAUSED to RUNNING in foreground',
            foreground: true,
            running: true,
            smartPaused: false,
            expected: true,
          ),
          (
            name: 'H PAUSED to RUNNING in background',
            foreground: false,
            running: true,
            smartPaused: false,
            expected: false,
          ),
        ];

    for (final testCase in cases) {
      test(testCase.name, () {
        expect(
          shouldRunUiStatsTimer(
            appForeground: testCase.foreground,
            sessionRunning: testCase.running,
            smartPaused: testCase.smartPaused,
          ),
          testCase.expected,
        );
      });
    }

    test('repeated convergence does not duplicate start, refresh, or stop', () {
      var timerActive = false;
      var starts = 0;
      var immediateRefreshes = 0;
      var stops = 0;

      void converge(bool shouldRun) {
        switch (uiStatsTimerEffect(
          shouldRun: shouldRun,
          isTimerActive: timerActive,
        )) {
          case UiStatsTimerEffect.none:
            return;
          case UiStatsTimerEffect.start:
            starts++;
            immediateRefreshes++;
            timerActive = true;
          case UiStatsTimerEffect.stop:
            stops++;
            timerActive = false;
        }
      }

      converge(true);
      converge(true);
      expect((starts, immediateRefreshes, stops), (1, 1, 0));

      converge(false);
      converge(false);
      expect((starts, immediateRefreshes, stops), (1, 1, 1));
    });
  });

  test('full stop clears smart pause and its manual override', () {
    final cleared = <String>[];
    convergeFullStopProviders(
      clearManualOverride: () => cleared.add('override'),
      clearSmartStopped: () => cleared.add('smartStopped'),
    );
    expect(cleared, ['override', 'smartStopped']);
  });

  group('ensureRestoreValidationCoreReady', () {
    test('connects and initializes the core once before validation', () async {
      var connectCalls = 0;
      var initCalls = 0;
      final ready = await ensureRestoreValidationCoreReady(
        isConnected: false,
        connectCore: () async {
          connectCalls++;
          return true;
        },
        isCoreInitialized: () async => false,
        initializeCore: () async {
          initCalls++;
          return true;
        },
      );

      expect(ready, isTrue);
      expect(connectCalls, 1);
      expect(initCalls, 1);
    });

    test('does not reconnect or initialize an available core', () async {
      var connectCalls = 0;
      var initCalls = 0;
      final ready = await ensureRestoreValidationCoreReady(
        isConnected: true,
        connectCore: () async {
          connectCalls++;
          return true;
        },
        isCoreInitialized: () async => true,
        initializeCore: () async {
          initCalls++;
          return true;
        },
      );

      expect(ready, isTrue);
      expect(connectCalls, 0);
      expect(initCalls, 0);
    });
  });

  test('activation failure remains a committed restore outcome', () async {
    final outcome = await activateCommittedRestore(
      applyProfile: () async => false,
      updateGroups: () async {},
    );
    expect(outcome.committed, true);
    expect(outcome.activationSucceeded, false);
    expect(outcome.activationError, isNotEmpty);
  });

  group('shouldFullSetupOnInit', () {
    test(
      'skips full setup when VPN is not running and auto run is disabled',
      () {
        expect(
          shouldFullSetupOnInit(isRunning: false, autoRun: false),
          isFalse,
        );
      },
    );

    test('runs full setup when VPN is already running', () {
      expect(shouldFullSetupOnInit(isRunning: true, autoRun: false), isTrue);
    });

    test('runs full setup when auto run is enabled', () {
      expect(shouldFullSetupOnInit(isRunning: false, autoRun: true), isTrue);
    });
  });

  group('running session reattach helpers', () {
    test('RUNNING and STARTING require full setup', () {
      expect(sessionRequiresFullSetup('RUNNING'), isTrue);
      expect(sessionRequiresFullSetup('STARTING'), isTrue);
      expect(sessionRequiresFullSetup('STOPPING'), isFalse);
      expect(sessionRequiresFullSetup('PAUSED'), isFalse);
      expect(sessionRequiresFullSetup('STOPPED'), isFalse);
    });

    test('only RUNNING skips the connect min delay', () {
      expect(shouldSkipConnectMinDelay('RUNNING'), isTrue);
      expect(shouldSkipConnectMinDelay('STARTING'), isFalse);
      expect(shouldSkipConnectMinDelay('STOPPED'), isFalse);
    });

    test('only RUNNING defers initCore group work to applyProfile', () {
      expect(shouldDeferInitCoreGroups('RUNNING'), isTrue);
      expect(shouldDeferInitCoreGroups('STARTING'), isFalse);
    });

    test('PAUSED restores smart-stop UI without the RUNNING fast path', () {
      expect(shouldRestoreSmartPaused('PAUSED'), isTrue);
      expect(shouldRestoreSmartPaused('STOPPED', smartPaused: true), isTrue);
      expect(shouldRestoreSmartPaused('RUNNING'), isFalse);
      expect(shouldSkipConnectMinDelay('PAUSED'), isFalse);
      expect(shouldDeferInitCoreGroups('PAUSED'), isFalse);
      expect(sessionRequiresFullSetup('PAUSED'), isFalse);
    });

    test('PAUSED attaches Core without VPN setup or applyProfile', () {
      expect(shouldAttachCoreWithoutVpnSetup('PAUSED'), isTrue);
      expect(shouldAttachCoreWithoutVpnSetup('RUNNING'), isFalse);
      expect(shouldAttachCoreWithoutVpnSetup('STOPPED'), isFalse);
      expect(shouldAttachCoreWithoutVpnSetup(null), isFalse);
    });

    test('smart resume starts the listener only after Core is ready', () {
      expect(
        shouldStartListenerAfterSmartResume(suspend: false, coreReady: true),
        isTrue,
      );
      expect(
        shouldStartListenerAfterSmartResume(suspend: false, coreReady: false),
        isFalse,
      );
      expect(
        shouldStartListenerAfterSmartResume(suspend: true, coreReady: true),
        isFalse,
      );
    });

    test('native session maps to visible UI state without guessing', () {
      expect(nativeSessionUiStateFor('RUNNING'), NativeSessionUiState.running);
      expect(nativeSessionUiStateFor('PAUSED'), NativeSessionUiState.paused);
      expect(nativeSessionUiStateFor('STOPPED'), NativeSessionUiState.stopped);
      expect(nativeSessionUiStateFor('STARTING'), NativeSessionUiState.pending);
      expect(nativeSessionUiStateFor('STOPPING'), NativeSessionUiState.pending);
      expect(nativeSessionUiStateFor(null), NativeSessionUiState.pending);
    });
  });

  group('vpnStartPolicy', () {
    test('user tap silences loading and stops VPN if apply or TUN fails', () {
      final policy = vpnStartPolicy(isInit: false);
      expect(policy.silence, isTrue);
      expect(policy.stopOnFailure, isTrue);
      expect(policy.seedRunTimeAtZero, isFalse);
    });

    test(
      'init shows loading, does not stop VPN on failure, and seeds runTime',
      () {
        final policy = vpnStartPolicy(isInit: true);
        expect(policy.silence, isFalse);
        expect(policy.stopOnFailure, isFalse);
        expect(policy.seedRunTimeAtZero, isTrue);
      },
    );
  });

  group('shouldReconnectCoreOnResume', () {
    test(
      'does not reconnect core on Android when VPN is stopped and groups exist',
      () {
        expect(
          shouldReconnectCoreOnResume(
            isAndroid: true,
            isRunning: false,
            hasGroups: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'reconnects core on Android when VPN is stopped but groups are empty (initial load)',
      () {
        expect(
          shouldReconnectCoreOnResume(
            isAndroid: true,
            isRunning: false,
            hasGroups: false,
          ),
          isTrue,
        );
      },
    );

    test('reconnects core on Android when VPN is running', () {
      expect(
        shouldReconnectCoreOnResume(
          isAndroid: true,
          isRunning: true,
          hasGroups: true,
        ),
        isTrue,
      );
    });

    test('does not reconnect core on non-Android platforms', () {
      expect(
        shouldReconnectCoreOnResume(
          isAndroid: false,
          isRunning: true,
          hasGroups: true,
        ),
        isFalse,
      );
    });
  });

  group('hasExternalProviderDefinitions', () {
    test('is false when config has no providers', () {
      expect(hasExternalProviderDefinitions(const ClashConfig()), isFalse);
    });

    test('is true when config has proxy providers', () {
      final config = ClashConfig.fromJson({
        'proxy-providers': {'provider1': <String, Object?>{}},
      });

      expect(hasExternalProviderDefinitions(config), isTrue);
    });

    test('is true when config has rule providers', () {
      final config = ClashConfig.fromJson({
        'rule-providers': {'rules1': <String, Object?>{}},
      });

      expect(hasExternalProviderDefinitions(config), isTrue);
    });
  });

  group('parseProfileProviderDefinitions', () {
    test('detects proxy and rule providers without accessing core', () {
      final definitions = parseProfileProviderDefinitions('''
proxy-providers:
  airport:
    type: http
rule-providers:
  reject:
    type: http
''');

      expect(definitions.external, isTrue);
      expect(definitions.proxy, isTrue);
    });

    test('does not treat empty provider maps as definitions', () {
      final definitions = parseProfileProviderDefinitions('''
proxy-providers: {}
rule-providers: {}
proxies:
  - name: inline
    type: direct
''');

      expect(definitions.external, isFalse);
      expect(definitions.proxy, isFalse);
    });
  });

  group('runtime config projection identity', () {
    test(
      'provider result is discarded when A changes to B during fetch',
      () async {
        var currentProfileId = 1;
        final fetchStarted = Completer<void>();
        final releaseFetch = Completer<void>();
        final published = <String>[];

        final resultFuture = fetchAndPublishRuntimeProjection(
          targetProfileId: 1,
          currentProfileId: () => currentProfileId,
          fetch: () async {
            fetchStarted.complete();
            await releaseFetch.future;
            return 'providers-A';
          },
          publish: published.add,
        );
        await fetchStarted.future;
        currentProfileId = 2;
        releaseFetch.complete();

        expect(await resultFuture, isFalse);
        expect(published, isEmpty);
      },
    );

    test('A result stays discarded after UI advances through B to C', () async {
      var currentProfileId = 1;
      final fetchStarted = Completer<void>();
      final releaseFetch = Completer<void>();
      final published = <String>[];

      final resultFuture = fetchAndPublishRuntimeProjection(
        targetProfileId: 1,
        currentProfileId: () => currentProfileId,
        fetch: () async {
          fetchStarted.complete();
          await releaseFetch.future;
          return 'providers-A';
        },
        publish: published.add,
      );
      await fetchStarted.future;
      currentProfileId = 2;
      currentProfileId = 3;
      releaseFetch.complete();

      expect(await resultFuture, isFalse);
      expect(published, isEmpty);
    });

    test(
      'provider result publishes when target identity stays current',
      () async {
        final published = <String>[];
        final result = await fetchAndPublishRuntimeProjection(
          targetProfileId: 1,
          currentProfileId: () => 1,
          fetch: () async => 'providers-A',
          publish: published.add,
        );

        expect(result, isTrue);
        expect(published, ['providers-A']);
      },
    );
  });

  group('preheat runtime projection identity', () {
    test(
      'switching A to B during warm-up drops late delay and post-refresh',
      () async {
        var currentProfileId = 1;
        final warmUpStarted = Completer<void>();
        final releaseWarmUp = Completer<void>();
        final published = <Delay>[];
        var scheduledRefreshes = 0;

        final remainsCurrent = warmUpRuntimeDelaysForProfile(
          targetProfileId: 1,
          currentProfileId: () => currentProfileId,
          publish: published.add,
          warmUp: (onDelay) async {
            onDelay(const Delay(url: 'test', name: 'A', value: 0));
            warmUpStarted.complete();
            await releaseWarmUp.future;
            onDelay(const Delay(url: 'test', name: 'A', value: 88));
          },
        );
        await warmUpStarted.future;
        currentProfileId = 2;
        releaseWarmUp.complete();

        if (await remainsCurrent) scheduledRefreshes++;
        expect(
          published.map((delay) => delay.value),
          [0],
          reason: 'the late A result must not enter B delay projection',
        );
        expect(scheduledRefreshes, 0);
      },
    );

    test(
      'A debounce becomes inert when current changes before callback',
      () async {
        final scheduler = Debouncer();
        var currentProfileId = 1;
        var refreshes = 0;

        scheduleRuntimeProjectionRefresh(
          scheduler: scheduler,
          tag: Object(),
          expectedProfileId: 1,
          currentProfileId: () => currentProfileId,
          refresh: () => refreshes++,
          duration: const Duration(milliseconds: 10),
        );
        currentProfileId = 2;
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(refreshes, 0);
      },
    );

    test('A debounce refreshes normally while A remains current', () async {
      final scheduler = Debouncer();
      final refreshed = Completer<void>();

      scheduleRuntimeProjectionRefresh(
        scheduler: scheduler,
        tag: Object(),
        expectedProfileId: 1,
        currentProfileId: () => 1,
        refresh: refreshed.complete,
        duration: const Duration(milliseconds: 10),
      );

      await refreshed.future.timeout(const Duration(seconds: 1));
      expect(refreshed.isCompleted, isTrue);
    });
  });

  group('ProfilesAction', () {
    test('auto loop does not republish a stale captured profile', () async {
      final a = Profile.normal(label: 'A', url: 'https://a.example');
      final bOld = Profile.normal(label: 'B old', url: 'https://b.example');
      final bNew = bOld.copyWith(
        label: 'B newest',
        autoUpdate: false,
        autoUpdateDuration: const Duration(hours: 12),
      );
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => _TestProfiles([a, bOld])),
        ],
      );
      addTearDown(container.dispose);
      final aStarted = Completer<void>();
      final releaseA = Completer<void>();
      Profile? capturedB;

      final loop = runAutoProfileRefreshLoop(
        capturedProfiles: List<Profile>.from(container.read(profilesProvider)),
        refresh: (profile) async {
          if (profile.id == a.id) {
            aStarted.complete();
            await releaseA.future;
          } else {
            capturedB = profile;
          }
        },
        onError: (_) {},
      );
      await aStarted.future;
      container.read(profilesProvider.notifier).put(bNew);
      releaseA.complete();
      await loop;

      expect(capturedB, bOld);
      expect(container.read(profilesProvider).getProfile(bOld.id), bNew);
    });

    test('auto loop supersedes a captured response after URL edit', () async {
      final a = Profile.normal(label: 'A', url: 'https://a.example');
      final bOld = Profile.normal(
        label: 'B old',
        url: 'https://old.example/profile',
      );
      final bNew = bOld.copyWith(
        label: 'B newest',
        url: 'https://new.example/profile',
      );
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => _TestProfiles([a, bOld])),
        ],
      );
      addTearDown(container.dispose);
      final aStarted = Completer<void>();
      final releaseA = Completer<void>();
      var oldResponseWasCurrent = true;

      final loop = runAutoProfileRefreshLoop(
        capturedProfiles: List<Profile>.from(container.read(profilesProvider)),
        refresh: (profile) async {
          if (profile.id == a.id) {
            aStarted.complete();
            await releaseA.future;
            return;
          }
          oldResponseWasCurrent = isProfileSourceIdentityCurrent(
            container.read(profilesProvider).getProfile(profile.id),
            profileId: profile.id,
            sourceUrl: profile.url,
          );
        },
        onError: (_) {},
      );
      await aStarted.future;
      container.read(profilesProvider.notifier).put(bNew);
      releaseA.complete();
      await loop;

      expect(oldResponseWasCurrent, isFalse);
      expect(container.read(profilesProvider).getProfile(bOld.id), bNew);
    });

    test('refresh-only failure never publishes captured metadata', () async {
      final captured = Profile.normal(label: 'old label', url: 'bad-url');
      final latest = captured.copyWith(
        label: 'newest label',
        autoUpdate: false,
        autoUpdateDuration: const Duration(hours: 8),
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => null),
          profilesProvider.overrideWith(() => _TestProfiles([latest])),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(profilesActionProvider.notifier)
            .updateProfile(captured, publishInput: false),
        throwsA(anything),
      );

      expect(container.read(profilesProvider).getProfile(captured.id), latest);
    });

    test('keeps edited profile data when remote update fails', () async {
      final original = Profile.normal(label: 'old label', url: 'bad-url');
      final edited = original.copyWith(
        label: 'new label',
        url: 'still-bad-url',
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => null),
          profilesProvider.overrideWith(() => _TestProfiles([original])),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(profilesProvider).getProfile(original.id),
        original,
      );

      await expectLater(
        container
            .read(profilesActionProvider.notifier)
            .updateProfile(edited, publishInput: true),
        throwsA(anything),
      );

      final profile = container.read(profilesProvider).getProfile(original.id);
      expect(profile?.label, edited.label);
      expect(profile?.url, edited.url);
    });
  });
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles(this.initial);

  @override
  List<Profile> build() => initial;

  @override
  void put(Profile profile) {
    final next = List<Profile>.from(state);
    final index = next.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      next.add(profile);
    } else {
      next[index] = profile;
    }
    state = next;
  }
}
