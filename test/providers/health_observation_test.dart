import 'package:fl_clash/providers/health_observation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('healthObservationOneShotDelay', () {
    test('returns null when disabled', () {
      final now = DateTime(2026, 1, 1, 12);

      expect(
        healthObservationOneShotDelay(
          enabled: false,
          now: now,
          nextEligibleAt: now.add(const Duration(minutes: 10)),
        ),
        isNull,
      );
    });

    test('runs immediately without a next eligible time', () {
      final now = DateTime(2026, 1, 1, 12);

      expect(
        healthObservationOneShotDelay(enabled: true, now: now),
        Duration.zero,
      );
    });

    test('runs immediately when next eligible time has passed', () {
      final now = DateTime(2026, 1, 1, 12);

      expect(
        healthObservationOneShotDelay(
          enabled: true,
          now: now,
          nextEligibleAt: now.subtract(const Duration(seconds: 1)),
        ),
        Duration.zero,
      );
    });

    test('waits until future next eligible time', () {
      final now = DateTime(2026, 1, 1, 12);

      expect(
        healthObservationOneShotDelay(
          enabled: true,
          now: now,
          nextEligibleAt: now.add(const Duration(minutes: 7)),
        ),
        const Duration(minutes: 7),
      );
    });

    test('uses retry delay before next eligible time', () {
      final now = DateTime(2026, 1, 1, 12);

      expect(
        healthObservationOneShotDelay(
          enabled: true,
          now: now,
          nextEligibleAt: now.add(const Duration(minutes: 7)),
          retryDelay: const Duration(seconds: 30),
        ),
        const Duration(seconds: 30),
      );
    });
  });

  group('healthObservationWorkerCount', () {
    test('returns zero without eligible proxies', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 0,
          appForeground: true,
        ),
        0,
      );
    });

    test('caps foreground workers at ten', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
        ),
        10,
      );
    });

    test('caps background workers at five', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: false,
        ),
        5,
      );
    });

    test('uses up to five workers on cellular or screen off', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
          cellular: true,
        ),
        5,
      );
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
          screenOn: false,
        ),
        5,
      );
    });

    test('pauses in power save mode', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
          powerSaveMode: true,
        ),
        0,
      );
    });

    test('uses up to five workers when network is power limited', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
          networkPowerLimited: true,
        ),
        5,
      );
    });

    test(
      'uses up to five workers when both cellular and networkPowerLimited',
      () {
        expect(
          healthObservationWorkerCount(
            eligibleProxyCount: 12,
            appForeground: true,
            cellular: true,
            networkPowerLimited: true,
          ),
          5,
        );
      },
    );

    test('uses ten workers when network is not power limited', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
          networkPowerLimited: false,
        ),
        10,
      );
    });
  });

  group('healthObservationIsCellular', () {
    test('detects mobile connectivity', () {
      expect(
        healthObservationIsCellular([
          ConnectivityResult.wifi,
          ConnectivityResult.mobile,
        ]),
        isTrue,
      );
    });

    test('ignores non-cellular connectivity', () {
      expect(
        healthObservationIsCellular([
          ConnectivityResult.vpn,
          ConnectivityResult.wifi,
        ]),
        isFalse,
      );
    });
  });

  group('healthObservationLooksStuck', () {
    test('detects stuck observation after 10 minutes', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        healthObservationLooksStuck(
          isObserving: true,
          lastAttemptAt: now.subtract(const Duration(minutes: 11)),
          now: now,
        ),
        isTrue,
      );
    });

    test('not stuck when observing for less than 10 minutes', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        healthObservationLooksStuck(
          isObserving: true,
          lastAttemptAt: now.subtract(const Duration(minutes: 9)),
          now: now,
        ),
        isFalse,
      );
    });

    test('not stuck when not observing', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        healthObservationLooksStuck(
          isObserving: false,
          lastAttemptAt: now.subtract(const Duration(minutes: 15)),
          now: now,
        ),
        isFalse,
      );
    });

    test('not stuck when lastAttemptAt is null', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        healthObservationLooksStuck(
          isObserving: true,
          lastAttemptAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('detects stuck at exactly 10 minutes + 1 second', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        healthObservationLooksStuck(
          isObserving: true,
          lastAttemptAt: now.subtract(const Duration(minutes: 10, seconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
