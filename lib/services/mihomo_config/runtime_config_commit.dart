import 'dart:async';

enum RuntimeConfigCommitOutcome { committed, superseded }

enum SetupConfigOutcome { applied, unchanged, superseded, failed }

extension SetupConfigOutcomeSemantics on SetupConfigOutcome {
  bool get isFailure => this == SetupConfigOutcome.failed;

  bool get mayContinueStart =>
      this == SetupConfigOutcome.applied ||
      this == SetupConfigOutcome.unchanged;
}

/// SetupAction-owned commit gate for the shared runtime config file.
///
/// Expensive materialization stays outside this gate. Only the final
/// freshness check and the write/setup/post-commit transaction are serialized.
final class RuntimeConfigCommitOwner {
  int _latestGeneration = 0;
  Future<void> _tail = Future<void>.value();

  int beginRequest() => ++_latestGeneration;

  bool isLatest(int generation) => generation == _latestGeneration;

  Future<RuntimeConfigCommitOutcome> commit({
    required int generation,
    required Future<void> Function() transaction,
  }) async {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await predecessor;
    try {
      if (generation != _latestGeneration) {
        return RuntimeConfigCommitOutcome.superseded;
      }
      await transaction();
      return RuntimeConfigCommitOutcome.committed;
    } finally {
      release.complete();
    }
  }
}
