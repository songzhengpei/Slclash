import 'dart:async';

import 'package:fl_clash/services/profile_source_mutation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileSourceMutationOwner', () {
    test('late older request cannot overwrite a newer request', () async {
      final owner = ProfileSourceMutationOwner();
      final first = owner.begin(1);
      final second = owner.begin(1);
      var source = '';

      final secondOutcome = await owner.commit(second, () async {
        source = 'second';
      });
      final firstOutcome = await owner.commit(first, () async {
        source = 'first';
      });

      expect(secondOutcome, ProfileSourceMutationOutcome.committed);
      expect(firstOutcome, ProfileSourceMutationOutcome.superseded);
      expect(source, 'second');
    });

    test('newer request waits for an already active commit', () async {
      final owner = ProfileSourceMutationOwner();
      final first = owner.begin(1);
      final firstEntered = Completer<void>();
      final releaseFirst = Completer<void>();
      final order = <String>[];

      final firstCommit = owner.commit(first, () async {
        order.add('first-start');
        firstEntered.complete();
        await releaseFirst.future;
        order.add('first-end');
      });
      await firstEntered.future;
      final second = owner.begin(1);
      final secondCommit = owner.commit(second, () async {
        order.add('second');
      });

      await Future<void>.delayed(Duration.zero);
      expect(order, ['first-start']);
      releaseFirst.complete();

      expect(await firstCommit, ProfileSourceMutationOutcome.committed);
      expect(await secondCommit, ProfileSourceMutationOutcome.committed);
      expect(order, ['first-start', 'first-end', 'second']);
    });

    test('different profile ids have independent commit gates', () async {
      final owner = ProfileSourceMutationOwner();
      final releaseA = Completer<void>();
      final aEntered = Completer<void>();
      var bCommitted = false;

      final aCommit = owner.commit(owner.begin(1), () async {
        aEntered.complete();
        await releaseA.future;
      });
      await aEntered.future;
      final bCommit = owner.commit(owner.begin(2), () async {
        bCommitted = true;
      });

      await bCommit;
      expect(bCommitted, isTrue);
      expect(releaseA.isCompleted, isFalse);
      releaseA.complete();
      await aCommit;
    });

    test('delete invalidates a request still outside commit', () async {
      final owner = ProfileSourceMutationOwner();
      final old = owner.begin(1);
      var exists = true;

      await owner.invalidateAndCommit(1, () async {
        exists = false;
      });
      final oldOutcome = await owner.commit(old, () async {
        exists = true;
      });

      expect(oldOutcome, ProfileSourceMutationOutcome.superseded);
      expect(exists, isFalse);
    });

    test('delete waits behind an active commit and wins finally', () async {
      final owner = ProfileSourceMutationOwner();
      final entered = Completer<void>();
      final release = Completer<void>();
      var exists = false;

      final update = owner.commit(owner.begin(1), () async {
        entered.complete();
        await release.future;
        exists = true;
      });
      await entered.future;
      final deletion = owner.invalidateAndCommit(1, () async {
        exists = false;
      });
      await Future<void>.delayed(Duration.zero);
      expect(exists, isFalse);

      release.complete();
      await update;
      await deletion;
      expect(exists, isFalse);
    });

    test('pre-delete token stays stale in a recreated lifetime', () async {
      final owner = ProfileSourceMutationOwner();
      final old = owner.begin(1);
      await owner.invalidateAndCommit(1, () async {});
      final recreated = owner.begin(1);
      var source = '';

      expect(
        await owner.commit(old, () async => source = 'old'),
        ProfileSourceMutationOutcome.superseded,
      );
      expect(
        await owner.commit(recreated, () async => source = 'recreated'),
        ProfileSourceMutationOutcome.committed,
      );
      expect(source, 'recreated');
    });

    test('restore-style commit invalidates only its affected profiles', () async {
      final owner = ProfileSourceMutationOwner();
      final oldA = owner.begin(1);
      final oldB = owner.begin(2);
      final unrelated = owner.begin(3);
      var restored = false;

      await owner.invalidateAndCommitAll({1, 2}, () async {
        restored = true;
      });

      expect(restored, isTrue);
      expect(
        await owner.commit(oldA, () async {}),
        ProfileSourceMutationOutcome.superseded,
      );
      expect(
        await owner.commit(oldB, () async {}),
        ProfileSourceMutationOutcome.superseded,
      );
      expect(
        await owner.commit(unrelated, () async {}),
        ProfileSourceMutationOutcome.committed,
      );
    });
  });
}
