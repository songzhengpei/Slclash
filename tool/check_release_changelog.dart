import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/check_release_changelog.dart <tag>');
    exitCode = 64;
    return;
  }

  final tag = arguments.single.startsWith('v')
      ? arguments.single
      : 'v${arguments.single}';
  final source = File('lib/common/app_changelog.dart').readAsStringSync();
  final firstVersion = RegExp(
    r"version:\s*'([^']+)'",
  ).firstMatch(source)?.group(1);

  if (firstVersion != tag) {
    stderr.writeln(
      'Release blocked: latest app changelog is ${firstVersion ?? 'missing'}, '
      'but the release tag is $tag. Add the $tag changelog card first.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('App changelog matches release $tag.');
}
