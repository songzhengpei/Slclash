import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';

typedef Phase4Reselect = void Function();
typedef Phase4ScrollBy = void Function(double dy);
typedef Phase4KeepExperiment = void Function();

/// ADB → MainActivity extras (profile/debug) → this channel.
/// No-op unless [NavigationTrace.enabled].
class Phase4PerfCommands {
  Phase4PerfCommands._();

  static const _channel = MethodChannel('$methodChannelPrefix/phase4_perf');
  static bool _attached = false;
  static Phase4Reselect? onReselect;
  static Phase4ScrollBy? onScrollBy;
  static Phase4KeepExperiment? onKeepExperiment;

  /// Profile/perf experiment only. `null` = product `NavigationItem.keep`.
  static bool? dashboardKeepOverride;

  static void attach() {
    if (!NavigationTrace.enabled || _attached) {
      return;
    }
    _attached = true;
    _channel.setMethodCallHandler(_handle);
    NavigationTrace.mark('nav_listener_ready');
  }

  static Future<dynamic> _handle(MethodCall call) async {
    final args = _stringMap(call.arguments);
    switch (call.method) {
      case 'ping':
        return _ping();
      case 'navigate':
        return _navigate(args['page']);
      case 'reselect':
        onReselect?.call();
        return 'ok';
      case 'scroll_by':
        final dy = double.tryParse(args['dy'] ?? '') ?? 800;
        onScrollBy?.call(dy);
        return 'ok';
      case 'dump_counts':
        NavigationTrace.dumpCounts(
          dashboardKeepOverride: dashboardKeepOverride,
        );
        return {
          'mounts': NavigationTrace.mountCounts(),
          'builds': NavigationTrace.buildCounts(),
          'dashboard_keep_override': dashboardKeepOverride,
        };
      case 'keep_dashboard':
        return _keepDashboard(args['keep'] ?? args['value']);
      default:
        return null;
    }
  }

  static Map<String, Object?> _ping() {
    final pages = <String>[];
    String current = 'unknown';
    try {
      final container = globalState.container;
      current = container.read(currentPageLabelProvider).name;
      pages.addAll(
        container
            .read(currentNavigationItemsStateProvider)
            .value
            .map((item) => item.label.name),
      );
    } catch (_) {
      pages.addAll(const ['dashboard', 'proxies', 'profiles', 'tools']);
    }
    NavigationTrace.mark(
      'nav_pong',
      extras: {
        'current': current,
        'pages': pages.join(','),
        'dashboard_keep_override': dashboardKeepOverride,
      },
    );
    return {'current': current, 'pages': pages};
  }

  static String _keepDashboard(String? raw) {
    if (raw == 'clear' || raw == 'null') {
      dashboardKeepOverride = null;
    } else {
      dashboardKeepOverride = raw == 'true' || raw == '1';
    }
    NavigationTrace.mark(
      'nav_keep_dashboard',
      extras: {'keep': dashboardKeepOverride},
    );
    onKeepExperiment?.call();
    return '${dashboardKeepOverride ?? 'product'}';
  }

  static String _navigate(String? raw) {
    final page = _parsePage(raw);
    if (page == null) {
      return 'unknown_page';
    }
    globalState.container.read(currentPageLabelProvider.notifier).toPage(page);
    return page.name;
  }

  static PageLabel? _parsePage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    for (final label in PageLabel.values) {
      if (label.name == raw) {
        return label;
      }
    }
    return null;
  }

  static Map<String, String> _stringMap(Object? arguments) {
    if (arguments is Map) {
      return arguments.map((key, value) => MapEntry('$key', '$value'));
    }
    return const {};
  }
}
