import 'dart:io';

import 'error.dart';

String _require(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw BuildException('Required environment variable not set: $key');
  }
  return value;
}

String _get(String key, {String? defaultValue}) {
  return Platform.environment[key] ?? defaultValue ?? '';
}

class Environment {
  static String get androidNdk => _require('ANDROID_NDK');
  static String get appEnv => _get('APP_ENV', defaultValue: 'pre');
}
