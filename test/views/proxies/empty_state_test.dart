import 'package:fl_clash/views/proxies/empty.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  final textTheme = buildSlclashTextTheme();
  final typography = SurgeTypography.fromTextTheme(textTheme);
  return MaterialApp(
    theme: ThemeData(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[SurgeTheme.light(), typography],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders compact loading state without redundant action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ProxiesEmptyState(
          label: '正在加载 Provider',
          description: '正在获取当前订阅的代理组。',
          actionLabel: '重新加载',
          onAction: _noop,
          actionLoading: true,
          kind: ProxiesEmptyStateKind.loading,
        ),
      ),
    );

    expect(find.text('连接中'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('renders each failure with its own semantic icon', (
    tester,
  ) async {
    const cases = <(ProxiesEmptyStateKind, IconData)>[
      (ProxiesEmptyStateKind.timeout, SurgeIcons.schedule),
      (ProxiesEmptyStateKind.coreUnavailable, SurgeIcons.wifiDisabled),
      (ProxiesEmptyStateKind.failed, SurgeIcons.warning),
      (ProxiesEmptyStateKind.empty, SurgeIcons.route),
    ];

    for (final entry in cases) {
      await tester.pumpWidget(
        _app(
          ProxiesEmptyState(
            label: entry.$1.name,
            description: 'description',
            actionLabel: '重新加载',
            onAction: _noop,
            kind: entry.$1,
          ),
        ),
      );
      expect(find.byIcon(entry.$2), findsOneWidget);
    }
  });
}

void _noop() {}
