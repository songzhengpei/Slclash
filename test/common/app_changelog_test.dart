import 'package:fl_clash/common/app_changelog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest changelog matches the v2.2.6 release', () {
    expect(appChangelogEntries.first.version, 'v2.2.6');
    expect(appChangelogEntries.first.changes, [
      '更新 Mihomo 内核至最新稳定版 v1.19.33。',
      '优化公共 Wi-Fi 认证完成及网络恢复后的连接清理，减少失效连接残留。',
      '统一节点与策略组面板样式，修复访问控制设置对齐问题。',
    ]);
    expect(appChangelogEntries[1].version, 'v2.2.5');
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
