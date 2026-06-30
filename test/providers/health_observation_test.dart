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
}
