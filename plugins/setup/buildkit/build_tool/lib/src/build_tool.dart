import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'environment.dart';
import 'error.dart';
import 'go_builder.dart';
import 'logging.dart';
import 'options.dart';
import 'target.dart';

final _log = Logger('build_tool');

String _rootDir = '.';

String _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
        File(p.join(dir.path, 'core')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

abstract class BuildCommand extends Command {
  Future<void> runBuildCommand();

  @override
  Future<void> run() async {
    await runBuildCommand();
  }
}

class BuildAndroidCommand extends BuildCommand {
  BuildAndroidCommand() {
    argParser.addOption(
      'arch',
      valueHelp: 'arm,arm64,amd64',
      help: 'Target architecture (omit to build all)',
    );
    argParser.addOption(
      'target-platform',
      valueHelp: 'android-arm,android-arm64,android-x64',
      help: 'Flutter target platform list (omit to build all)',
    );
  }

  @override
  final name = 'android';

  @override
  final description = 'Build Android Go core (c-shared library)';

  @override
  Future<void> runBuildCommand() async {
    final archName = argResults?['arch'] as String?;
    final flutterTargetPlatforms = argResults?['target-platform'] as String?;
    final config = BuildConfig.load(rootDir: _rootDir);

    final targets = Target.resolveAndroidTargets(
      archName: archName,
      flutterTargetPlatforms: flutterTargetPlatforms,
    );

    final builder = GoBuilder(rootDir: _rootDir, config: config);
    final corePaths = await builder.buildAll(targets);

    _log.info('Build complete: $corePaths');
  }
}

Future<void> runMain(List<String> args) async {
  try {
    initLogging();

    final runner = CommandRunner('build_tool', 'FlClash build tool')
      ..argParser.addOption(
        'root-dir',
        valueHelp: '<path>',
        help: 'Project root directory (default: auto-detect)',
      )
      ..addCommand(BuildAndroidCommand());

    final topResults = runner.parse(args);
    _rootDir = (topResults['root-dir'] as String?) ?? _findProjectRoot();
    await runner.run(args);
  } on BuildException catch (e) {
    _log.severe(e.toString());
    exit(1);
  } on CommandFailedException catch (e) {
    _log.severe(e.toString());
    exit(1);
  } on UsageException catch (e) {
    stderr.writeln(e.toString());
    exit(1);
  } catch (e, s) {
    _log.severe(kDoubleSeparator);
    _log.severe('Build failed with unexpected error:');
    _log.severe(kSeparator);
    _log.severe('$e');
    _log.severe(kSeparator);
    _log.severe('$s');
    _log.severe(kDoubleSeparator);
    exit(1);
  }
}
