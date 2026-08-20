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
}
