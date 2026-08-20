import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/views/dashboard/dashboard_layout.dart';
import 'package:fl_clash/views/dashboard/widgets/network_overview_card.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardResponsiveLayout _layout(double width) {
  return DashboardResponsiveLayout.fromViewport(
    viewportWidth: width,
    viewportHeight: DashboardResponsiveLayout.referenceViewportHeight,
    textScaler: TextScaler.noScaling,
  );
}

Widget _app(DashboardResponsiveLayout layout) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return ProviderScope(
    overrides: [
      uiAutoRefreshEnabledProvider.overrideWithValue(false),
      appForegroundProvider.overrideWithValue(true),
      currentPageLabelProvider.overrideWithValue(PageLabel.dashboard),
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
      home: Scaffold(
        body: SizedBox(
          width: layout.viewportWidth,
          height: 720,
          child: SurgeNetworkOverviewCard(layout: layout),
        ),
      ),
    ),
  );
}

void main() {
  setUp(OverviewLatencyHostLifecycle.reset);

  testWidgets(
    'reflow breakpoint does not remount OverviewLatencyHost state',
    (tester) async {
      final wide = _layout(384);
      final narrow = _layout(225);
      expect(wide.requiresReflow, isFalse);
      expect(narrow.requiresReflow, isTrue);

      await tester.pumpWidget(_app(wide));
      await tester.pump();
      expect(OverviewLatencyHostLifecycle.mounts, 1);
      expect(OverviewLatencyHostLifecycle.disposes, 0);

      await tester.pumpWidget(_app(narrow));
      await tester.pump();
      expect(
        OverviewLatencyHostLifecycle.mounts,
        1,
        reason: 'false → true reflow must keep LatencyHost state',
      );
      expect(OverviewLatencyHostLifecycle.disposes, 0);

      await tester.pumpWidget(_app(wide));
      await tester.pump();
      expect(
        OverviewLatencyHostLifecycle.mounts,
        1,
        reason: 'true → false reflow must keep LatencyHost state',
      );
      expect(OverviewLatencyHostLifecycle.disposes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
