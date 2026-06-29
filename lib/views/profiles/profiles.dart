import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite/overwrite.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit.dart';
import 'media_check.dart';
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
                          const _ProfileSectionHeader(title: '当前订阅'),
                          const SizedBox(height: 8),
                          _CurrentProfileSummary(
                            profile: currentProfile,
                            expanded: _isCurrentExpanded,
                            onExpandChanged: () {
                              setState(() {
                                _isCurrentExpanded = !_isCurrentExpanded;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          const _ProfileSectionHeader(title: '快捷操作'),
                          const SizedBox(height: 8),
                          _MediaCheckEntryCard(
                            profile: currentProfile,
                            profiles: state.profiles,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _ProfileSectionHeader(
                          title: '已添加订阅',
                          count: state.profiles.length,
                        ),
                        const SizedBox(height: 8),
                        _ProfileListContainer(
                          profiles: state.profiles,
                          currentProfileId: state.currentProfileId,
                          onSelect: (profileId) {
                            ref.read(currentProfileIdProvider.notifier).value =
                                profileId;
                          },
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

class _MediaCheckEntryPill extends StatelessWidget {
  const _MediaCheckEntryPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
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

  Future<void> _handleAddProfileFormURL(
    String url, {
    String? label,
    bool autoUpdate = true,
    Duration autoUpdateDuration = defaultUpdateDuration,
  }) async {
    await globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormURL(
          url,
          label: label,
          autoUpdate: autoUpdate,
          autoUpdateDuration: autoUpdateDuration,
        );
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
    final result = await showSheet<_AddUrlProfileResult>(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return const FractionallySizedBox(
          heightFactor: 0.75,
          child: _AddUrlProfileSheet(),
        );
      },
    );
    if (result != null) {
      await _handleAddProfileFormURL(
        result.url,
        label: result.label,
        autoUpdate: result.autoUpdate,
        autoUpdateDuration: result.autoUpdateDuration,
      );
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
                label: appLocalizations.qrcode,
                subtitle: appLocalizations.qrcodeDesc,
                onTap: _toScan,
              ),
              _ProfileSettingOption(
                label: appLocalizations.file,
                subtitle: appLocalizations.fileDesc,
                onTap: _handleAddProfileFormFile,
              ),
              _ProfileSettingOption(
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
                  onReorder: _handleReorder,
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

class _AddUrlProfileResult {
  const _AddUrlProfileResult({
    required this.url,
    required this.autoUpdate,
    required this.autoUpdateDuration,
    this.label,
  });

  final String url;
  final String? label;
  final bool autoUpdate;
  final Duration autoUpdateDuration;
}

class _AddUrlProfileSheet extends StatefulWidget {
  const _AddUrlProfileSheet();

  @override
  State<_AddUrlProfileSheet> createState() => _AddUrlProfileSheetState();
}

class _AddUrlProfileSheetState extends State<_AddUrlProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _urlController = TextEditingController();
  final _autoUpdateDurationController = TextEditingController(
    text: defaultUpdateDuration.inMinutes.toString(),
  );
  bool _autoUpdate = false;

  void _handleSubmit() {
    if (_formKey.currentState?.validate() == false) return;
    Navigator.of(context).pop(
      _AddUrlProfileResult(
        url: _urlController.text.trim(),
        label: _labelController.text.trim(),
        autoUpdate: _autoUpdate,
        autoUpdateDuration: Duration(
          minutes: int.parse(_autoUpdateDurationController.text),
        ),
      ),
    );
  }

  void _setAutoUpdate(bool value) {
    if (_autoUpdate == value) return;
    setState(() {
      _autoUpdate = value;
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _autoUpdateDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AdaptiveSheetScaffold(
      title: appLocalizations.importFromURL,
      actions: [IconButtonData(icon: Icons.check, onPressed: _handleSubmit)],
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SurgeField(
              label: appLocalizations.name,
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: _labelController,
                decoration: surgeInputDecoration(
                  context,
                  hintText: appLocalizations.optional,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SurgeField(
              label: appLocalizations.url,
              child: TextFormField(
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.url,
                controller: _urlController,
                decoration: surgeInputDecoration(
                  context,
                  hintText: appLocalizations.url,
                ),
                onFieldSubmitted: (_) {
                  _handleSubmit();
                },
                validator: (value) {
                  final url = value?.trim();
                  if (url == null || url.isEmpty) {
                    return appLocalizations.emptyTip('').trim();
                  }
                  if (!url.isUrl) {
                    return appLocalizations.urlTip('').trim();
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 18),
            SurgeToggleFieldRow(
              label: appLocalizations.autoUpdate,
              value: _autoUpdate,
              onChanged: _setAutoUpdate,
            ),
            AnimatedSize(
              duration: SurgeMotion.reveal,
              curve: SurgeMotion.stateCurve,
              alignment: Alignment.topCenter,
              child: _autoUpdate
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: SurgeField(
                        label: appLocalizations.autoUpdateInterval,
                        child: TextFormField(
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.number,
                          controller: _autoUpdateDurationController,
                          decoration: surgeInputDecoration(
                            context,
                            hintText: appLocalizations.autoUpdateInterval,
                          ),
                          onFieldSubmitted: (_) {
                            _handleSubmit();
                          },
                          validator: (value) {
                            if (!_autoUpdate) return null;
                            if (value == null || value.isEmpty) {
                              return appLocalizations
                                  .profileAutoUpdateIntervalNullValidationDesc;
                            }
                            try {
                              int.parse(value);
                            } catch (_) {
                              return appLocalizations
                                  .profileAutoUpdateIntervalInvalidValidationDesc;
                            }
                            return null;
                          },
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
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
    required this.label,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.enabled = true,
  });

  final IconData? icon;
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
              if (icon != null) ...[
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
              ],
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
  void Function()? _removeGroupsListener;

  void _refreshProxies() {
    if (mounted) {
      setState(() {
        _proxiesFuture = _loadProfileProxies();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _proxiesFuture = _loadProfileProxies();
    final sub = globalState.container.listen(
      groupsProvider,
      (_, _) => _refreshProxies(),
    );
    _removeGroupsListener = sub.close;
  }

  @override
  void dispose() {
    _removeGroupsListener?.call();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CurrentProfileSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _proxiesFuture = _loadProfileProxies();
    }
  }

  Future<List<Proxy>> _loadProfileProxies() async {
    final currentProfileId = globalState.container.read(
      currentProfileIdProvider,
    );
    final groups = globalState.container.read(groupsProvider);
    return loadProfileLeafProxies(
      profileId: widget.profile.id,
      currentProfileId: currentProfileId,
      fallbackGroups: groups,
    );
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
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
                  ),
                  const SizedBox(width: 12),
                  _ProfilePill(
                    label: widget.profile.type.name,
                    color: surge.textSecondary,
                    filled: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CurrentProfileDetails(profile: widget.profile),
              const SizedBox(height: 10),
              Divider(height: 1, color: surge.separator),
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

class _CurrentProfileDetails extends StatelessWidget {
  const _CurrentProfileDetails({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final subscriptionInfo = profile.subscriptionInfo;
    final infoStyle = context.textTheme.labelSmall?.copyWith(
      color: surge.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

    if (subscriptionInfo == null || subscriptionInfo.total == 0) {
      return LastUpdateTimeText(
        lastUpdateDate: profile.lastUpdateDate,
        style: infoStyle,
      );
    }

    final used = subscriptionInfo.upload + subscriptionInfo.download;
    final total = subscriptionInfo.total;
    final progress = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final usedText = used.traffic.show;
    final totalText = total.traffic.show;
    final expireText = subscriptionInfo.expire != 0
        ? DateTime.fromMillisecondsSinceEpoch(
            subscriptionInfo.expire * 1000,
          ).show
        : context.appLocalizations.infiniteTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: surge.fill,
            color: surge.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '$usedText / $totalText · $expireText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: infoStyle,
              ),
            ),
            const SizedBox(width: 12),
            LastUpdateTimeText(
              lastUpdateDate: profile.lastUpdateDate,
              style: infoStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaCheckEntryCard extends StatelessWidget {
  const _MediaCheckEntryCard({required this.profile, required this.profiles});

  final Profile profile;
  final List<Profile> profiles;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final profileCount = profiles.length;
    return SurgeCard(
      shadow: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      onTap: () {
        BaseNavigator.push(
          context,
          ProfileMediaCheckView(profiles: profiles, initialProfile: profile),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 30,
                height: 40,
                child: Icon(
                  Icons.fact_check_rounded,
                  color: surge.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '流媒体检测',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: surge.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profileCount > 1 ? '按订阅手动检测 · 结果缓存' : '手动检测 · 结果缓存',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: surge.textSecondary,
                          fontSize: 11,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: surge.textSecondary,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MediaCheckEntryPill(
                  label: 'GPT',
                  color: surge.purple,
                  icon: Icons.psychology_alt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MediaCheckEntryPill(
                  label: 'YouTube',
                  color: surge.orange,
                  icon: Icons.smart_display_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MediaCheckEntryPill(
                  label: '健康',
                  color: surge.green,
                  icon: Icons.eco_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
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
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 17,
              color: enabled ? surge.textPrimary : surge.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                enabled ? '展开当前订阅节点' : '正在读取当前订阅节点',
                style: context.textTheme.labelMedium?.copyWith(
                  color: enabled ? surge.textPrimary : surge.textSecondary,
                  fontSize: 13,
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
                size: 21,
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
                const SizedBox(width: 8),
                _ProfileProxyTestAllButton(proxies: proxies),
              ],
            ),
          ),
          SizedBox(
            height: math.min(300, proxies.length * 53).toDouble(),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: const ScrollbarThemeData(
                  mainAxisMargin: 8,
                  crossAxisMargin: -3,
                ),
              ),
              child: Scrollbar(
                thumbVisibility: false,
                child: ListView.separated(
                  padding: const EdgeInsets.only(right: 3),
                  itemCount: proxies.length,
                  itemBuilder: (_, index) =>
                      _ProfileProxyPreviewCard(proxy: proxies[index]),
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: surge.separator),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileProxyTestAllButton extends StatefulWidget {
  const _ProfileProxyTestAllButton({required this.proxies});

  final List<Proxy> proxies;

  @override
  State<_ProfileProxyTestAllButton> createState() =>
      _ProfileProxyTestAllButtonState();
}

class _ProfileProxyTestAllButtonState
    extends State<_ProfileProxyTestAllButton> {
  var _testing = false;

  Future<void> _handleTestAll() async {
    if (_testing) return;
    setState(() {
      _testing = true;
    });
    await delayTest(widget.proxies);
    if (!mounted) return;
    setState(() {
      _testing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Tooltip(
      message: '测试全部延迟',
      child: GestureDetector(
        onTap: _handleTestAll,
        child: Container(
          width: 28,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surge.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: surge.separator.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _testing
                ? SizedBox.square(
                    key: const ValueKey('loading'),
                    dimension: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: surge.textSecondary,
                    ),
                  )
                : Icon(
                    Icons.network_ping_rounded,
                    key: const ValueKey('icon'),
                    size: 15,
                    color: surge.textSecondary,
                  ),
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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
    try {
      ref
          .read(proxiesActionProvider.notifier)
          .setDelay(await coreController.getDelay(testUrl, proxy.name));
    } catch (e) {
      commonPrint.log('_ProfileDelayBadge test failed for ${proxy.name}: $e');
      ref
          .read(proxiesActionProvider.notifier)
          .setDelay(Delay(url: testUrl, name: proxy.name, value: -1));
    }
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
        ? surge.textSecondary
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
            color: delay == null ? surge.fill : color.withValues(alpha: 0.1),
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
  const _ProfileSectionHeader({required this.title, this.count});

  final String title;
  final int? count;

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
          if (count != null)
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

class _ProfileListContainer extends StatelessWidget {
  const _ProfileListContainer({
    required this.profiles,
    required this.currentProfileId,
    required this.onSelect,
  });

  final List<Profile> profiles;
  final int? currentProfileId;
  final void Function(int? profileId) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ProfileListItem(
        profile: profiles[i],
        isSelected: profiles[i].id == currentProfileId,
        onTap: () => onSelect(profiles[i].id),
      ),
    );
  }
}

class _SelectedProfileDot extends StatelessWidget {
  const _SelectedProfileDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Positioned(
      right: 10,
      top: -6,
      child: AnimatedScale(
        scale: selected ? 1 : 0.65,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
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
                  color: surge.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileListItem extends StatelessWidget {
  const _ProfileListItem({
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  final Profile profile;
  final bool isSelected;
  final VoidCallback onTap;

  Future<void> _handleDeleteProfile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) return;
    await globalState.container
        .read(profilesActionProvider.notifier)
        .deleteProfile(profile.id);
  }

  Future<void> _handlePreview(BuildContext context) async {
    BaseNavigator.push<String>(context, PreviewProfileView(profile: profile));
  }

  Future<void> _updateProfile() async {
    if (profile.type == ProfileType.file) return;
    await globalState.loadingRun(() async {
      await globalState.container
          .read(profilesActionProvider.notifier)
          .updateProfile(profile, showLoading: true);
    }, tag: LoadingTag.profiles);
  }

  void _handleShowEditExtendPage(BuildContext context) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: EditProfileView(profile: profile, context: context),
        );
      },
    );
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
    final hasTraffic =
        profile.subscriptionInfo != null && profile.subscriptionInfo!.total > 0;
    return Consumer(
      builder: (_, ref, _) {
        final dynamicColor = ref.watch(
          themeSettingProvider.select((state) => state.dynamicColor),
        );
        final selectedBorderColor = !dynamicColor
            ? surge.textPrimary
            : surge.primary;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SurgeCard(
              backgroundColor: isSelected ? surge.selectedFill : surge.card,
              border: Border.all(
                color: isSelected
                    ? selectedBorderColor
                    : surge.separator.withValues(alpha: 0.95),
                width: isSelected ? 1.05 : 0.75,
              ),
              shadow: false,
              borderRadius: surge.radii.list,
              padding: EdgeInsets.zero,
              height: hasTraffic ? 92 : 78,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _ProfileTextBlock(
                        profile: profile,
                        info: [_ProfileListSummary(profile: profile)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 88,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ProfilePill(
                            label: profile.type.name,
                            color: surge.textSecondary,
                          ),
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
                                          onSync:
                                              profile.type == ProfileType.url
                                              ? _updateProfile
                                              : null,
                                          onOverride: () {
                                            _handlePushGenProfilePage(
                                              context,
                                              profile.id,
                                            );
                                          },
                                          onCopyLink:
                                              profile.type == ProfileType.url
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
                  ],
                ),
              ),
            ),
            _SelectedProfileDot(selected: isSelected),
          ],
        );
      },
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
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: EditProfileView(profile: profile, context: context),
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
    return Consumer(
      builder: (_, ref, _) {
        final dynamicColor = ref.watch(
          themeSettingProvider.select((state) => state.dynamicColor),
        );
        final selectedBorderColor = !dynamicColor
            ? const Color(0xFFD8DAE0)
            : surge.primary;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SurgeCard(
              backgroundColor: isSelected ? surge.selectedFill : surge.card,
              border: Border.all(
                color: isSelected ? selectedBorderColor : surge.separator,
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
                    _ProfilePill(
                      label: profile.type.name,
                      color: surge.textSecondary,
                    ),
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
                          color: surge.shadow,
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
      },
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
                    : surge.textSecondary.withValues(alpha: 0.08),
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
  const _ProfileTextBlock({required this.profile, this.info = const []});

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
        if (info.isNotEmpty)
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

class _ProfileListSummary extends StatelessWidget {
  const _ProfileListSummary({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final subscriptionInfo = profile.subscriptionInfo;
    final hasTraffic = subscriptionInfo != null && subscriptionInfo.total > 0;
    final used = hasTraffic
        ? subscriptionInfo.upload + subscriptionInfo.download
        : 0;
    final total = hasTraffic ? subscriptionInfo.total : 0;
    final progress = hasTraffic ? (used / total).clamp(0.0, 1.0) : 0.0;
    final expireText = hasTraffic && subscriptionInfo.expire != 0
        ? DateTime.fromMillisecondsSinceEpoch(
            subscriptionInfo.expire * 1000,
          ).show
        : context.appLocalizations.infiniteTime;
    final trafficText = '${used.traffic.show} / ${total.traffic.show}';
    final detailStyle = context.textTheme.labelSmall?.copyWith(
      color: surge.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

    if (!hasTraffic) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: LastUpdateTimeText(
          lastUpdateDate: profile.lastUpdateDate,
          style: detailStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2.5),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              color: hasTraffic ? surge.primary : Colors.transparent,
              backgroundColor: surge.fill,
            ),
          ),
          const SizedBox(height: 7),
          _ProfileSummaryLine(
            lastUpdateDate: profile.lastUpdateDate,
            trafficText: trafficText,
            expireText: expireText,
            style: detailStyle,
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryLine extends StatelessWidget {
  const _ProfileSummaryLine({
    required this.lastUpdateDate,
    required this.trafficText,
    required this.expireText,
    required this.style,
  });

  final DateTime? lastUpdateDate;
  final String trafficText;
  final String expireText;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (lastUpdateDate == null) {
      return _SummaryText(text: '$trafficText · $expireText', style: style);
    }
    return TickBuilder(
      duration: const Duration(minutes: 1),
      builder: (context, _) {
        return _SummaryText(
          text:
              '${lastUpdateDate!.getLastUpdateTimeDesc(context)} · $trafficText · $expireText',
          style: style,
        );
      },
    );
  }
}

class _SummaryText extends StatelessWidget {
  const _SummaryText({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: style,
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
