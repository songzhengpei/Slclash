import 'dart:async';

import 'package:fl_clash/services/mihomo_config/runtime_config_commit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runtime config commit ownership', () {
    test('slow A materializing after fast B is superseded', () async {
      final owner = RuntimeConfigCommitOwner();
      final a = owner.beginRequest();
      final b = owner.beginRequest();
      final commits = <String>[];

      final bOutcome = await owner.commit(
        generation: b,
        transaction: () async => commits.add('B'),
      );
      final aOutcome = await owner.commit(
        generation: a,
        transaction: () async => commits.add('A'),
      );

      expect(bOutcome, RuntimeConfigCommitOutcome.committed);
      expect(aOutcome, RuntimeConfigCommitOutcome.superseded);
      expect(commits, ['B']);
    });

    test('A to B to A uses generation rather than profile identity', () async {
      final owner = RuntimeConfigCommitOwner();
      final oldA = owner.beginRequest();
      owner.beginRequest(); // B
      final newA = owner.beginRequest();
      final commits = <String>[];

      final oldOutcome = await owner.commit(
        generation: oldA,
        transaction: () async => commits.add('old-A'),
      );
      final newOutcome = await owner.commit(
        generation: newA,
        transaction: () async => commits.add('new-A'),
      );

      expect(oldOutcome, RuntimeConfigCommitOutcome.superseded);
      expect(newOutcome, RuntimeConfigCommitOutcome.committed);
      expect(commits, ['new-A']);
    });

    test('setup observes bytes written by the same request', () async {
      final owner = RuntimeConfigCommitOwner();
      final a = owner.beginRequest();
      var sharedConfig = '';
      final aWritten = Completer<void>();
      final releaseA = Completer<void>();
      final setupReads = <String>[];

      final aCommit = owner.commit(
        generation: a,
        transaction: () async {
          sharedConfig = 'A';
          aWritten.complete();
          await releaseA.future;
          setupReads.add('A:$sharedConfig');
        },
      );
      await aWritten.future;

      final b = owner.beginRequest();
      final bCommit = owner.commit(
        generation: b,
        transaction: () async {
          sharedConfig = 'B';
          setupReads.add('B:$sharedConfig');
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(sharedConfig, 'A');

      releaseA.complete();
      await Future.wait([aCommit, bCommit]);
      expect(setupReads, ['A:A', 'B:B']);
      expect(sharedConfig, 'B');
    });

    test('stale before commit performs no transaction effects', () async {
      final owner = RuntimeConfigCommitOwner();
      final stale = owner.beginRequest();
      owner.beginRequest();
      var writes = 0;
      var setups = 0;
      var updates = 0;

      final outcome = await owner.commit(
        generation: stale,
        transaction: () async {
          writes++;
          setups++;
          updates++;
        },
      );

      expect(outcome, RuntimeConfigCommitOutcome.superseded);
      expect(writes, 0);
      expect(setups, 0);
      expect(updates, 0);
    });

    test('newer request waits for active commit and becomes final', () async {
      final owner = RuntimeConfigCommitOwner();
      final a = owner.beginRequest();
      final aStarted = Completer<void>();
      final releaseA = Completer<void>();
      final commits = <String>[];

      final aCommit = owner.commit(
        generation: a,
        transaction: () async {
          aStarted.complete();
          await releaseA.future;
          commits.add('A');
        },
      );
      await aStarted.future;

      final b = owner.beginRequest();
      final bCommit = owner.commit(
        generation: b,
        transaction: () async => commits.add('B'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(commits, isEmpty);

      releaseA.complete();
      expect(await aCommit, RuntimeConfigCommitOutcome.committed);
      expect(await bCommit, RuntimeConfigCommitOutcome.committed);
      expect(commits, ['A', 'B']);
    });

    test('older post-commit work finishes before newer commit', () async {
      final owner = RuntimeConfigCommitOwner();
      final a = owner.beginRequest();
      final aSetupDone = Completer<void>();
      final releaseAUpdate = Completer<void>();
      final events = <String>[];

      final aCommit = owner.commit(
        generation: a,
        transaction: () async {
          events.add('A-setup');
          aSetupDone.complete();
          await releaseAUpdate.future;
          events.add('A-onUpdated');
        },
      );
      await aSetupDone.future;

      final b = owner.beginRequest();
      final bCommit = owner.commit(
        generation: b,
        transaction: () async {
          events.add('B-setup');
          events.add('B-onUpdated');
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, ['A-setup']);

      releaseAUpdate.complete();
      await Future.wait([aCommit, bCommit]);
      expect(events, ['A-setup', 'A-onUpdated', 'B-setup', 'B-onUpdated']);
    });

    test(
      'superseded is an outcome and does not invoke failure handling',
      () async {
        final owner = RuntimeConfigCommitOwner();
        final stale = owner.beginRequest();
        owner.beginRequest();
        var failureEffects = 0;

        final outcome = await owner.commit(
          generation: stale,
          transaction: () async => fail('stale transaction must not run'),
        );
        if (outcome != RuntimeConfigCommitOutcome.superseded) {
          failureEffects++;
        }

        expect(outcome, RuntimeConfigCommitOutcome.superseded);
        expect(failureEffects, 0);
        expect(SetupConfigOutcome.superseded.isFailure, isFalse);
        expect(SetupConfigOutcome.superseded.mayContinueStart, isFalse);
        expect(SetupConfigOutcome.failed.isFailure, isTrue);
      },
    );
  });
}
