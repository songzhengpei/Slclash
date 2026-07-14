import 'package:fl_clash/models/models.dart';

abstract class PendingBackupRestoreCommit {
  List<ProxyGroup> get proxyGroups;
  Set<int> get restoredProfileIds;
  bool get invalidateProviderCaches;

  Future<void> commitFiles({required bool isOverride});
  Future<void> rollbackFiles();
  Future<void> complete();
}

PendingBackupRestoreCommit? _pendingBackupRestoreCommit;

void setPendingBackupRestoreCommit(PendingBackupRestoreCommit pending) {
  _pendingBackupRestoreCommit = pending;
}

PendingBackupRestoreCommit? takePendingBackupRestoreCommit() {
  final pending = _pendingBackupRestoreCommit;
  _pendingBackupRestoreCommit = null;
  return pending;
}

Future<void> clearPendingBackupRestoreCommit() async {
  final pending = _pendingBackupRestoreCommit;
  _pendingBackupRestoreCommit = null;
  if (pending != null) {
    await pending.rollbackFiles();
    await pending.complete();
  }
}
