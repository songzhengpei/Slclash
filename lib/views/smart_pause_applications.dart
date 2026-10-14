import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartAutoStopApplicationsItem extends ConsumerWidget {
  const SmartAutoStopApplicationsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpn = ref.watch(vpnSettingProvider);
    if (!vpn.smartAutoStop) return const SizedBox.shrink();
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return ListItem.open(
      title: Text(zh ? '触发应用' : 'Trigger apps'),
      subtitle: Text(
        vpn.smartAutoStopApplications.isEmpty
            ? (zh ? '未选择应用' : 'No apps selected')
            : (zh
                  ? '已选择 ${vpn.smartAutoStopApplications.length} 个应用'
                  : '${vpn.smartAutoStopApplications.length} apps selected'),
      ),
      delegate: const OpenDelegate(
        blur: false,
        widget: SmartPauseApplicationsPage(),
      ),
    );
  }
}

class SmartPauseApplicationsPage extends ConsumerStatefulWidget {
  const SmartPauseApplicationsPage({super.key});

  @override
  ConsumerState<SmartPauseApplicationsPage> createState() =>
      _SmartPauseApplicationsPageState();
}

class _SmartPauseApplicationsPageState
    extends ConsumerState<SmartPauseApplicationsPage>
    with WidgetsBindingObserver {
  late Future<List<Package>> _packages;
  bool? _permission;
  String _query = '';
  final _controller = ScrollController();
  late final Set<String> _pinned;

  Future<void> _authorize() async {
    final opened = await service?.openUsageAccessSettings() ?? false;
    if (!opened && mounted) {
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            zh
                ? '请在系统设置中搜索“使用情况访问权限”'
                : 'Open Usage access in Android Settings',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pinned = ref.read(vpnSettingProvider).smartAutoStopApplications.toSet();
    _packages = ref.read(systemActionProvider.notifier).getPackages();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    var granted = false;
    try {
      granted = await service?.hasUsageAccess() ?? false;
    } catch (_) {
      /* Show the unavailable state. */
    }
    if (mounted) setState(() => _permission = granted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final selected = ref.watch(
      vpnSettingProvider.select((vpn) => vpn.smartAutoStopApplications),
    );
    final surge = SurgeTheme.of(context);
    return CommonScaffold(
      title: zh ? '触发应用' : 'Trigger apps',
      backgroundColor: SurgeTheme.of(context).background,
      searchState: AppBarSearchState(
        onSearch: (query) => setState(() => _query = query.toLowerCase()),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              surge.spacing.pagePadding,
              12,
              surge.spacing.pagePadding,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    zh ? '使用情况访问权限' : 'Usage access',
                    style: context.typography.cardTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: _permission == true
                      ? (zh ? '管理授权' : 'Manage access')
                      : (zh
                            ? '打开系统授权设置'
                            : 'Open Android usage access settings'),
                  child: SurgeStatusButton(
                    key: const Key('usage-access-button'),
                    isActive: _permission == true,
                    activeLabel: zh ? '已授权' : 'Granted',
                    inactiveLabel: zh ? '授权' : 'Authorize',
                    loading: _permission == null,
                    compact: true,
                    height: 28,
                    horizontalPadding: 10,
                    minWidth: 76,
                    scaleMetrics: false,
                    textStyle: context.typography.mediaRunButtonLabel.copyWith(
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    onPressed: _authorize,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              surge.spacing.pagePadding,
              0,
              surge.spacing.pagePadding,
              8,
            ),
            child: DefaultTextStyle(
              style: context.typography.supporting.copyWith(
                color: surge.textSecondary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    zh
                        ? '用于启动时检测 VPN 环境的应用。'
                        : 'For apps that check for a VPN when opening.',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    zh
                        ? '选择自动保存；离开选中应用 30 秒后恢复代理，可信网络下继续暂停。'
                        : 'Selections save automatically. Resume 30s after leaving selected apps; stay paused on trusted networks.',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Package>>(
              future: _packages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(
                        () => _packages = ref
                            .read(systemActionProvider.notifier)
                            .getPackages(),
                      ),
                      child: Text(zh ? '重试加载应用' : 'Retry loading apps'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final packages = [...snapshot.data!];
                final installed = packages.map((p) => p.packageName).toSet();
                // Keep uninstalled selections visible and removable.
                for (final name in selected.where(
                  (name) => !installed.contains(name),
                )) {
                  packages.add(
                    Package(
                      packageName: name,
                      label: name,
                      system: false,
                      internet: false,
                      lastUpdateTime: 0,
                    ),
                  );
                }
                packages.sort((a, b) {
                  final priority =
                      (_pinned.contains(b.packageName) ? 1 : 0) -
                      (_pinned.contains(a.packageName) ? 1 : 0);
                  return priority != 0 ? priority : a.label.compareTo(b.label);
                });
                final visible = packages
                    .where(
                      (p) =>
                          p.label.toLowerCase().contains(_query) ||
                          p.packageName.toLowerCase().contains(_query),
                    )
                    .toList();
                return PackageSelectionList(
                  controller: _controller,
                  packages: visible,
                  selected: selected,
                  onChanged: (packageName, checked) =>
                      ref.read(vpnSettingProvider.notifier).update((vpn) {
                        final names = vpn.smartAutoStopApplications.toSet();
                        if (checked == true) {
                          names.add(packageName);
                        } else {
                          names.remove(packageName);
                        }
                        return vpn.copyWith(
                          smartAutoStopApplications: names.toList(),
                        );
                      }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
