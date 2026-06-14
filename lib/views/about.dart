import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  static const _slclashDesc =
      'SlClash 是基于 FlClash 和 Mihomo 内核私有裁剪和重设计的 Android 代理客户端。';

  Future<void> _checkUpdate(BuildContext context) async {
    final data = await globalState.safeRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: context.appLocalizations.checkUpdate,
    );
    globalState.container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: data, isUser: true);
  }

  Widget _buildMoreSection(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SurgeSection(
      title: appLocalizations.more,
      margin: EdgeInsets.zero,
      showDividers: true,
      children: [
        ListItem(
          title: Text(appLocalizations.checkUpdate),
          onTap: () {
            _checkUpdate(context);
          },
        ),
        ListItem(
          title: const Text('原生项目'),
          onTap: () {
            globalState.openUrl('https://github.com/chen08209/FlClash');
          },
          trailing: const Icon(Icons.launch),
        ),
        ListItem(
          title: Text(appLocalizations.project),
          onTap: () {
            globalState.openUrl('https://github.com/$repository');
          },
          trailing: const Icon(Icons.launch),
        ),
        ListItem(
          title: Text(appLocalizations.core),
          onTap: () {
            globalState.openUrl(
              'https://github.com/chen08209/Clash.Meta/tree/FlClash',
            );
          },
          trailing: const Icon(Icons.launch),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    return BaseScaffold(
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
                                    style: context.textTheme.titleLarge
                                        ?.copyWith(
                                          color: surge.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    globalState.packageInfo.version,
                                    style: context.textTheme.labelMedium
                                        ?.copyWith(
                                          color: surge.textSecondary,
                                          letterSpacing: 0,
                                        ),
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
                    style: context.textTheme.bodySmall?.copyWith(
                      color: surge.textSecondary,
                      height: 1.35,
                      letterSpacing: 0,
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
