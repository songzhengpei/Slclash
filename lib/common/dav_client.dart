import 'dart:async';
import 'dart:io' as io;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:webdav_client/webdav_client.dart';

import 'package:fl_clash/services/backup/backup_file_guard.dart';

class DAVFileEntry {
  final String name;
  final int size;
  final DateTime lastModified;

  DAVFileEntry({
    required this.name,
    required this.size,
    required this.lastModified,
  });
}

class DAVClient {
  late Client client;
  late String fileName;

  DAVClient(DAVProps dav) {
    client = newClient(dav.uri, user: dav.user, password: dav.password);
    fileName = dav.fileName;
    client.setHeaders({'accept-charset': 'utf-8', 'Content-Type': 'text/xml'});
    client.setConnectTimeout(8000);
    client.setSendTimeout(60000);
    client.setReceiveTimeout(60000);
  }

  Future<bool> ping() async {
    try {
      await client.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  static const String root = '/clash-verge-rev-backup';

  String _timestampFileName() {
    final now = DateTime.now();
    final ts =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'O-android-backup-$ts.zip';
  }

  Future<bool> backup(String localFilePath) async {
    await client.mkdir(root);
    final remotePath = '$root/${_timestampFileName()}';
    await client.writeFromFile(localFilePath, remotePath);
    return true;
  }

  Future<List<DAVFileEntry>> listFiles() async {
    await client.mkdir(root);
    final list = await client.readDir(root);
    final result = <DAVFileEntry>[];
    for (final item in list) {
      if (item.isDir == true) continue;
      final name = item.name ?? '';
      if (name.endsWith('.zip')) {
        result.add(
          DAVFileEntry(
            name: name,
            size: item.size ?? 0,
            lastModified: item.mTime ?? DateTime.now(),
          ),
        );
      }
    }
    result.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return result;
  }

  Future<bool> restoreFile(String remoteFileName) async {
    final remotePath = '$root/$remoteFileName';
    final properties = await client.readProps(remotePath);
    validateBackupArchiveLength(properties.size);
    final backupFilePath = await appPath.backupFilePath;
    await client.read2File(remotePath, backupFilePath);
    await validateBackupArchiveFile(io.File(backupFilePath));
    return true;
  }

  Future<bool> restore() async {
    return restoreFile(fileName);
  }
}
