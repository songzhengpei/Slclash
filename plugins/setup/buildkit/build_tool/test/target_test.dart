import 'package:build_tool/src/error.dart';
import 'package:build_tool/src/target.dart';
import 'package:test/test.dart';

void main() {
  group('resolveAndroidTargets', () {
    test('defaults to arm64 Android target', () {
      final targets = Target.resolveAndroidTargets();

      expect(targets, [Target.androidArm64]);
    });

    test('maps a Flutter target platform to the matching Android target', () {
      final targets = Target.resolveAndroidTargets(
        flutterTargetPlatforms: 'android-arm64',
      );

      expect(targets, [Target.androidArm64]);
    });

    test('uses explicit arch when provided', () {
      final targets = Target.resolveAndroidTargets(archName: 'arm64');

      expect(targets, [Target.androidArm64]);
    });

    test('rejects unsupported Flutter target platforms', () {
      expect(
        () => Target.resolveAndroidTargets(
          flutterTargetPlatforms: 'android-riscv64',
        ),
        throwsA(isA<BuildException>()),
      );
    });
  });
}
