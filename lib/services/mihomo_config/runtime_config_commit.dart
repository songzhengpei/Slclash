import 'dart:async';

enum RuntimeConfigCommitOutcome { committed, superseded }

enum SetupConfigOutcome { applied, unchanged, superseded, failed }

extension SetupConfigOutcomeSemantics on SetupConfigOutcome {
  bool get isFailure => this == SetupConfigOutcome.failed;

  bool get mayContinueStart =>
      this == SetupConfigOutcome.applied ||
      this == SetupConfigOutcome.unchanged;
}

final class RuntimeConfigCommitLease {
  RuntimeConfigCommitLease._(this._owner, this.generation);

  final RuntimeConfigCommitOwner _owner;
  final int generation;
}

/// SetupAction-owned commit gate for the shared runtime config file.
///
/// Expensive materialization stays outside this gate. Only the final
/// freshness check and the write/setup/post-commit transaction are serialized.
final class RuntimeConfigCommitOwner {
  int _latestGeneration = 0;
  Future<void> _tail = Future<void>.value();
  RuntimeConfigCommitLease? _activeLease;

  int beginRequest() => ++_latestGeneration;

  bool isLatest(int generation) => generation == _latestGeneration;

  Future<RuntimeConfigCommitOutcome> commit({
    required int generation,
    required Future<void> Function(RuntimeConfigCommitLease lease) transaction,
  }) async {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await predecessor;
    try {
      if (generation != _latestGeneration) {
        return RuntimeConfigCommitOutcome.superseded;
      }
      final lease = RuntimeConfigCommitLease._(this, generation);
      _activeLease = lease;
      try {
        await transaction(lease);
      } finally {
        _activeLease = null;
      }
      return RuntimeConfigCommitOutcome.committed;
    } finally {
      release.complete();
    }
  }

  /// Runs a continuation of the currently-owned logical commit inline.
  /// It neither waits on the queue nor creates/supersedes a generation.
  Future<void> continueCommit({
    required RuntimeConfigCommitLease lease,
    required Future<void> Function(RuntimeConfigCommitLease lease) transaction,
  }) async {
    if (!identical(lease._owner, this) || !identical(_activeLease, lease)) {
      throw StateError('Runtime config commit lease is not active');
    }
    await transaction(lease);
  }
}
