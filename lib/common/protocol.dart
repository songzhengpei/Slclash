import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

class Protocol {
  static Protocol? _instance;

  Protocol._internal();

  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  void register(String scheme) {
    final String protocolRegKey = 'Software\\Classes\\$scheme';
    const RegistryValue protocolRegValue = RegistryValue.string(
      'URL Protocol',
      '',
    );
    const String protocolCmdRegKey = 'shell\\open\\command';
    final RegistryValue protocolCmdRegValue = RegistryValue.string(
      '',
      '"${Platform.resolvedExecutable}" "%1"',
    );
    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }
}

final protocol = Protocol();
