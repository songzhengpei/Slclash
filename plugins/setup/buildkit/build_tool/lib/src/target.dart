import 'error.dart';

class Target {
  final String goos;
  final String goarch;
  final String? abi;
  final String? flutterPlatform;

  const Target({
    required this.goos,
    required this.goarch,
    this.abi,
    this.flutterPlatform,
  });

  static const androidArm64 = Target(
    goos: 'android',
    goarch: 'arm64',
    abi: 'arm64-v8a',
    flutterPlatform: 'android-arm64',
  );

  static final List<Target> all = [androidArm64];

  static List<Target> forPlatform(String platformName) {
    return all.where((t) => t.goos == platformName).toList();
  }

  static List<Target> resolveAndroidTargets({
    String? archName,
    String? flutterTargetPlatforms,
  }) {
    if (archName != null && flutterTargetPlatforms != null) {
      throw BuildException('Use either --arch or --target-platform, not both');
    }

    final androidTargets = forPlatform('android');
    if (archName != null) {
      final targets = androidTargets
          .where((t) => t.goarch == archName)
          .toList();
      if (targets.isEmpty) {
        throw BuildException('Invalid arch: $archName');
      }
      return targets;
    }

    if (flutterTargetPlatforms == null || flutterTargetPlatforms.isEmpty) {
      return [androidArm64];
    }

    final targets = <Target>[];
    final seen = <String>{};
    for (final platform in flutterTargetPlatforms.split(',')) {
      final name = platform.trim();
      if (name.isEmpty || !seen.add(name)) continue;
      final target = androidTargets.where((t) => t.flutterPlatform == name);
      if (target.isEmpty) {
        throw BuildException('Invalid target-platform: $name');
      }
      targets.add(target.single);
    }

    if (targets.isEmpty) {
      throw BuildException('No Android target platforms provided');
    }
    return targets;
  }

  String get dynamicLibExtension => '.so';

  String get platformDir => goos;

  String get ndkCcName {
    if (abi == null) throw Exception('Not an Android target');
    switch (abi) {
      case 'arm64-v8a':
        return 'aarch64-linux-android21-clang';
      default:
        throw Exception('Unknown ABI: $abi');
    }
  }

  @override
  String toString() => '$goos/$goarch${abi != null ? ' ($abi)' : ''}';
}
