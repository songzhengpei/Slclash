import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'backup_error.dart';
import 'backup_limits.dart';

class SafeZipContents {
  const SafeZipContents(this.files, this.directories);

  final Map<String, List<int>> files;
  final Set<String> directories;
}

class SafeZipReader {
  const SafeZipReader({this.limits = const BackupLimits()});

  final BackupLimits limits;

  SafeZipContents read(List<int> input) {
    if (input.length > limits.maxArchiveBytes) {
      throw const BackupFormatException(
        BackupErrorCode.archiveTooLarge,
        'Backup archive exceeds the compressed size limit',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(Uint8List.fromList(input));
    } catch (_) {
      throw const BackupFormatException(
        BackupErrorCode.invalidZip,
        'Backup is not a valid ZIP archive',
      );
    }
    if (archive.files.length > limits.maxEntries) {
      throw const BackupFormatException(
        BackupErrorCode.tooManyEntries,
        'Backup contains too many entries',
      );
    }

    final files = <String, List<int>>{};
    final directories = <String>{};
    final normalizedNames = <String>{};
    var extractedBytes = 0;
    for (final entry in archive.files) {
      final name = _validatePath(entry.name, isDirectory: entry.isDirectory);
      if (!normalizedNames.add(name.toLowerCase())) {
        throw const BackupFormatException(
          BackupErrorCode.duplicatePath,
          'Backup contains a duplicate path',
        );
      }
      if (entry.isSymbolicLink) {
        throw const BackupFormatException(
          BackupErrorCode.unsupportedEntry,
          'Backup contains a symbolic link',
        );
      }
      if (entry.isDirectory) {
        directories.add(name);
        continue;
      }
      if (entry.size < 0 || entry.size > limits.maxEntryBytes) {
        throw const BackupFormatException(
          BackupErrorCode.entryTooLarge,
          'Backup entry exceeds the size limit',
        );
      }
      extractedBytes += entry.size;
      if (extractedBytes > limits.maxExtractedBytes) {
        throw const BackupFormatException(
          BackupErrorCode.extractedDataTooLarge,
          'Backup exceeds the extracted size limit',
        );
      }
      try {
        final content = entry.content;
        if (content.length != entry.size) {
          throw const BackupFormatException(
            BackupErrorCode.sizeMismatch,
            'ZIP entry size does not match its content',
          );
        }
        files[name] = List<int>.unmodifiable(content);
      } on BackupFormatException {
        rethrow;
      } catch (_) {
        throw const BackupFormatException(
          BackupErrorCode.invalidZip,
          'A ZIP entry could not be decoded',
        );
      }
    }
    return SafeZipContents(
      Map<String, List<int>>.unmodifiable(files),
      Set<String>.unmodifiable(directories),
    );
  }

  String _validatePath(String raw, {required bool isDirectory}) {
    if (raw.isEmpty || raw.contains('\u0000') || raw.contains('\\')) {
      throw const BackupFormatException(
        BackupErrorCode.unsafePath,
        'Backup contains an unsafe path',
      );
    }
    if (raw.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(raw)) {
      throw const BackupFormatException(
        BackupErrorCode.unsafePath,
        'Backup contains an absolute path',
      );
    }
    final normalized = isDirectory && raw.endsWith('/')
        ? raw.substring(0, raw.length - 1)
        : raw;
    final segments = normalized.split('/');
    if (normalized.isEmpty ||
        segments.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const BackupFormatException(
        BackupErrorCode.unsafePath,
        'Backup contains path traversal or ambiguous segments',
      );
    }
    return isDirectory ? '$normalized/' : normalized;
  }
}
