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
