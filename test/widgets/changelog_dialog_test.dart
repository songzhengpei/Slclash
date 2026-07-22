import 'package:fl_clash/widgets/changelog_dialog.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders one card per release with a confirmation action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final textTheme = buildSlclashTextTheme();
    final typography = SurgeTypography.fromTextTheme(textTheme);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(360, 720)),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData(
            textTheme: textTheme,
            extensions: [SurgeTheme.light(), typography],
          ),
          home: const Scaffold(body: AppChangelogDialog()),
        ),
      ),
    );

    expect(find.text('更新日志'), findsOneWidget);
    expect(find.text('v2.0.5'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
