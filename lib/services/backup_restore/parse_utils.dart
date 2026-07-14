import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'models.dart';

class StagedBackupArchive {
  const StagedBackupArchive(this.directory, this.files);

  final Directory directory;
  final Map<String, File> files;

  File requireFile(String path, {int? maxBytes}) {
    final file = files[path];
    if (file == null) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.missingRequiredFile,
        '备份缺少必需文件：$path',
      );
    }
    if (maxBytes != null && file.lengthSync() > maxBytes) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.archiveLimitExceeded,
        '$path 大小超限',
      );
    }
    return file;
  }
}

class BackupParseUtils {
  const BackupParseUtils();

  String canonicalArchivePath(String rawName) {
    if (rawName.isEmpty || rawName.contains('\u0000')) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.unsafePath,
        'ZIP 包含空路径或 NUL 字符',
      );
    }
    final slashName = rawName.replaceAll('\\', '/');
    if (slashName.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(slashName)) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.unsafePath,
        'ZIP 包含绝对路径：$rawName',
      );
    }
    final value = slashName.endsWith('/')
        ? slashName.substring(0, slashName.length - 1)
        : slashName;
    final segments = value.split('/');
    if (segments.isEmpty ||
        segments.any(
          (segment) =>
              segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.unsafePath,
        'ZIP 包含路径穿越或非规范路径：$rawName',
      );
    }
    final normalized = p.posix.normalize(segments.join('/'));
    if (normalized == '.' ||
        normalized.startsWith('../') ||
        normalized.contains('/../')) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.unsafePath,
        'ZIP 路径越出恢复目录：$rawName',
      );
    }
    return normalized;
  }

  Future<Map<String, Object?>> readJsonObject(
    File file,
    String label,
  ) async {
    try {
      return objectMap(json.decode(await file.readAsString()), field: label);
    } on BackupRestoreException {
      rethrow;
    } catch (error) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        '$label 不是有效 JSON',
        error,
      );
    }
  }

  Future<Map<String, Object?>> readYamlObject(
    File file,
    String label,
  ) async {
    try {
      return objectMap(
        yamlToDart(loadYaml(await file.readAsString())),
        field: label,
      );
    } on BackupRestoreException {
      rethrow;
    } catch (error) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        '$label 不是有效 YAML',
        error,
      );
    }
  }

  Object? yamlToDart(Object? value) {
    if (value is YamlMap) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): yamlToDart(entry.value),
      };
    }
    if (value is YamlList) {
      return value.map(yamlToDart).toList(growable: false);
    }
    return value;
  }

  Map<String, Object?> objectMap(
    Object? value, {
    required String field,
  }) {
    if (value is! Map) {
      throw BackupRestoreException(
        BackupRestoreErrorCode.invalidMetadata,
        '$field 必须是对象',
      );
    }
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  int? intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, String> stringMap(Object? value) {
    if (value is! Map) return const {};
    return <String, String>{
      for (final entry in value.entries)
        if (entry.value != null)
          entry.key.toString(): entry.value.toString(),
    };
  }

  Set<String> stringSet(Object? value) {
    if (value is! Iterable) return const {};
    return value.map((item) => item.toString()).toSet();
  }

  DateTime? dateTime(Object? value) {
    if (value == null) return null;
    if (value is num) {
      final milliseconds = value > 100000000000
          ? value.toInt()
          : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return DateTime.tryParse(value.toString());
  }

  String normalizeBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return '';
    }
    final normalizedPath = uri.path == '/' || uri.path.isEmpty
        ? ''
        : uri.path.replaceAll(RegExp(r'/+$'), '');
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: normalizedPath,
    ).toString();
  }

  int stableProfileId(String uid, Set<int> usedIds) {
    final digest = sha256.convert(utf8.encode(uid)).bytes;
    var id = 0;
    for (var index = 0; index < 8; index++) {
      id = (id << 8) | digest[index];
    }
    id &= 0x7fffffffffffffff;
    if (id == 0) id = 1;
    while (usedIds.contains(id)) {
      id = (id + 1) & 0x7fffffffffffffff;
      if (id == 0) id = 1;
    }
    return id;
  }

  String sha256File(File file) {
    return sha256.convert(file.readAsBytesSync()).toString();
  }

  void validateRelationships({
    required List<Profile> profiles,
    required List<Rule> rules,
    required List<ProfileRuleLink> links,
  }) {
    if (rules.isEmpty != links.isEmpty) {
      throw const BackupRestoreException(
        BackupRestoreErrorCode.invalidRelationship,
        '规则与 Profile 关联元数据不完整',
      );
    }
    final ruleIds = rules.map((rule) => rule.id).toSet();
    final profileIds = profiles.map((profile) => profile.id).toSet();
    for (final link in links) {
      if (!ruleIds.contains(link.ruleId) ||
          (link.profileId != null && !profileIds.contains(link.profileId))) {
        throw const BackupRestoreException(
          BackupRestoreErrorCode.invalidRelationship,
          '规则关联引用了不存在的 Profile 或 Rule',
        );
      }
    }
  }

  T? enumByName<T extends Enum>(Iterable<T> values, String? name) {
    if (name == null) return null;
    return values.where((value) => value.name == name).firstOrNull;
  }
}
