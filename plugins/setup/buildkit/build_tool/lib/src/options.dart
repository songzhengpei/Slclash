import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

final _log = Logger('options');

class BuildConfig {
  final String tags;
  final String goLdflags;
  final String coreDir;
  final String libName;
  final String outputDir;

  const BuildConfig({
    required this.tags,
    required this.goLdflags,
    required this.coreDir,
    required this.libName,
    required this.outputDir,
  });

  static const _defaults = BuildConfig(
    tags: 'with_gvisor',
    goLdflags: '-w -s',
    coreDir: 'core',
    libName: 'libclash',
    outputDir: 'libclash',
  );

  static BuildConfig load({required String rootDir}) {
    final configPath = p.join(rootDir, 'build_config.yaml');
    final file = File(configPath);
    if (!file.existsSync()) {
      _log.fine('No build_config.yaml found, using defaults');
      return _defaults;
    }
    final yaml = loadYaml(file.readAsStringSync()) as YamlMap?;
    if (yaml == null) return _defaults;
    return BuildConfig(
      tags: yaml['tags'] as String? ?? _defaults.tags,
      goLdflags: yaml['go_ldflags'] as String? ?? _defaults.goLdflags,
      coreDir: yaml['core_dir'] as String? ?? _defaults.coreDir,
      libName: yaml['lib_name'] as String? ?? _defaults.libName,
      outputDir: yaml['output_dir'] as String? ?? _defaults.outputDir,
    );
  }
}
