import 'dart:async';

enum ProfileSourceMutationOutcome { committed, superseded }

final class ProfileSourceMutationToken {
  const ProfileSourceMutationToken._(
    this.profileId,
    this.generation,
    this._state,
  );

  final int profileId;
  final int generation;
  final _ProfileSourceMutationState _state;
}

final class _ProfileSourceMutationState {
  int generation = 0;
  Future<void> tail = Future<void>.value();
}

/// Owns source-file lifetimes and final commits independently per profile id.
///
/// Downloading, staging, and validation happen before [commit]. The callback is
/// the non-interleavable authoritative section for that profile only.
final class ProfileSourceMutationOwner {
  final Map<int, _ProfileSourceMutationState> _states = {};

  _ProfileSourceMutationState _stateFor(int profileId) =>
      _states.putIfAbsent(profileId, _ProfileSourceMutationState.new);

  ProfileSourceMutationToken begin(int profileId) {
    final state = _stateFor(profileId);
    return ProfileSourceMutationToken._(profileId, ++state.generation, state);
  }

  bool isCurrent(ProfileSourceMutationToken token) =>
      identical(_states[token.profileId], token._state) &&
      token.generation == token._state.generation;

  Future<ProfileSourceMutationOutcome> commit(
    ProfileSourceMutationToken token,
    Future<void> Function() transaction,
  ) async {
    final state = token._state;
    final predecessor = state.tail;
    final release = Completer<void>();
    state.tail = release.future;
    await predecessor;
    try {
      if (!isCurrent(token)) {
        return ProfileSourceMutationOutcome.superseded;
      }
      await transaction();
      return ProfileSourceMutationOutcome.committed;
    } finally {
      release.complete();
    }
  }

  /// Invalidates every token issued for [profileId] before waiting for the
  /// profile's active commit, then runs deletion under the same commit gate.
  Future<void> invalidateAndCommit(
    int profileId,
    Future<void> Function() transaction,
  ) async {
    final state = _stateFor(profileId);
    ++state.generation;
    final predecessor = state.tail;
    final release = Completer<void>();
    state.tail = release.future;
    await predecessor;
    try {
      await transaction();
    } finally {
      release.complete();
    }
  }

  /// Reserves all affected per-profile gates together for a restore/import
  /// transaction. Generations are invalidated before waiting on active commits.
  Future<void> invalidateAndCommitAll(
    Iterable<int> profileIds,
    Future<void> Function() transaction,
  ) async {
    final states = profileIds.toSet().map(_stateFor).toList();
    for (final state in states) {
      ++state.generation;
    }
    final predecessors = <Future<void>>[];
    final releases = <Completer<void>>[];
    for (final state in states) {
      predecessors.add(state.tail);
      final release = Completer<void>();
      releases.add(release);
      state.tail = release.future;
    }
    await Future.wait(predecessors);
    try {
      await transaction();
    } finally {
      for (final release in releases) {
        release.complete();
      }
    }
  }
}

final profileSourceMutationOwner = ProfileSourceMutationOwner();
