import 'package:fl_clash/common/app_changelog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest changelog matches the v2.2.4 release', () {
    expect(appChangelogEntries.first.version, 'v2.2.4');
    expect(appChangelogEntries.first.changes, [
      '新增按应用触发的智能暂停，兼容少数启动时检测 VPN 环境的应用。',
      '更新 Mihomo 内核至最新稳定版 v1.19.32。',
    ]);
    expect(
      appChangelogEntries.map((entry) => entry.version),
      isNot(contains('v2.1.6')),
    );
    expect(
      appChangelogEntries.map((entry) => entry.version),
      isNot(contains('v2.1.7')),
    );
  });

  test('fresh installs do not show the changelog automatically', () {
    expect(
      shouldShowChangelogAfterUpdate(wasUpdated: false, lastShownVersion: null),
      isFalse,
    );
  });

  test('an updated install shows the latest changelog once', () {
    expect(
      shouldShowChangelogAfterUpdate(wasUpdated: true, lastShownVersion: null),
      isTrue,
    );
    expect(
      shouldShowChangelogAfterUpdate(
        wasUpdated: true,
        lastShownVersion: appChangelogEntries.first.version,
      ),
      isFalse,
    );
  });
}
