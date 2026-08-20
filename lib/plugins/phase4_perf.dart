import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart';
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
      case 'proxy_session':
        return _proxySession(args['value'] ?? args['state']);
      case 'delay_test':
        return _delayTest(args['max']);
      case 'select_race':
        return _selectRace(args['pattern']);
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

  static String _proxySession(String? raw) {
    final on = raw == 'start' || raw == 'on' || raw == '1' || raw == 'true';
    if (on) {
      ProxyTrace.beginSession();
      return 'start';
    }
    ProxyTrace.endSession();
    return 'end';
  }

  static String _delayTest(String? maxRaw) {
    ProxyTrace.resetDelayCounters();
    final groups = getCurrentGroups();
    final proxies = <Proxy>[];
    for (final group in groups) {
      proxies.addAll(group.all);
    }
    final max = int.tryParse(maxRaw ?? '') ?? proxies.length;
    final slice = max > 0 && max < proxies.length
        ? proxies.sublist(0, max)
        : proxies;
    StartupTrace.mark(
      'delay_test_dispatch',
      extras: {'count': slice.length, 'max': max},
    );
    unawaited(delayTest(slice));
    return '${slice.length}';
  }

  /// Rapid Selector taps through the product selectedMap + debounce path.
  static String _selectRace(String? pattern) {
    final groups = getCurrentGroups();
    Group? group;
    for (final candidate in groups) {
      if (candidate.type == GroupType.Selector && candidate.all.length >= 3) {
        group = candidate;
        break;
      }
    }
    if (group == null) {
      StartupTrace.mark('proxy_select_race_skip', extras: {'reason': 'no_selector'});
      return 'no_selector';
    }
    final a = group.all[0].name;
    final b = group.all[1].name;
    final c = group.all[2].name;
    final seq = pattern == 'aba' ? [a, b, a] : [a, b, c];
    for (final name in seq) {
      applyProxyGroupMemberTap(group: group, tappedName: name);
    }
    StartupTrace.mark(
      'proxy_select_race_issued',
      extras: {
        'group': group.name,
        'pattern': pattern ?? 'abc',
        'seq': seq.join(','),
      },
    );
    return '${group.name}:${seq.join(',')}';
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
