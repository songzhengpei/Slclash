import 'package:fake_async/fake_async.dart';
import 'package:fl_clash/common/function.dart';
import 'package:fl_clash/common/proxy_group_selection.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        selectedNameForGroup(group, selectedMapValue: 'A', cachedComputedNow: 'A'),
        isNull,
      );
    });
  });

  group('core failure / race', () {
    test('empty result is success', () {
      expect(isCoreSelectionSuccess(''), isTrue);
      expect(isCoreSelectionSuccess('Must be a Selector'), isFalse);
      expect(isCoreSelectionSuccess('proxy not exist'), isFalse);
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

    test('A then B then C in one burst only sends C and restores A on fail', () {
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

  void dispatchSelect(String group, String name) {
    final previous = session.peek(group);
    final result = coreSelect(group, name);
    coreCalls.add('select:$group:$name');
    if (isCoreSelectionSuccess(result)) {
      session.complete(group);
      close++;
      checkIp++;
      return;
    }
    final current = map[group];
    final rollback = shouldRollbackOptimisticIntent(
      currentIntent: current,
      failedIntent: name,
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
      newerIntentPending: !rollback && current != name,
    );
  }
}
