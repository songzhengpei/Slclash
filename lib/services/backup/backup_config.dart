import 'package:fl_clash/models/models.dart';

/// Serialize restorable settings without exporting device-local credentials.
Map<String, dynamic> backupConfigJson(Config config) {
  final json = Map<String, dynamic>.from(config.toJson());
  json.remove('davProps');
  return json;
}

/// Credentials always belong to the device performing the restore.
Config preserveLocalBackupSecrets(Config restored, Config? current) {
  return restored.copyWith(davProps: current?.davProps);
}
