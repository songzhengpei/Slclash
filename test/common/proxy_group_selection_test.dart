import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fl_clash/common/function.dart';
import 'package:fl_clash/common/proxy_group_selection.dart';
import 'package:fl_clash/common/runtime_profile_identity.dart';
import 'package:fl_clash/core/command_outcome.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runtime profile identity', () {
    test('A to B to A never reactivates the old A epoch', () {
      const oldA = RuntimeProfileIdentity(profileId: 1, epoch: 0);

      expect(
        isRuntimeProfileIdentityCurrent(
          identity: oldA,
          currentProfileId: 1,
          currentEpoch: 2,
        ),
        isFalse,
      );
    });

    test('stale debounce does not dispatch its Core mutation', () async {
      const oldA = RuntimeProfileIdentity(profileId: 1, epoch: 0);
      var coreCalls = 0;

      final result = await runRuntimeMutationIfCurrent(
        identity: oldA,
        isCurrent: (_) => false,
        mutation: () async {
          coreCalls++;
          return '';
        },
      );

      expect(result.current, isFalse);
      expect(coreCalls, 0);
    });

    test('completion is discarded after identity changes in flight', () async {
      const oldA = RuntimeProfileIdentity(profileId: 1, epoch: 0);
      var currentProfileId = 1;
      var currentEpoch = 0;
      final coreResult = Completer<String>();

      final resultFuture = runRuntimeMutationIfCurrent(
        identity: oldA,
        isCurrent: (identity) => isRuntimeProfileIdentityCurrent(
          identity: identity,
          currentProfileId: currentProfileId,
          currentEpoch: currentEpoch,
        ),
        mutation: () => coreResult.future,
      );
      currentProfileId = 2;
      currentEpoch = 1;
      coreResult.complete('');

      expect((await resultFuture).current, isFalse);
    });

    test('same group name uses isolated profile lifetime sessions', () {
      const a = RuntimeProfileIdentity(profileId: 1, epoch: 0);
      const b = RuntimeProfileIdentity(profileId: 2, epoch: 1);
      final session = ProxySelectionSession();
      const aKey = (a, 'same-group');
      const bKey = (b, 'same-group');

      session.captureBaseline(aKey, 'A-old');
      session.captureBaseline(bKey, 'B-old');

      expect(session.peek(aKey), 'A-old');
      expect(session.peek(bKey), 'B-old');
    });
  });

  group('capabilities', () {
    test('Selector', () {
      expect(GroupType.Selector.supportsManualSelection, isTrue);
      expect(GroupType.Selector.supportsFixedSelection, isFalse);
    });
    test('URLTest', () {
      expect(GroupType.URLTest.supportsManualSelection, isTrue);
      expect(GroupType.URLTest.supportsFixedSelection, isTrue);
    });
    test('Fallback', () {
      expect(GroupType.Fallback.supportsManualSelection, isTrue);
      expect(GroupType.Fallback.supportsFixedSelection, isTrue);
    });
    test('LoadBalance', () {
      expect(GroupType.LoadBalance.supportsManualSelection, isFalse);
      expect(GroupType.LoadBalance.supportsFixedSelection, isFalse);
    });
    test('Relay', () {
      expect(GroupType.Relay.supportsManualSelection, isFalse);
      expect(GroupType.Relay.supportsFixedSelection, isFalse);
    });
  });

  group('URLTest/Fallback tap', () {
    test('automatic tap B is pin not unfix', () {
      final d = resolveProxyGroupTap(
        type: GroupType.URLTest,
        fixed: '',
        tappedName: 'B',
      );
      expect(d.kind, ProxyGroupTapKind.select);
      expect(d.proxyName, 'B');
    });

    test('automatic tap current now A is pin not unfix', () {
      final d = resolveProxyGroupTap(
        type: GroupType.Fallback,
        fixed: '',
        tappedName: 'A',
      );
      expect(d.kind, ProxyGroupTapKind.select);
      expect(d.proxyName, 'A');
    });

    test('fixed A tap A is unfix not PUT empty', () {
      final d = resolveProxyGroupTap(
        type: GroupType.URLTest,
        fixed: 'A',
        tappedName: 'A',
      );
      expect(d.kind, ProxyGroupTapKind.unfix);
      expect(d.proxyName, '');
    });

    test('fixed A tap B is pin B', () {
      final d = resolveProxyGroupTap(
        type: GroupType.Fallback,
        fixed: 'A',
        tappedName: 'B',
      );
      expect(d.kind, ProxyGroupTapKind.select);
      expect(d.proxyName, 'B');
    });
  });

  group('LoadBalance tap', () {
    test('member tap is ignored', () {
      final d = resolveProxyGroupTap(
        type: GroupType.LoadBalance,
        fixed: null,
        tappedName: 'A',
      );
      expect(d.kind, ProxyGroupTapKind.ignore);
    });

    test('selectedNameForGroup is not local selectedMap', () {
      const group = Group(
        name: 'lb',
        type: GroupType.LoadBalance,
        now: '',
        all: [Proxy(name: 'A', type: 'ss')],
      );
      expect(
        selectedNameForGroup(
          group,
          selectedMapValue: 'A',
          cachedComputedNow: 'A',
        ),
        isNull,
      );
    });
  });

  group('core failure / race', () {
    test('empty result is success', () {
      expect(isCoreSelectionSuccess(''), isTrue);
      expect(isCoreSelectionSuccess('Must be a Selector'), isFalse);
      expect(isCoreSelectionSuccess('proxy not exist'), isFalse);
      expect(isCoreSelectionSuccess(CoreCommandOutcome.unconfirmed), isFalse);
    });

    test('failed A does not rollback newer B', () {
      expect(
        shouldRollbackOptimisticIntent(currentIntent: 'B', failedIntent: 'A'),
        isFalse,
      );
    });

    test('failed A rollbacks when still A', () {
      expect(
        shouldRollbackOptimisticIntent(currentIntent: 'A', failedIntent: 'A'),
        isTrue,
      );
    });

    test('unfix failure keeps pin when user already selected B', () {
      expect(
        shouldRollbackOptimisticIntent(currentIntent: 'B', failedIntent: ''),
        isFalse,
      );
    });
  });

  test('fixed mark only when Core fixed equals member', () {
    expect(
      groupShowsFixedMark(type: GroupType.URLTest, fixed: 'A', proxyName: 'A'),
      isTrue,
    );
    expect(
      groupShowsFixedMark(type: GroupType.URLTest, fixed: '', proxyName: 'A'),
      isFalse,
    );
    expect(
      groupShowsFixedMark(
        type: GroupType.LoadBalance,
        fixed: null,
        proxyName: 'A',
      ),
      isFalse,
    );
  });

  test('same now with changed fixed is not equal', () {
    const auto = Group(
      name: 'auto',
      type: GroupType.URLTest,
      now: 'A',
      fixed: '',
    );
    const pinned = Group(
      name: 'auto',
      type: GroupType.URLTest,
      now: 'A',
      fixed: 'A',
    );
    expect(groupsListsEqual([auto], [pinned]), isFalse);
    expect(groupsListsEqual([auto], [auto]), isTrue);
  });

  group('selection transaction', () {
    test('Core A tap B error restores A and skips connection side effects', () {
      final h = _SelectionHarness()..map['g'] = 'A';
      h.coreSelect = (_, __) => 'Must be a Selector';
      h.optimisticTap('g', 'B');
      expect(h.map['g'], 'B');
      h.dispatchSelect('g', 'B');
      expect(h.map['g'], 'A');
      expect(h.coreCalls, ['select:g:B']);
      expect(h.close, 0);
      expect(h.reset, 0);
      expect(h.checkIp, 0);
    });

    test(
      'A then B then C in one burst only sends C and restores A on fail',
      () {
        fakeAsync((async) {
          final h = _SelectionHarness()..map['g'] = 'A';
          h.coreSelect = (_, name) => name == 'C' ? 'proxy not exist' : '';
          final debouncer = Debouncer();
          void tap(String name) {
            h.optimisticTap('g', name);
            debouncer.call(proxySelectionDebounceTag('g'), () {
              h.dispatchSelect('g', name);
            });
          }

          tap('B');
          async.elapse(const Duration(milliseconds: 300));
          tap('C');
          async.elapse(const Duration(milliseconds: 600));
          expect(h.coreCalls, ['select:g:C']);
          expect(h.map['g'], 'A');
          expect(h.close + h.reset + h.checkIp, 0);
        });
      },
    );

    test('in-flight B success then C fail rolls back to B', () {
      fakeAsync((async) {
        final h = _SelectionHarness()..map['g'] = 'A';
        final bCore = Completer<String>();
        final debouncer = Debouncer();
        void tap(String name, Future<String> core) {
          h.optimisticTap('g', name);
          debouncer.call(proxySelectionDebounceTag('g'), () {
            h.dispatchSelectAsync('g', name, core);
          });
        }

        tap('B', bCore.future);
        async.elapse(const Duration(milliseconds: 600));
        expect(h.coreCalls, ['select:g:B']);
        tap('C', Future.value('proxy not exist'));
        bCore.complete('');
        async.flushMicrotasks();
        expect(h.map['g'], 'C');
        expect(h.session.peek('g'), 'B');
        expect(h.close, 1);
        expect(h.checkIp, 1);
        async.elapse(const Duration(milliseconds: 600));
        expect(h.coreCalls, ['select:g:B', 'select:g:C']);
        expect(h.map['g'], 'B');
        expect(h.session.peek('g'), isNull);
        expect(h.close, 1);
        expect(h.reset, 0);
        expect(h.checkIp, 1);
      });
    });

    test('in-flight unfix success then B fail rolls back to empty', () {
      fakeAsync((async) {
        final h = _SelectionHarness()..map['g'] = 'A';
        final unfixCore = Completer<String>();
        final debouncer = Debouncer();
        h.optimisticUnfix('g');
        debouncer.call(proxySelectionDebounceTag('g'), () {
          h.dispatchUnfixAsync('g', unfixCore.future);
        });
        async.elapse(const Duration(milliseconds: 600));
        h.optimisticTap('g', 'B');
        debouncer.call(proxySelectionDebounceTag('g'), () {
          h.dispatchSelectAsync('g', 'B', Future.value('proxy not exist'));
        });
        unfixCore.complete('');
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 600));
        expect(h.coreCalls, ['unfix:g', 'select:g:B']);
        expect(h.map['g'], '');
        expect(h.session.peek('g'), isNull);
        expect(h.close, 1);
        expect(h.checkIp, 1);
      });
    });

    test(
      'changeProxy transport unconfirmed rolls back without close or checkIp',
      () {
        fakeAsync((async) {
          final h = _SelectionHarness()..map['g'] = 'A';
          h.optimisticTap('g', 'B');
          h.dispatchSelectAsync(
            'g',
            'B',
            Future.value(CoreCommandOutcome.unconfirmed),
          );
          async.flushMicrotasks();
          expect(h.map['g'], 'A');
          expect(h.close, 0);
          expect(h.checkIp, 0);
          expect(h.session.peek('g'), isNull);
        });
      },
    );

    test('unfix transport unconfirmed rolls back without close or checkIp', () {
      fakeAsync((async) {
        final h = _SelectionHarness()..map['g'] = 'A';
        h.optimisticUnfix('g');
        h.dispatchUnfixAsync('g', Future.value(CoreCommandOutcome.unconfirmed));
        async.flushMicrotasks();
        expect(h.map['g'], 'A');
        expect(h.close, 0);
        expect(h.checkIp, 0);
      });
    });

    test('two groups within 600ms both write Core', () {
      fakeAsync((async) {
        final h = _SelectionHarness()
          ..map['g1'] = 'A'
          ..map['g2'] = 'X';
        final debouncer = Debouncer();
        h.optimisticTap('g1', 'B');
        debouncer.call(proxySelectionDebounceTag('g1'), () {
          h.dispatchSelect('g1', 'B');
        });
        async.elapse(const Duration(milliseconds: 300));
        h.optimisticTap('g2', 'Y');
        debouncer.call(proxySelectionDebounceTag('g2'), () {
          h.dispatchSelect('g2', 'Y');
        });
        async.elapse(const Duration(milliseconds: 600));
        expect(h.coreCalls, ['select:g1:B', 'select:g2:Y']);
        expect(h.map['g1'], 'B');
        expect(h.map['g2'], 'Y');
        expect(h.checkIp, 2);
      });
    });
  });
}

class _SelectionHarness {
  final session = ProxySelectionSession();
  final map = <String, String>{};
  final coreCalls = <String>[];
  var close = 0;
  var reset = 0;
  var checkIp = 0;
  String Function(String group, String proxy) coreSelect = (_, __) => '';

  void optimisticTap(String group, String name) {
    session.captureBaseline(group, map[group]);
    map[group] = name;
  }

  void optimisticUnfix(String group) {
    session.captureBaseline(group, map[group]);
    map[group] = '';
  }

  void dispatchSelect(String group, String name) {
    coreCalls.add('select:$group:$name');
    _finish(
      group: group,
      submitted: name,
      previous: session.peek(group),
      result: coreSelect(group, name),
    );
  }

  Future<void> dispatchSelectAsync(
    String group,
    String name,
    Future<String> core,
  ) async {
    coreCalls.add('select:$group:$name');
    final previous = session.peek(group);
    final result = await core;
    _finish(group: group, submitted: name, previous: previous, result: result);
  }

  Future<void> dispatchUnfixAsync(String group, Future<String> core) async {
    coreCalls.add('unfix:$group');
    final previous = session.peek(group);
    final result = await core;
    _finish(group: group, submitted: '', previous: previous, result: result);
  }

  void _finish({
    required String group,
    required String submitted,
    required String? previous,
    required String result,
  }) {
    if (isCoreSelectionSuccess(result)) {
      session.commitWithNewerIntent(
        groupName: group,
        committedValue: submitted,
        currentIntent: map[group],
      );
      close++;
      checkIp++;
      return;
    }
    final current = map[group];
    final rollback = shouldRollbackOptimisticIntent(
      currentIntent: current,
      failedIntent: submitted,
    );
    if (rollback) {
      if (previous == null) {
        map.remove(group);
      } else {
        map[group] = previous;
      }
    }
    session.completeUnlessNewerIntent(
      groupName: group,
      newerIntentPending: !rollback && current != submitted,
    );
  }
}
