import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'error.dart';

final _log = Logger('mihomo_patcher');

class MihomoPatcher {
  final String rootDir;

  MihomoPatcher({required this.rootDir});

  String get _mihomoPath => p.join(rootDir, 'core', 'Clash.Meta');
  String get _patchPath =>
      p.join(rootDir, 'core', 'patches', 'mihomo', 'proxy-only-traffic.patch');

  void apply() {
    if (!Directory(_mihomoPath).existsSync()) {
      throw BuildException('Mihomo submodule not found: $_mihomoPath');
    }
    if (!File(_patchPath).existsSync()) {
      throw BuildException('Required Mihomo patch not found: $_patchPath');
    }

    if (_gitApplyCheck(reverse: true)) {
      _log.info('Mihomo proxy-only traffic patch is already applied.');
      return;
    }
    if (!_gitApplyCheck()) {
      throw BuildException(
        'The Mihomo proxy-only traffic patch is incompatible with this core '
        'revision. Rebase core/patches/mihomo/proxy-only-traffic.patch before '
        'building or releasing.',
      );
    }

    final result = Process.runSync(
      'git',
      ['apply', '--whitespace=nowarn', _patchPath],
      workingDirectory: _mihomoPath,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    if (result.exitCode != 0) {
      throw CommandFailedException(
        executable: 'git',
        arguments: ['apply', '--whitespace=nowarn', _patchPath],
        exitCode: result.exitCode,
        stdout: (result.stdout as String).trim(),
        stderr: (result.stderr as String).trim(),
      );
    }
    _log.info('Applied Mihomo proxy-only traffic patch.');
  }

  bool _gitApplyCheck({bool reverse = false}) {
    final arguments = [
      'apply',
      if (reverse) '--reverse',
      '--check',
      _patchPath,
    ];
    final result = Process.runSync(
      'git',
      arguments,
      workingDirectory: _mihomoPath,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    return result.exitCode == 0;
  }
}
