class AppChangelogEntry {
  const AppChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  final String version;
  final String date;
  final List<String> changes;
}

const appChangelogEntries = <AppChangelogEntry>[
  AppChangelogEntry(
    version: 'v2.1.0',
    date: '2026-08-21',
    changes: [
      "重构 Mihomo 配置兼容逻辑，提升原生配置的兼容性与稳定性。",
      "优化代理组选择、节点固定及状态同步，更贴近 Mihomo 原生行为。",
      "优化网络诊断、智能暂停与 VPN 运行逻辑，提升日常使用稳定性。",
      "优化启动、页面切换和后台任务，降低不必要的资源占用。",
    ],
  ),
  AppChangelogEntry(
    version: 'v2.0.9',
    date: '2026-08-17',
    changes: [
      "优化英文界面文案与文字缩放适配，减少多处文本截断。 优化流媒体检测界面及模式选择菜单显示。 修复 Worker 备份恢复时误清空脚本、规则和策略组的问题。 优化订阅类型标签与订阅名称的对齐效果。",
    ],
  ),
  AppChangelogEntry(
    version: 'v2.0.8',
    date: '2026-07-24',
    changes: ["修复仅统计代理流量 优化订阅卡信息布局"],
  ),
  AppChangelogEntry(
    version: 'v2.0.7',
    date: '2026-07-22',
    changes: [
      'changelog207Item1',
      'changelog207Item2',
      'changelog207Item3',
      'changelog207Item4',
    ],
  ),
  AppChangelogEntry(
    version: 'v2.0.5',
    date: '2026-07-19',
    changes: ['changelog205Item1', 'changelog205Item2', 'changelog205Item3'],
  ),
  AppChangelogEntry(
    version: 'v2.0.4',
    date: '2026-07-17',
    changes: ['changelog204Item1', 'changelog204Item2', 'changelog204Item3'],
  ),
];

const lastShownChangelogVersionKey = 'lastShownChangelogVersion';

bool shouldShowChangelogAfterUpdate({
  required bool wasUpdated,
  required String? lastShownVersion,
  List<AppChangelogEntry> entries = appChangelogEntries,
}) {
  if (!wasUpdated || entries.isEmpty) return false;
  return lastShownVersion != entries.first.version;
}
