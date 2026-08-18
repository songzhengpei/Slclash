/// How a structural change modifies the preservation base.
enum StructuralChangeType { set, remove }

/// One structural change between a `before` and an `after` config map.
class StructuralChange {
  /// Path segments from the root map to the changed value.
  final List<String> path;

  final StructuralChangeType type;

  /// The new value for [StructuralChangeType.set]; always null for remove.
  final dynamic value;

  StructuralChange.set(this.path, this.value)
      : type = StructuralChangeType.set;

  StructuralChange.remove(this.path)
      : type = StructuralChangeType.remove,
        value = null;
}

/// Deep equality over JSON-compatible plain Dart structures. Used instead of
/// runtime string comparison so key order and identity never cause false
/// diffs.
bool deepConfigEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!deepConfigEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepConfigEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Returns a fresh deep copy of a JSON-compatible plain Dart structure.
dynamic deepCopyConfigValue(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): deepCopyConfigValue(entry.value),
    };
  }
  if (value is List) return value.map(deepCopyConfigValue).toList();
  return value;
}

/// Computes the structural diff from [before] to [after] as an ordered list
/// of changes.
///
/// Rules:
/// - Map to Map recurses over every key: added keys become [set], removed
///   keys become [remove], shared keys recurse.
/// - Lists compare by deep equality only: any inequality becomes a whole-list
///   [set]. List items are never structurally merged.
/// - Scalars become [set] when unequal.
/// - A type change (map/list/scalar/null) becomes a whole-value [set].
/// - `after` containing an explicit null is a [set] of null, never a remove.
List<StructuralChange> diffStructuralChanges(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final changes = <StructuralChange>[];
  _diffMap(before, after, const [], changes);
  return changes;
}

void _diffMap(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
  List<String> path,
  List<StructuralChange> changes,
) {
  for (final key in after.keys) {
    final childPath = [...path, key];
    if (!before.containsKey(key)) {
      changes.add(StructuralChange.set(childPath, deepCopyConfigValue(after[key])));
    } else {
      _diffValue(before[key], after[key], childPath, changes);
    }
  }
  for (final key in before.keys) {
    if (!after.containsKey(key)) {
      changes.add(StructuralChange.remove([...path, key]));
    }
  }
}

void _diffValue(
  dynamic before,
  dynamic after,
  List<String> path,
  List<StructuralChange> changes,
) {
  if (before is Map && after is Map) {
    _diffMap(
      Map<String, dynamic>.from(before),
      Map<String, dynamic>.from(after),
      path,
      changes,
    );
    return;
  }
  if (!deepConfigEquals(before, after)) {
    changes.add(StructuralChange.set(path, deepCopyConfigValue(after)));
  }
}

/// Applies [changes] onto [base] without mutating it, returning a deep-copied
/// result. Nested [set] paths create intermediate maps; [remove] deletes the
/// target key; whole-value [set] replaces the subtree; lists are atomic; an
/// explicit null is kept as null. Throws [StateError] when a [set] path
/// traverses a non-map value that cannot be created through.
Map<String, dynamic> applyStructuralChanges(
  Map<String, dynamic> base,
  List<StructuralChange> changes,
) {
  final result = Map<String, dynamic>.from(
    deepCopyConfigValue(base) as Map<String, dynamic>,
  );
  for (final change in changes) {
    final container = _navigateContainer(
      result,
      change.path,
      createMissing: change.type == StructuralChangeType.set,
    );
    if (container == null) {
      if (change.type == StructuralChangeType.remove) continue;
      throw StateError(
        'structural change ${change.path.join('.')} traverses a '
        'non-map value',
      );
    }
    final key = change.path.last;
    if (change.type == StructuralChangeType.remove) {
      container.remove(key);
    } else {
      container[key] = deepCopyConfigValue(change.value);
    }
  }
  return result;
}

Map<String, dynamic>? _navigateContainer(
  Map<String, dynamic> root,
  List<String> path, {
  required bool createMissing,
}) {
  var current = root;
  for (var i = 0; i < path.length - 1; i++) {
    final key = path[i];
    final next = current[key];
    if (next is Map<String, dynamic>) {
      current = next;
    } else if (next == null && createMissing) {
      final fresh = <String, dynamic>{};
      current[key] = fresh;
      current = fresh;
    } else {
      return null;
    }
  }
  return current;
}
