import 'package:fl_clash/services/mihomo_config/structural_config_diff.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _apply(
  Map<String, dynamic> base,
  List<StructuralChange> changes,
) =>
    applyStructuralChanges(base, changes);

void main() {
  group('structural diff', () {
    test('1. scalar unchanged produces no diff', () {
      final changes = diffStructuralChanges(
        {'mode': 'rule'},
        {'mode': 'rule'},
      );
      expect(changes, isEmpty);
    });

    test('2. scalar update becomes a SET', () {
      final changes = diffStructuralChanges(
        {'mode': 'rule'},
        {'mode': 'global'},
      );
      expect(changes, hasLength(1));
      expect(changes.single.path, ['mode']);
      expect(changes.single.type, StructuralChangeType.set);
      expect(changes.single.value, 'global');
    });

    test('3. explicit null becomes SET null, not REMOVE', () {
      final changes = diffStructuralChanges(
        {'global-ua': 'old'},
        {'global-ua': null},
      );
      expect(changes, hasLength(1));
      expect(changes.single.type, StructuralChangeType.set);
      expect(changes.single.value, isNull);
    });

    test('4. new root key becomes SET', () {
      final changes = diffStructuralChanges(
        {'mode': 'rule'},
        {'mode': 'rule', 'ipv6': true},
      );
      expect(changes, hasLength(1));
      expect(changes.single.path, ['ipv6']);
      expect(changes.single.type, StructuralChangeType.set);
      expect(changes.single.value, isTrue);
    });

    test('5. root key delete becomes REMOVE', () {
      final changes = diffStructuralChanges(
        {'mode': 'rule', 'ipv6': true},
        {'mode': 'rule'},
      );
      expect(changes, hasLength(1));
      expect(changes.single.path, ['ipv6']);
      expect(changes.single.type, StructuralChangeType.remove);
    });

    test('6. nested key add', () {
      final changes = diffStructuralChanges(
        {
          'dns': {'enable': true},
        },
        {
          'dns': {'enable': true, 'listen': '127.0.0.1:53'},
        },
      );
      expect(changes, hasLength(1));
      expect(changes.single.path, ['dns', 'listen']);
      expect(changes.single.type, StructuralChangeType.set);
    });

    test('7. nested key update', () {
      final changes = diffStructuralChanges(
        {
          'dns': {'enable': true, 'cache-algorithm': 'arc'},
        },
        {
          'dns': {'enable': true, 'cache-algorithm': 'lru'},
        },
      );
      expect(changes, hasLength(1));
      expect(changes.single.path, ['dns', 'cache-algorithm']);
      expect(changes.single.value, 'lru');
    });

    test('8. nested key delete', () {
      final changes = diffStructuralChanges(
        {
          'dns': {'enable': true, 'nameserver': ['1.1.1.1']},
        },
        {
          'dns': {'enable': true},
        },
      );
      expect(changes, hasLength(1));
      expect(changes.single.path, ['dns', 'nameserver']);
      expect(changes.single.type, StructuralChangeType.remove);
    });

    test('9. unchanged list produces no diff', () {
      final changes = diffStructuralChanges(
        {'rules': ['A', 'B']},
        {'rules': ['A', 'B']},
      );
      expect(changes, isEmpty);
    });

    test('10. changed list becomes a whole-list SET', () {
      final changes = diffStructuralChanges(
        {'rules': ['A', 'B']},
        {'rules': ['C']},
      );
      expect(changes, hasLength(1));
      expect(changes.single.path, ['rules']);
      expect(changes.single.type, StructuralChangeType.set);
      expect(changes.single.value, ['C']);
    });

    test('11. map to scalar becomes a whole SET', () {
      final changes = diffStructuralChanges(
        {'dns': {'enable': true}},
        {'dns': 'off'},
      );
      expect(changes, hasLength(1));
      expect(changes.single.type, StructuralChangeType.set);
      expect(changes.single.value, 'off');
    });

    test('12. scalar to map becomes a whole SET', () {
      final changes = diffStructuralChanges(
        {'dns': 'off'},
        {'dns': {'enable': true}},
      );
      expect(changes, hasLength(1));
      expect(changes.single.type, StructuralChangeType.set);
      expect(changes.single.value, {'enable': true});
    });

    test('13. before is not mutated', () {
      final before = {
        'dns': {
          'enable': true,
          'nameserver': ['1.1.1.1'],
        },
      };
      diffStructuralChanges(before, {
        'dns': {'enable': false},
      });
      expect(before['dns'], {
        'enable': true,
        'nameserver': ['1.1.1.1'],
      });
    });

    test('14. after is not mutated', () {
      final after = {
        'dns': {
          'enable': false,
          'nameserver': ['8.8.8.8'],
        },
      };
      diffStructuralChanges({
        'dns': {'enable': true},
      }, after);
      expect(after['dns'], {
        'enable': false,
        'nameserver': ['8.8.8.8'],
      });
    });

    test('15. apply does not mutate the base', () {
      final base = {
        'dns': {
          'enable': true,
          'future-field': 'kept',
        },
      };
      _apply(base, [
        StructuralChange.set(['dns', 'enable'], false),
      ]);
      expect(base['dns'], {
        'enable': true,
        'future-field': 'kept',
      });
    });

    test('16. deep nested paths', () {
      final changes = diffStructuralChanges(
        {
          'experimental': {
            'quic-go-disable-gso': true,
            'dialer-ip4p-convert': true,
          },
        },
        {
          'experimental': {
            'quic-go-disable-gso': false,
            'dialer-ip4p-convert': true,
            'new': {'deep': 'value'},
          },
        },
      );
      final setPaths = changes
          .where((c) => c.type == StructuralChangeType.set)
          .map((c) => c.path)
          .toList();
      expect(
        setPaths,
        containsAll([
          ['experimental', 'quic-go-disable-gso'],
          // A brand-new nested map arrives as a whole-subtree SET (rule A).
          ['experimental', 'new'],
        ]),
      );
      expect(setPaths, isNot(contains(['experimental', 'new', 'deep'])));
    });
  });

  group('applyStructuralChanges', () {
    test('nested SET creates missing intermediate maps', () {
      final result = _apply({}, [
        StructuralChange.set(['a', 'b', 'c'], 1),
      ]);
      expect(result['a'], {
        'b': {'c': 1},
      });
    });

    test('whole value SET replaces the subtree', () {
      final result = _apply({
        'dns': {'enable': true, 'future-field': 'kept'},
      }, [
        StructuralChange.set(['dns'], {'enable': false}),
      ]);
      expect(result['dns'], {'enable': false});
    });

    test('REMOVE deletes the key', () {
      final result = _apply({
        'dns': {'enable': true, 'future-field': 'kept'},
      }, [
        StructuralChange.remove(['dns', 'future-field']),
      ]);
      expect(result['dns'], {'enable': true});
    });

    test('REMOVE of a missing key is a no-op', () {
      final result = _apply({'dns': {'enable': true}}, [
        StructuralChange.remove(['dns', 'missing']),
      ]);
      expect(result['dns'], {'enable': true});
    });

    test('explicit null is kept as null', () {
      final result = _apply({'global-ua': 'old'}, [
        StructuralChange.set(['global-ua'], null),
      ]);
      expect(result, containsPair('global-ua', null));
      expect(result.containsKey('global-ua'), isTrue);
    });

    test('lists are replaced atomically', () {
      final result = _apply({'rules': ['A']}, [
        StructuralChange.set(['rules'], ['X', 'Y']),
      ]);
      expect(result['rules'], ['X', 'Y']);
    });

    test('result is a deep copy; later edits do not touch the base', () {
      final base = {
        'dns': {
          'enable': true,
          'nameserver': ['1.1.1.1'],
        },
      };
      final result = _apply(base, [
        StructuralChange.set(['dns', 'enable'], false),
      ]);
      (result['dns'] as Map)['extra'] = 'mutated';
      (result['dns']['nameserver'] as List).add('mutated');
      expect(base['dns'], {
        'enable': true,
        'nameserver': ['1.1.1.1'],
      });
    });

    test('SET value is deep-copied into the result', () {
      final sourceList = ['A'];
      final result = _apply({}, [
        StructuralChange.set(['rules'], sourceList),
      ]);
      (result['rules'] as List).add('B');
      expect(sourceList, ['A']);
    });

    test('SET traversing a non-map value throws StateError', () {
      expect(
        () => _apply({
          'dns': 'off',
        }, [
          StructuralChange.set(['dns', 'enable'], true),
        ]),
        throwsStateError,
      );
    });
  });
}
