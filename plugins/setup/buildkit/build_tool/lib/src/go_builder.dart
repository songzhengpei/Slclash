import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'environment.dart';
import 'error.dart';
import 'logging.dart';
import 'options.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('go_builder');

String _resolveCc(Target target) {
  final ndk = Environment.androidNdk;
  final prebuiltDir = Directory(p.join(ndk, 'toolchains', 'llvm', 'prebuilt'));
  final entries = prebuiltDir
      .listSync()
      .where((e) => !p.basename(e.path).startsWith('.'))
      .toList();
  if (entries.isEmpty) {
    throw BuildException('No NDK prebuilt toolchain found in $prebuiltDir');
  }
  return p.join(entries.first.path, 'bin', target.ndkCcName);
}

class GoBuilder {
  final String rootDir;
  final BuildConfig config;

  GoBuilder({required this.rootDir, required this.config});

  String get _corePath => p.join(rootDir, config.coreDir);
  String get _outputPath => p.join(rootDir, config.outputDir);

  Future<String> build(Target target) async {
    final outDir = p.join(_outputPath, target.platformDir, target.abi!);
    ensureDir(outDir);

    final fileName = '${config.libName}${target.dynamicLibExtension}';
    final outFile = p.join(outDir, fileName);

    final env = <String, String>{'GOOS': target.goos, 'GOARCH': target.goarch};

    env['CGO_ENABLED'] = '1';
    env['CC'] = _resolveCc(target);
    env['CFLAGS'] = '-O3 -Werror';

    final args = [
      'build',
      '-ldflags=${config.goLdflags}',
      '-tags=${config.tags}',
      '-buildmode=c-shared',
      '-o',
      outFile,
    ];

    _log.info(kDoubleSeparator);
    _log.info('Building Go core: $target (CGO, c-shared)');
    _log.info(kSeparator);

    await runCommandStream(
      'go',
      args,
      workingDirectory: _corePath,
      environment: env,
    );

    await _adjustAndroidOutput(
      outDir: p.join(_outputPath, target.platformDir),
      abiDir: target.abi!,
      archName: target.abi!,
      libPath: outFile,
      libName: fileName,
    );

    _log.info('Built: $outFile');
    return outFile;
  }

  Future<List<String>> buildAll(List<Target> targets) async {
    final results = await Future.wait(targets.map(build));
    return results;
  }

  Future<void> _adjustAndroidOutput({
    required String outDir,
    required String abiDir,
    required String archName,
    required String libPath,
    required String libName,
  }) async {
    final includesPath = p.join(outDir, 'includes', archName);
    final androidCoreMainPath = p.join(
      rootDir,
      'android',
      'core',
      'src',
      'main',
    );
    final jniLibsPath = p.join(androidCoreMainPath, 'jniLibs', abiDir);
    final cppIncludesPath = p.join(
      androidCoreMainPath,
      'cpp',
      'includes',
      archName,
    );

    ensureDir(jniLibsPath);
    ensureDir(includesPath);
    _clearDirectory(includesPath);
    ensureDir(cppIncludesPath);
    _clearDirectory(cppIncludesPath);

    _deleteIfExists(p.join(jniLibsPath, libName));
    File(libPath).copySync(p.join(jniLibsPath, libName));

    final abiDirPath = p.join(outDir, abiDir);
    final headerFiles = [
      ...Directory(abiDirPath).listSync(),
      ...Directory(_corePath).listSync(),
    ];
    for (final file in headerFiles) {
      if (!file.path.endsWith('.h')) continue;
      final fileName = p.basename(file.path);
      final source = File(file.path);
      source.copySync(p.join(includesPath, fileName));
      source.copySync(p.join(cppIncludesPath, fileName));
      if (file.path.startsWith(abiDirPath)) {
        source.deleteSync();
      }
    }
  }

  void _clearDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;

    for (final entity in dir.listSync()) {
      if (entity is File || entity is Link) {
        entity.deleteSync();
      } else if (entity is Directory) {
        entity.deleteSync(recursive: true);
      }
    }
  }

  void _deleteIfExists(String filePath) {
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
