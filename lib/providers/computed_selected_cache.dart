import 'package:fl_clash/enum/enum.dart';
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
  static const _fallbackNames = <String>{
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'PASS',
  };

  @override
  Map<String, String> build() => {};

  /// Incrementally sync the cache from the current list of groups.
  ///
  /// Rules:
  /// - If [groups] is empty, return without clearing cache (protect against
  ///   transient empty states during core restart).
  /// - When a computed group has a real (non-fallback) [now] that exists in
  ///   [group.all], update the cache entry.
  /// - When [now] is a fallback placeholder, do NOT overwrite — keep the
  ///   previous stable cache intact.
  /// - If a previously cached node no longer exists in [group.all], remove
  ///   that group's cache entry (stale node eviction).
  /// - Groups that are not [isComputedSelected] are ignored.
  void syncFromGroups(List<Group> groups) {
    if (groups.isEmpty) return;

    final cache = Map<String, String>.from(state);
    final computedGroups =
        groups.where((g) => g.type.isComputedSelected).toList();
    final computedGroupNames = computedGroups.map((g) => g.name).toSet();

    // Evict groups that no longer exist or whose cached node is gone
    cache.removeWhere((groupName, cachedNode) {
      if (!computedGroupNames.contains(groupName)) return true;
      final group = computedGroups.firstWhere((g) => g.name == groupName);
      return !group.all.any((p) => p.name == cachedNode);
    });

    // Update cache for groups that have a real stable now
    for (final group in computedGroups) {
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
