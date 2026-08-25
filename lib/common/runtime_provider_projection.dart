import 'package:fl_clash/common/runtime_profile_identity.dart';

final class RuntimeProviderProjectionSingleflight<T> {
  final Map<(RuntimeProfileIdentity, String), Future<T?>> _running = {};

  Future<T?> refresh({
    required RuntimeProfileIdentity identity,
    required String providerName,
    required bool Function(RuntimeProfileIdentity identity) isActive,
    required Future<T?> Function() fetch,
    required void Function(T? value) publish,
  }) {
    if (!isActive(identity)) return Future.value(null);
    final key = (identity, providerName);
    final running = _running[key];
    if (running != null) return running;
    final future = _refresh(
      identity: identity,
      isActive: isActive,
      fetch: fetch,
      publish: publish,
    );
    _running[key] = future;
    future.whenComplete(() {
      if (identical(_running[key], future)) _running.remove(key);
    });
    return future;
  }

  Future<T?> _refresh({
    required RuntimeProfileIdentity identity,
    required bool Function(RuntimeProfileIdentity identity) isActive,
    required Future<T?> Function() fetch,
    required void Function(T? value) publish,
  }) async {
    if (!isActive(identity)) return null;
    final value = await fetch();
    if (!isActive(identity)) return null;
    publish(value);
    return value;
  }
}

Future<void> runTrailingRuntimeRefreshLoop({
  required bool Function() isActive,
  required bool Function() takeDirty,
  required Future<void> Function() refresh,
  void Function()? onTrailing,
}) async {
  while (isActive()) {
    takeDirty();
    await refresh();
    if (!isActive() || !takeDirty()) return;
    onTrailing?.call();
  }
}
