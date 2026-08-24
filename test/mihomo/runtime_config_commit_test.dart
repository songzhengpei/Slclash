import 'dart:async';

import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/services/mihomo_config/runtime_config_commit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runtime config commit ownership', () {
    test(
      'outer apply updateGroups display fallback does not wait on itself',
      () async {
        final owner = RuntimeConfigCommitOwner();
        final targetA = Profile.normal(label: 'A', url: 'profile-a');
        final a = owner.beginRequest();
        final events = <String>[];

        final outcome = await owner
            .commit(
              generation: a,
              transaction: (lease) async {
                events.add('A-setup');
                final context = RuntimeConfigPostUpdateContext(
                  lease: lease,
                  targetProfile: targetA,
                );
                Future<void> applyProfileForDisplay(
                  RuntimeConfigPostUpdateContext inheritedContext,
                ) => owner.continueCommit(
                  lease: inheritedContext.lease,
                  transaction: (_) async {
                    events.add(
                      '${inheritedContext.targetProfile?.label}-display-write-setup',
                    );
                  },
                );
                Future<void> updateGroupsWithInvalidFallback(
                  RuntimeConfigPostUpdateContext inheritedContext,
                ) => applyProfileForDisplay(inheritedContext);
                await updateGroupsWithInvalidFallback(context);
                events.add('A-onUpdated-done');
              },
            )
            .timeout(const Duration(seconds: 1));

        expect(outcome, RuntimeConfigCommitOutcome.committed);
        expect(events, [
          'A-setup',
          'A-display-write-setup',
          'A-onUpdated-done',
        ]);
      },
    );

    test(
      'active A continuation finishes before waiting B and does not supersede B',
      () async {
        final owner = RuntimeConfigCommitOwner();
        final targetA = Profile.normal(label: 'A', url: 'profile-a');
        final targetB = Profile.normal(label: 'B', url: 'profile-b');
        final a = owner.beginRequest();
        final events = <String>[];
        late Future<RuntimeConfigCommitOutcome> bCommit;

        final aCommit = owner.commit(
          generation: a,
          transaction: (lease) async {
            events.add('A-setup');
            final context = RuntimeConfigPostUpdateContext(
              lease: lease,
              targetProfile: targetA,
            );
            final b = owner.beginRequest();
            bCommit = owner.commit(
              generation: b,
              transaction: (_) async {
                events.add('${targetB.label}-setup');
              },
            );
            await owner.continueCommit(
              lease: context.lease,
              transaction: (_) async {
                events.add(
                  '${context.targetProfile?.label}-display-write-setup',
                );
              },
            );
            events.add('A-done');
          },
        );

        expect(await aCommit, RuntimeConfigCommitOutcome.committed);
        expect(await bCommit, RuntimeConfigCommitOutcome.committed);
        expect(events, [
          'A-setup',
          'A-display-write-setup',
          'A-done',
          'B-setup',
        ]);
        expect(owner.beginRequest(), 3);
      },
    );

    test(
      'stale A projection is discarded while queued B becomes final authority',
      () async {
        final owner = RuntimeConfigCommitOwner();
        const targetA = Profile(
          id: 1,
          label: 'A',
          autoUpdateDuration: Duration.zero,
          selectedMap: {'group': 'proxy-A'},
        );
        const targetB = Profile(
          id: 2,
          label: 'B',
          autoUpdateDuration: Duration.zero,
          selectedMap: {'group': 'proxy-B'},
        );
        var currentProfileId = targetA.id;
        var runtimeProfileId = 0;
        int? groupsOwnerProfileId;
        var providers = 'providers-initial';
        final aSetupDone = Completer<void>();
        final releaseAUpdate = Completer<void>();
        final events = <String>[];

        final a = owner.beginRequest();
        final aCommit = owner.commit(
          generation: a,
          transaction: (lease) async {
            final context = RuntimeConfigPostUpdateContext(
              lease: lease,
              targetProfile: targetA,
            );
            runtimeProfileId = context.targetProfileId!;
            events.add('A-setup');
            aSetupDone.complete();
            await releaseAUpdate.future;

            expect(context.targetProfileId, targetA.id);
            expect(context.targetProfile?.selectedMap, {'group': 'proxy-A'});
            if (currentProfileId == context.targetProfileId) {
              groupsOwnerProfileId = context.targetProfileId;
              providers = 'providers-A';
              events.add('A-projection-published');
            } else {
              events.add('A-projection-discarded');
            }
          },
        );
        await aSetupDone.future;

        currentProfileId = targetB.id;
        final b = owner.beginRequest();
        final bCommit = owner.commit(
          generation: b,
          transaction: (_) async {
            runtimeProfileId = targetB.id;
            groupsOwnerProfileId = targetB.id;
            providers = 'providers-B';
            events.add('B-setup-and-projection');
          },
        );
        await Future<void>.delayed(Duration.zero);

        expect(runtimeProfileId, targetA.id);
        expect(events, ['A-setup']);
        releaseAUpdate.complete();

        expect(await aCommit, RuntimeConfigCommitOutcome.committed);
        expect(await bCommit, RuntimeConfigCommitOutcome.committed);
        expect(events, [
          'A-setup',
          'A-projection-discarded',
          'B-setup-and-projection',
        ]);
        expect(runtimeProfileId, targetB.id);
        expect(groupsOwnerProfileId, targetB.id);
        expect(providers, 'providers-B');
      },
    );

    test('A context never resolves dynamically to selected B or C', () async {
      final owner = RuntimeConfigCommitOwner();
      const targetA = Profile(
        id: 1,
        label: 'A',
        autoUpdateDuration: Duration.zero,
        selectedMap: {'group': 'proxy-A'},
      );
      var currentProfileId = targetA.id;
      final a = owner.beginRequest();

      final outcome = await owner.commit(
        generation: a,
        transaction: (lease) async {
          final context = RuntimeConfigPostUpdateContext(
            lease: lease,
            targetProfile: targetA,
          );
          currentProfileId = 2;
          expect(context.targetProfileId, targetA.id);
          expect(context.targetProfile?.selectedMap['group'], 'proxy-A');
          currentProfileId = 3;
          expect(context.targetProfileId, targetA.id);
          expect(currentProfileId, isNot(context.targetProfileId));
        },
      );

      expect(outcome, RuntimeConfigCommitOutcome.committed);
    });

    test('nested failure releases ownership for future applies', () async {
      final owner = RuntimeConfigCommitOwner();
      final a = owner.beginRequest();

      await expectLater(
        owner.commit(
          generation: a,
          transaction: (lease) => owner.continueCommit(
            lease: lease,
            transaction: (_) async => throw StateError('display failed'),
          ),
        ),
        throwsStateError,
      );

      final b = owner.beginRequest();
      final events = <String>[];
      final outcome = await owner
          .commit(generation: b, transaction: (_) async => events.add('B'))
          .timeout(const Duration(seconds: 1));
      expect(outcome, RuntimeConfigCommitOutcome.committed);
      expect(events, ['B']);
    });

    test('slow A materializing after fast B is superseded', () async {
      final owner = RuntimeConfigCommitOwner();
      final a = owner.beginRequest();
      final b = owner.beginRequest();
      final commits = <String>[];

      final bOutcome = await owner.commit(
        generation: b,
        transaction: (_) async => commits.add('B'),
      );
      final aOutcome = await owner.commit(
        generation: a,
        transaction: (_) async => commits.add('A'),
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
        transaction: (_) async => commits.add('old-A'),
      );
      final newOutcome = await owner.commit(
        generation: newA,
        transaction: (_) async => commits.add('new-A'),
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
        transaction: (_) async {
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
        transaction: (_) async {
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
      var preloads = 0;
      var updates = 0;

      final outcome = await owner.commit(
        generation: stale,
        transaction: (_) async {
          writes++;
          setups++;
          preloads++;
          updates++;
        },
      );

      expect(outcome, RuntimeConfigCommitOutcome.superseded);
      expect(writes, 0);
      expect(setups, 0);
      expect(preloads, 0);
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
        transaction: (_) async {
          aStarted.complete();
          await releaseA.future;
          commits.add('A');
        },
      );
      await aStarted.future;

      final b = owner.beginRequest();
      final bCommit = owner.commit(
        generation: b,
        transaction: (_) async => commits.add('B'),
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
        transaction: (_) async {
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
        transaction: (_) async {
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
          transaction: (_) async => fail('stale transaction must not run'),
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
