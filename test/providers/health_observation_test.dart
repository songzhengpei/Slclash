import 'package:fl_clash/providers/health_observation.dart';
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

    test('caps foreground workers at five', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
        ),
        5,
      );
    });

    test('caps background workers at two', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: false,
        ),
        2,
      );
    });

    test('uses one worker on cellular or screen off', () {
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
          cellular: true,
        ),
        1,
      );
      expect(
        healthObservationWorkerCount(
          eligibleProxyCount: 12,
          appForeground: true,
          screenOn: false,
        ),
        1,
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
  });
}
