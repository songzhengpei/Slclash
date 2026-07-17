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
    version: 'v2.0.4',
    date: '2026-07-17',
    changes: [
      '本地导出和 WebDAV 备份统一使用原生 V1 母包。',
      'Slclash 导出的母包可直接导入 Clash Verge Rev，覆盖订阅数据。',
      '恢复仅更新订阅数据，不影响其他应用设置。',
    ],
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
