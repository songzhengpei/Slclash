import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
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

  group('ProfilesAction', () {
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
        container.read(profilesActionProvider.notifier).updateProfile(edited),
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
