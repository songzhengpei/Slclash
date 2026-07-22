import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/changelog_dialog.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  static const _slclashDesc =
      'SlClash 是基于 FlClash 和 Mihomo 内核私有裁剪和重设计的 Android 代理客户端。';
  static const _unknown = 'unknown';

  String get _coreVersion {
    final version = globalState.mihomoVersion;
    if (version.isEmpty) return _unknown;
    return version.startsWith('v') ? version : 'v$version';
  }

  String get _coreReleaseDate {
    final releaseDate = globalState.mihomoReleaseDate.takeFirstValid([
      globalState.coreBuildTime,
    ]);
    if (releaseDate.isEmpty) return _unknown;
    final dateTime = DateTime.tryParse(releaseDate);
    if (dateTime == null) return releaseDate;
    return dateTime.toLocal().show;
  }

  String get _coreInfo => 'Mihomo Core $_coreVersion · 发布日期 $_coreReleaseDate';

  String get _coreSourceUrl {
    final version = globalState.mihomoVersion;
    if (version.isEmpty) return 'https://github.com/MetaCubeX/mihomo';
    final tag = version.startsWith('v') ? version : 'v$version';
    return 'https://github.com/MetaCubeX/mihomo/tree/$tag';
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final data = await globalState.safeRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: context.appLocalizations.checkUpdate,
    );
    globalState.container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: data, isUser: true);
  }

  Future<void> _showChangelog(BuildContext context) {
    return globalState.showCommonDialog<bool>(
      child: const AppChangelogDialog(),
    );
  }

  Widget _buildMoreSection(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SurgeSection(
      title: appLocalizations.more,
      margin: EdgeInsets.zero,
      showDividers: true,
      children: [
        _AboutLinkItem(
          icon: SurgeIcons.systemUpdate,
          title: appLocalizations.checkUpdate,
          onTap: () => _checkUpdate(context),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.newRelease,
          title: '更新日志',
          onTap: () => _showChangelog(context),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.code,
          title: '原生项目',
          onTap: () =>
              globalState.openUrl('https://github.com/chen08209/FlClash'),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.proxyGroup,
          title: appLocalizations.project,
          onTap: () => globalState.openUrl('https://github.com/$repository'),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.memory,
          title: appLocalizations.core,
          onTap: () => globalState.openUrl(_coreSourceUrl),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    return CommonScaffold(
      title: appLocalizations.about,
      body: ColoredBox(
        color: surge.background,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SurgeCard(
              borderRadius: 18,
              shadow: true,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(
                    builder: (_, ref, _) {
                      return _DeveloperModeDetector(
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/icon.png',
                              width: 58,
                              height: 58,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appName,
                                    style: context.typography.appBarTitle
                                        .copyWith(color: surge.textPrimary),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    globalState.packageInfo.version,
                                    style: context.typography.supporting
                                        .copyWith(color: surge.textSecondary),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _coreInfo,
                                    style: context.typography.supporting
                                        .copyWith(color: surge.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onEnterDeveloperMode: () {
                          ref
                              .read(appSettingProvider.notifier)
                              .update(
                                (state) => state.copyWith(developerMode: true),
                              );
                          context.showNotifier(
                            appLocalizations.developerModeEnableTip,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 0, color: surge.separator),
                  const SizedBox(height: 12),
                  Text(
                    _slclashDesc,
                    style: context.typography.supporting.copyWith(
                      color: surge.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildMoreSection(context),
          ],
        ),
      ),
    );
  }
}

class _AboutLinkItem extends StatelessWidget {
  const _AboutLinkItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 28,
                  child: Center(
                    child: Icon(icon, size: 20, color: surge.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    style: context.typography.rowTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 28,
                  child: Center(
                    child: Icon(
                      SurgeIcons.openInNew,
                      size: 18,
                      color: surge.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
