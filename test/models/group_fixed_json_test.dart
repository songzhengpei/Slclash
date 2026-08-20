import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URLTest fixed absent is null', () {
    final group = Group.fromJson({
      'type': 'url-test',
      'name': 'auto',
      'all': <Map<String, dynamic>>[],
    });
    expect(group.fixed, isNull);
  });

  test('URLTest fixed empty is automatic', () {
    final group = Group.fromJson({
      'type': 'url-test',
      'name': 'auto',
      'fixed': '',
      'now': 'A',
    });
    expect(group.fixed, '');
    expect(group.now, 'A');
  });

  test('URLTest fixed node is pin', () {
    final group = Group.fromJson({
      'type': 'url-test',
      'name': 'auto',
      'fixed': 'Hong Kong',
      'now': 'Hong Kong',
    });
    expect(group.fixed, 'Hong Kong');
  });

  test('Fallback fixed roundtrip', () {
    const original = Group(
      type: GroupType.Fallback,
      name: 'fb',
      now: 'B',
      fixed: 'B',
    );
    final parsed = Group.fromJson(original.toJson());
    expect(parsed.fixed, 'B');
    expect(parsed.type, GroupType.Fallback);
  });

  test('Selector fixed absent is null after roundtrip', () {
    const original = Group(type: GroupType.Selector, name: 'sel', now: 'A');
    final parsed = Group.fromJson(original.toJson());
    expect(parsed.fixed, isNull);
  });

  test('LoadBalance fixed absent is null', () {
    final group = Group.fromJson({
      'type': 'load-balance',
      'name': 'lb',
      'all': <Map<String, dynamic>>[],
    });
    expect(group.fixed, isNull);
    expect(group.now, isNull);
  });

  test('snapshot hydrate preserves fixed A', () {
    const snapshot = Group(
      type: GroupType.URLTest,
      name: 'auto',
      fixed: 'A',
      now: 'A',
      all: [Proxy(name: 'A', type: 'ss')],
    );
    final encoded = jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>;
    final hydrated = Group.fromJson(encoded);
    expect(hydrated.fixed, 'A');
  });

  test('fresh Core automatic must not keep snapshot pin in the same object', () {
    const stale = Group(type: GroupType.URLTest, name: 'auto', fixed: 'A');
    const fresh = Group(type: GroupType.URLTest, name: 'auto', fixed: '');
    expect(stale.fixed, 'A');
    expect(fresh.fixed, '');
    expect(identical(stale, fresh), isFalse);
  });
}
