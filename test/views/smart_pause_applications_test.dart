import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/smart_pause_applications.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('com.follow.clash/service');
  var permission = false;
  final calls = <String>[];
  setUp(() {
    permission = false;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'hasUsageAccess' ? permission : true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets(
    'app-only settings are visible and multi-select leaves networks untouched',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      globalState.container = container;
      final subscription = container.listen(vpnSettingProvider, (_, _) {});
      addTearDown(subscription.close);
      container.read(vpnSettingProvider.notifier).value = const VpnProps(
        smartAutoStop: true,
      );
      container.read(packagesProvider.notifier).value = const [
        Package(
          packageName: 'app.a',
          label: 'App A',
          system: false,
          internet: true,
          lastUpdateTime: 0,
        ),
        Package(
          packageName: 'app.b',
          label: 'App B',
          system: false,
          internet: true,
          lastUpdateTime: 0,
        ),
      ];
      final textTheme = buildSlclashTextTheme();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            theme: ThemeData(
              textTheme: textTheme,
              extensions: [
                SurgeTheme.light(),
                SurgeTypography.fromTextTheme(textTheme),
              ],
            ),
            home: const SmartPauseApplicationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trigger apps'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Usage access')).dx,
        tester
            .getTopLeft(
              find.text('For apps that check for a VPN when opening.'),
            )
            .dx,
        reason: 'Permission title and explanation share the page alignment',
      );
      expect(find.text('Authorize'), findsOneWidget);
      expect(
        tester
            .widget<SurgeStatusButton>(
              find.byKey(const Key('usage-access-button')),
            )
            .isActive,
        isFalse,
      );
      expect(find.byType(PackageSelectionList), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      await tester.tap(find.text('App A'));
      await tester.pump();
      await tester.tap(find.text('App B'));
      await tester.pump();
      expect(container.read(vpnSettingProvider).smartAutoStopApplications, [
        'app.a',
        'app.b',
      ]);
      expect(container.read(vpnSettingProvider).smartAutoStopNetworks, isEmpty);
      await tester.tap(find.text('App A'));
      await tester.pump();
      expect(container.read(vpnSettingProvider).smartAutoStopApplications, [
        'app.b',
      ]);
      await tester.tap(find.text('Authorize'));
      await tester.pumpAndSettle();
      expect(calls, contains('openUsageAccessSettings'));
      permission = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Granted'), findsOneWidget);
      final buttonCenter = tester.getCenter(
        find.byKey(const Key('usage-access-button')),
      );
      final labelCenter = tester.getCenter(find.text('Granted'));
      expect(labelCenter.dx, closeTo(buttonCenter.dx, 0.1));
      expect(labelCenter.dy, closeTo(buttonCenter.dy, 0.1));
      expect(
        tester
            .widget<SurgeStatusButton>(
              find.byKey(const Key('usage-access-button')),
            )
            .isActive,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'trigger conditions are nested under total switch in dark theme and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      globalState.container = container;
      final subscription = container.listen(vpnSettingProvider, (_, _) {});
      addTearDown(subscription.close);
      container.read(vpnSettingProvider.notifier).value = const VpnProps(
        smartAutoStop: true,
        smartAutoStopNetworks: ['192.168.100.0/24'],
        smartAutoStopApplications: ['app.a'],
      );
      final textTheme = buildSlclashTextTheme();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            theme: ThemeData(
              brightness: Brightness.dark,
              textTheme: textTheme,
              extensions: [
                SurgeTheme.dark(),
                SurgeTypography.fromTextTheme(textTheme),
              ],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(body: SmartAutoStopSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final section = find.byKey(const Key('smart-pause-section'));
      expect(
        find.descendant(of: section, matching: find.text('Trigger conditions')),
        findsNothing,
      );
      expect(
        find.descendant(of: section, matching: find.text('Trusted Networks')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: section, matching: find.text('Trigger apps')),
        findsOneWidget,
      );
      await tester.tap(find.text('Smart Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Trigger conditions'), findsNothing);
      expect(find.text('Trusted Networks'), findsNothing);
      expect(find.text('Trigger apps'), findsNothing);
      expect(container.read(vpnSettingProvider).smartAutoStopNetworks, [
        '192.168.100.0/24',
      ]);
      expect(container.read(vpnSettingProvider).smartAutoStopApplications, [
        'app.a',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
