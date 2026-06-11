import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite/overwrite.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit.dart';
import 'preview.dart';

class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  Function? applyConfigDebounce;
  bool _isUpdating = false;
  bool _isCurrentExpanded = false;

  // final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final context = _targetKey.currentContext;
    //   if (context == null) {
    //     return;
    //   }
    //   Scrollable.ensureVisible(
    //     context,
    //     duration: commonDuration,
    //     alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    //   );
    // });
  }

  Future<void> _updateProfiles(List<Profile> profiles) async {
    if (_isUpdating == true) {
      return;
    }
    _isUpdating = true;
    final List<UpdatingMessage> messages = [];
    final updateProfiles = profiles.map<Future>((profile) async {
      if (profile.type == ProfileType.file) return;
      try {
        await globalState.container
            .read(profilesActionProvider.notifier)
            .updateProfile(profile, showLoading: true);
      } catch (e) {
        messages.add(
          UpdatingMessage(label: profile.realLabel, message: e.toString()),
        );
      }
    });
    await Future.wait(updateProfiles);
    if (messages.isNotEmpty) {
      globalState.showAllUpdatingMessagesDialog(messages);
    }
    _isUpdating = false;
  }

  List<Widget> _buildActions(List<Profile> profiles) {
    return [
      if (profiles.isNotEmpty)
        _ProfilesActionButton(
          tooltip: context.appLocalizations.sync,
          icon: Icons.sync_rounded,
          onPressed: () {
            _updateProfiles(profiles);
          },
        ),
      _ProfilesActionButton(
        tooltip: context.appLocalizations.settings,
        icon: Icons.tune_rounded,
        onPressed: () {
          showSheet(
            context: context,
            props: const SheetProps(isScrollControlled: true),
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: _ProfilesManageSheet(profiles: profiles),
                title: '订阅管理',
              );
            },
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final appLocalizations = context.appLocalizations;
        final surge = SurgeTheme.of(context);
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final state = ref.watch(profilesStateProvider);
        final currentProfile = state.profiles.getProfile(
          state.currentProfileId,
        );
        return CommonScaffold(
          backgroundColor: surge.background,
          isLoading: isLoading,
          title: '配置',
          actions: _buildActions(state.profiles),
          body: state.profiles.isEmpty
              ? NullStatus(
                  label: appLocalizations.nullProfileDesc,
                  illustration: const ProfileEmptyIllustration(),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    key: profilesStoreKey,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 112 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (currentProfile != null) ...[
                          _CurrentProfileSummary(
                            profile: currentProfile,
                            expanded: _isCurrentExpanded,
                            onExpandChanged: () {
                              setState(() {
                                _isCurrentExpanded = !_isCurrentExpanded;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        _ProfileSectionHeader(
                          title: '已添加订阅',
                          count: state.profiles.length,
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < state.profiles.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == state.profiles.length - 1 ? 0 : 10,
                            ),
                            child: ProfileItem(
                              profile: state.profiles[i],
                              groupValue: state.currentProfileId,
                              onChanged: (profileId) {
                                ref
                                        .read(currentProfileIdProvider.notifier)
                                        .value =
                                    profileId;
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _ProfilesActionButton extends StatelessWidget {
  const _ProfilesActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 22, color: surge.textPrimary),
          style: IconButton.styleFrom(
            fixedSize: const Size(40, 40),
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: Colors.transparent,
            foregroundColor: surge.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilesManageSheet extends StatefulWidget {
  const _ProfilesManageSheet({required this.profiles});

  final List<Profile> profiles;

  @override
  State<_ProfilesManageSheet> createState() => _ProfilesManageSheetState();
}

class _ProfilesManageSheetState extends State<_ProfilesManageSheet> {
  late List<Profile> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = List.from(widget.profiles);
  }

  @override
  void didUpdateWidget(covariant _ProfilesManageSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!profileListEquality.equals(oldWidget.profiles, widget.profiles)) {
      _profiles = List.from(widget.profiles);
    }
  }

  Future<void> _handleAddProfileFormFile() async {
    await globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(String url) async {
    await globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormURL(url);
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      await globalState.container
          .read(profilesActionProvider.notifier)
          .addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(url);
      });
    }
  }

  Future<void> _toAddUrl() async {
    final appLocalizations = context.appLocalizations;
    final url = await globalState.showCommonDialog<String>(
      child: InputDialog(
        autovalidateMode: AutovalidateMode.onUnfocus,
        title: appLocalizations.importFromURL,
        labelText: appLocalizations.url,
        value: '',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip('').trim();
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip('').trim();
          }
          return null;
        },
      ),
    );
    if (url != null) {
      await _handleAddProfileFormURL(url);
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      final profile = _profiles.removeAt(oldIndex);
      _profiles.insert(newIndex, profile);
    });
    globalState.container.read(profilesProvider.notifier).reorder(_profiles);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileSettingSection(
            title: '添加订阅',
            children: [
              _ProfileSettingOption(
                icon: Icons.qr_code_rounded,
                label: appLocalizations.qrcode,
                subtitle: appLocalizations.qrcodeDesc,
                onTap: _toScan,
              ),
              _ProfileSettingOption(
                icon: Icons.upload_file_rounded,
                label: appLocalizations.file,
                subtitle: appLocalizations.fileDesc,
                onTap: _handleAddProfileFormFile,
              ),
              _ProfileSettingOption(
                icon: Icons.cloud_download_rounded,
                label: appLocalizations.url,
                subtitle: appLocalizations.urlDesc,
                onTap: _toAddUrl,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileSettingSection(
            title: '订阅排序',
            subtitle: '${_profiles.length}',
            children: [
              if (_profiles.isEmpty)
                _ProfileSettingOption(
                  icon: Icons.sort_rounded,
                  label: '暂无订阅',
                  enabled: false,
                  onTap: () {},
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return commonProxyDecorator(child, index, animation);
                  },
                  onReorderItem: _handleReorder,
                  itemBuilder: (_, index) {
                    final profile = _profiles[index];
                    return _ProfileSortOption(
                      key: ValueKey(profile.id),
                      profile: profile,
                      index: index,
                    );
                  },
                  itemCount: _profiles.length,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSettingSection extends StatelessWidget {
  const _ProfileSettingSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        SurgeCard(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          shadow: true,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ProfileSettingOption extends StatelessWidget {
  const _ProfileSettingOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final foreground = enabled
        ? surge.textSecondary
        : surge.textSecondary.withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: enabled
                            ? surge.textPrimary
                            : surge.textSecondary.withValues(alpha: 0.4),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: surge.textSecondary,
                          fontSize: 11,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: surge.textSecondary.withValues(alpha: 0.75),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSortOption extends StatelessWidget {
  const _ProfileSortOption({
    super.key,
    required this.profile,
    required this.index,
  });

  final Profile profile;
  final int index;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: surge.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                profile.realLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle_rounded,
                color: surge.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentProfileSummary extends StatefulWidget {
  const _CurrentProfileSummary({
    required this.profile,
    required this.expanded,
    required this.onExpandChanged,
  });

  final Profile profile;
  final bool expanded;
  final VoidCallback onExpandChanged;

  @override
  State<_CurrentProfileSummary> createState() => _CurrentProfileSummaryState();
}

class _CurrentProfileSummaryState extends State<_CurrentProfileSummary> {
  late Future<List<Proxy>> _proxiesFuture;

  @override
  void initState() {
    super.initState();
    _proxiesFuture = _loadProfileProxies();
  }

  @override
  void didUpdateWidget(covariant _CurrentProfileSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _proxiesFuture = _loadProfileProxies();
    }
  }

  Future<List<Proxy>> _loadProfileProxies() async {
    final configMap = await coreController.getConfig(widget.profile.id);
    return ClashConfig.fromJson(configMap).proxies;
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return FutureBuilder<List<Proxy>>(
      future: _proxiesFuture,
      builder: (_, snapshot) {
        final proxies = snapshot.data ?? const <Proxy>[];
        final isLoading = snapshot.connectionState != ConnectionState.done;
        return SurgeCard(
          shadow: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '当前订阅',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: surge.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _ProfilePill(
                    label: widget.profile.type.name,
                    color: surge.primary,
                    filled: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.profile.realLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              _CurrentProfileExpandButton(
                expanded: widget.expanded,
                enabled: !isLoading,
                onTap: widget.onExpandChanged,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: widget.expanded && !isLoading
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _CurrentProfileProxyPreview(proxies: proxies),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrentProfileExpandButton extends StatelessWidget {
  const _CurrentProfileExpandButton({
    required this.expanded,
    required this.enabled,
    required this.onTap,
  });

  final bool expanded;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: surge.separator.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 16,
              color: enabled ? surge.textPrimary : surge.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                enabled ? '展开当前订阅节点' : '正在读取当前订阅节点',
                style: context.textTheme.labelMedium?.copyWith(
                  color: enabled ? surge.textPrimary : surge.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: surge.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentProfileProxyPreview extends StatelessWidget {
  const _CurrentProfileProxyPreview({required this.proxies});

  final List<Proxy> proxies;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final visibleProxies = proxies.take(8).toList();
    if (proxies.isEmpty) {
      return Text(
        '当前订阅没有可展示的节点',
        style: context.textTheme.labelSmall?.copyWith(
          color: surge.textSecondary,
          fontSize: 11,
          letterSpacing: 0,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2, bottom: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '节点列表',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: surge.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  '${proxies.length}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          for (final proxy in visibleProxies)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ProfileProxyPreviewCard(proxy: proxy),
            ),
          if (proxies.length > visibleProxies.length)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '还有 ${proxies.length - visibleProxies.length} 个节点，可到代理页查看完整分组',
                style: context.textTheme.labelSmall?.copyWith(
                  color: surge.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileProxyPreviewCard extends StatelessWidget {
  const _ProfileProxyPreviewCard({required this.proxy});

  final Proxy proxy;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      padding: EdgeInsets.zero,
      shadow: false,
      borderRadius: surge.radii.list,
      backgroundColor: surge.card,
      border: Border.all(color: surge.separator, width: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiText(
                    proxy.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: surge.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    proxy.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: surge.textSecondary,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ProfileDelayBadge(proxy: proxy),
          ],
        ),
      ),
    );
  }
}

class _ProfileDelayBadge extends ConsumerWidget {
  const _ProfileDelayBadge({required this.proxy});

  final Proxy proxy;

  Future<void> _handleTest(WidgetRef ref) async {
    final testUrl = ref.read(realTestUrlProvider(null));
    ref
        .read(proxiesActionProvider.notifier)
        .setDelay(Delay(url: testUrl, name: proxy.name, value: 0));
    ref
        .read(proxiesActionProvider.notifier)
        .setDelay(await coreController.getDelay(testUrl, proxy.name));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: null),
    );
    final color = delay == null
        ? surge.textSecondary
        : delay == 0
        ? surge.primary
        : delay < 0
        ? surge.red
        : utils.getDelayColor(delay) ?? surge.textSecondary;
    final label = delay == null
        ? 'Test'
        : delay == 0
        ? ''
        : delay > 0
        ? '$delay ms'
        : 'Timeout';

    return GestureDetector(
      onTap: () {
        _handleTest(ref);
      },
      child: SizedBox(
        width: 64,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: delay == null
                ? const Color(0xFFF4F6FA)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: delay == null
                  ? surge.separator.withValues(alpha: 0.55)
                  : color.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              );
            },
            child: Center(
              key: ValueKey(label),
              child: delay == 0
                  ? SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      strutStyle: const StrutStyle(
                        forceStrutHeight: true,
                        height: 1,
                      ),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  const _ProfileSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(
                color: surge.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            '$count',
            style: context.textTheme.labelSmall?.copyWith(
              color: surge.textSecondary,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileItem extends StatelessWidget {
  final Profile profile;
  final int? groupValue;
  final void Function(int? value) onChanged;

  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
  });

  Future<void> _handleDeleteProfile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) {
      return;
    }
    await globalState.container
        .read(profilesActionProvider.notifier)
        .deleteProfile(profile.id);
  }

  Future<void> _handlePreview(BuildContext context) async {
    BaseNavigator.push<String>(context, PreviewProfileView(profile: profile));
  }

  Future updateProfile() async {
    if (profile.type == ProfileType.file) return;
    await globalState.loadingRun(() async {
      await globalState.container
          .read(profilesActionProvider.notifier)
          .updateProfile(profile, showLoading: true);
    }, tag: LoadingTag.profiles);
  }

  void _handleShowEditExtendPage(BuildContext context) {
    showExtend(
      context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: EditProfileView(profile: profile, context: context),
          title: context.appLocalizations.edit,
        );
      },
    );
  }

  List<Widget> _buildUrlProfileInfo(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final subscriptionInfo = profile.subscriptionInfo;
    return [
      const SizedBox(height: 6),
      if (subscriptionInfo != null)
        SubscriptionInfoView(subscriptionInfo: subscriptionInfo),
      LastUpdateTimeText(
        lastUpdateDate: profile.lastUpdateDate,
        style: context.textTheme.labelSmall?.copyWith(
          color: surge.textSecondary,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    ];
  }

  List<Widget> _buildFileProfileInfo(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return [
      const SizedBox(height: 6),
      LastUpdateTimeText(
        lastUpdateDate: profile.lastUpdateDate,
        style: context.textTheme.labelSmall?.copyWith(
          color: surge.textSecondary,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    ];
  }

  Future<void> _handleCopyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: profile.url));
    if (context.mounted) {
      context.showNotifier(context.appLocalizations.copySuccess);
    }
  }

  Future<void> _handleExportFile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      final mFile = await profile.file;
      final value = await picker.saveFile(
        profile.realLabel,
        mFile.readAsBytesSync(),
      );
      if (value == null) return false;
      return true;
    }, title: appLocalizations.tip);
    if (res == true && context.mounted) {
      context.showNotifier(appLocalizations.exportSuccess);
    }
  }

  void _handlePushGenProfilePage(BuildContext context, int id) {
    BaseNavigator.push(context, OverwriteView(profileId: id));
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isSelected = profile.id == groupValue;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SurgeCard(
          backgroundColor: isSelected
              ? surge.primary.withValues(alpha: 0.055)
              : surge.card,
          border: Border.all(
            color: isSelected
                ? surge.primary.withValues(alpha: 0.16)
                : surge.separator,
            width: 0.5,
          ),
          shadow: false,
          borderRadius: surge.radii.list,
          padding: EdgeInsets.zero,
          onTap: () {
            onChanged(profile.id);
          },
          child: Padding(
            key: Key(profile.id.toString()),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _ProfileTextBlock(
                    profile: profile,
                    info: switch (profile.type) {
                      ProfileType.file => _buildFileProfileInfo(context),
                      ProfileType.url => _buildUrlProfileInfo(context),
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _ProfilePill(label: profile.type.name, color: surge.primary),
                const SizedBox(width: 4),
                SizedBox(
                  height: 40,
                  width: 40,
                  child: Consumer(
                    builder: (_, ref, _) {
                      final isUpdating = ref.watch(
                        isUpdatingProvider(profile.updatingKey),
                      );
                      return FadeThroughBox(
                        child: isUpdating
                            ? const Padding(
                                key: ValueKey('loading'),
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : _ProfileActionButton(
                                onEdit: () {
                                  _handleShowEditExtendPage(context);
                                },
                                onPreview: () {
                                  _handlePreview(context);
                                },
                                onSync: profile.type == ProfileType.url
                                    ? updateProfile
                                    : null,
                                onOverride: () {
                                  _handlePushGenProfilePage(
                                    context,
                                    profile.id,
                                  );
                                },
                                onCopyLink: profile.type == ProfileType.url
                                    ? () {
                                        _handleCopyLink(context);
                                      }
                                    : null,
                                onExport: () {
                                  _handleExportFile(context);
                                },
                                onDelete: () {
                                  _handleDeleteProfile(context);
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: -6,
          child: AnimatedScale(
            scale: isSelected ? 1 : 0.65,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: surge.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: surge.card, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: surge.primary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.onEdit,
    required this.onPreview,
    required this.onOverride,
    required this.onExport,
    required this.onDelete,
    this.onSync,
    this.onCopyLink,
  });

  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback? onSync;
  final VoidCallback onOverride;
  final VoidCallback? onCopyLink;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final appLocalizations = context.appLocalizations;
    return CommonPopupBox(
      key: const ValueKey('menu'),
      popup: _ProfileActionMenu(
        children: [
          _ProfileActionMenuItem(
            icon: Icons.edit_outlined,
            label: appLocalizations.edit,
            onTap: onEdit,
          ),
          _ProfileActionMenuItem(
            icon: Icons.visibility_outlined,
            label: appLocalizations.preview,
            onTap: onPreview,
          ),
          if (onSync != null)
            _ProfileActionMenuItem(
              icon: Icons.sync_rounded,
              label: appLocalizations.sync,
              onTap: onSync!,
            ),
          _ProfileActionMenuItem(
            icon: Icons.tune_rounded,
            label: appLocalizations.override,
            onTap: onOverride,
          ),
          if (onCopyLink != null)
            _ProfileActionMenuItem(
              icon: Icons.link_rounded,
              label: appLocalizations.copyLink,
              onTap: onCopyLink!,
            ),
          _ProfileActionMenuItem(
            icon: Icons.ios_share_rounded,
            label: appLocalizations.exportFile,
            onTap: onExport,
          ),
          _ProfileActionMenuItem(
            icon: Icons.delete_outline_rounded,
            label: appLocalizations.delete,
            danger: true,
            onTap: onDelete,
          ),
        ],
      ),
      targetBuilder: (open) {
        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          color: surge.textSecondary,
          onPressed: open,
          icon: const Icon(Icons.more_horiz_rounded),
        );
      },
    );
  }
}

class _ProfileActionMenu extends StatelessWidget {
  const _ProfileActionMenu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      shadow: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      borderRadius: 14,
      border: Border.all(color: surge.separator.withValues(alpha: 0.7)),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 188),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _ProfileActionMenuItem extends StatelessWidget {
  const _ProfileActionMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = danger ? surge.red : surge.textPrimary;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: danger
                    ? surge.red.withValues(alpha: 0.09)
                    : const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTextBlock extends StatelessWidget {
  const _ProfileTextBlock({required this.profile, required this.info});

  final Profile profile;
  final List<Widget> info;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          profile.realLabel,
          style: context.textTheme.titleMedium?.copyWith(
            color: surge.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: info,
        ),
      ],
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class LastUpdateTimeText extends StatelessWidget {
  final DateTime? lastUpdateDate;
  final TextStyle? style;

  const LastUpdateTimeText({
    super.key,
    required this.lastUpdateDate,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (lastUpdateDate == null) {
      return Text('', style: style);
    }
    return TickBuilder(
      duration: const Duration(minutes: 1),
      builder: (context, _) {
        return Text(
          lastUpdateDate!.getLastUpdateTimeDesc(context),
          style: style,
        );
      },
    );
  }
}

class ReorderableProfilesSheet extends StatefulWidget {
  final List<Profile> profiles;

  const ReorderableProfilesSheet({super.key, required this.profiles});

  @override
  State<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState extends State<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index) {
    final position = ItemPosition.get(index, profiles.length);
    final profile = profiles[index];
    return ItemPositionProvider(
      key: Key(profile.id.toString()),
      position: position,
      child: DecorationListItem(
        trailing: ReorderableDelayedDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(profile.realLabel),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    globalState.container.read(profilesProvider.notifier).reorder(profiles);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AdaptiveSheetScaffold(
      sheetTransparentToolBar: true,
      actions: [IconButtonData(icon: Icons.check, onPressed: _handleSave)],
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(top: context.sheetTopPadding),
          proxyDecorator: (child, index, animation) {
            return commonProxyDecorator(_buildItem(index), index, animation);
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final profile = profiles.removeAt(oldIndex);
              profiles.insert(newIndex, profile);
            });
          },
          itemBuilder: (_, index) {
            return _buildItem(index);
          },
          itemCount: profiles.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
