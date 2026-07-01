import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI-only cache for computed group (URL-test / Fallback / LoadBalance)
/// stable `now` values.
///
/// Purpose: when the mihomo runtime resets computed group `now` to a
/// fallback (DIRECT / REJECT / PASS) during lifecycle transitions, this
/// cache provides a fallback for display until the runtime auto-selects a
/// real node again.
///
/// Important:
/// - Never written to Profile.selectedMap (user manual selections only).
/// - Never fed back to coreController.changeProxy or patchSelectGroup.
/// - Never persisted — purely transient UI cache.
final computedSelectedCacheProvider =
    NotifierProvider<ComputedSelectedCache, Map<String, String>>(
  ComputedSelectedCache.new,
);

class ComputedSelectedCache extends Notifier<Map<String, String>> {
  /// Fallback placeholder values that MUST NOT be cached.
  static const _fallbackNames = <String>{'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'};

  @override
  Map<String, String> build() => {};

  /// Sync the cache from the current list of groups.
  ///
  /// Only caches a group's `now` when ALL of these hold:
  /// 1. group.type.isComputedSelected == true
  /// 2. group.now is non-empty
  /// 3. group.now is not a fallback placeholder
  /// 4. group.now exists in group.all
  void syncFromGroups(List<Group> groups) {
    final cache = <String, String>{};
    for (final group in groups) {
      if (!group.type.isComputedSelected) continue;
      final now = group.now;
      if (now == null || now.isEmpty) continue;
      if (_fallbackNames.contains(now.toUpperCase())) continue;
      if (!group.all.any((p) => p.name == now)) continue;
      cache[group.name] = now;
    }
    state = cache;
  }

  /// Get cached stable `now` for [groupName], or null if not cached.
  String? getCachedNow(String groupName) => state[groupName];
}
