import 'dart:async';
import 'dart:io';

import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'common/common.dart';

Future<void> main() async {
  try {
    StartupTrace.beginProcess();
    WidgetsFlutterBinding.ensureInitialized();
    final version = await system.version;
    StartupTrace.mark('system.version');
    final container = await globalState.init(version);
    StartupTrace.mark('globalState.init');
    HttpOverrides.global = FlClashHttpOverrides();
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
        StartupTrace.mark('first_frame');
      }),
    );
    StartupTrace.mark('runApp');
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const Application(),
      ),
    );
  } catch (e, s) {
    return runApp(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
