import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite/overwrite.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
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

  void _handleShowAddExtendPage() {
    showExtend(
      globalState.navigatorKey.currentState!.context,
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: AddProfileView(
            context: globalState.navigatorKey.currentState!.context,
          ),
          title: context.appLocalizations.addProfile,
        );
      },
    );
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
    return profiles.isNotEmpty
        ? [
            IconButton(
              onPressed: () {
                _updateProfiles(profiles);
              },
              icon: const Icon(Icons.sync),
            ),
            IconButton(
              onPressed: () {
                showSheet(
                  context: context,
                  builder: (_) {
                    return ReorderableProfilesSheet(profiles: profiles);
                  },
                );
              },
              icon: const Icon(Icons.sort),
              iconSize: 26,
            ),
          ]
        : [];
  }

  Widget _buildFAB() {
    return CommonFloatingActionButton(
      onPressed: _handleShowAddExtendPage,
      icon: const Icon(Icons.add),
      label: context.appLocalizations.addProfile,
    );
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
          title: appLocalizations.profiles,
          floatingActionButton: _buildFAB(),
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
                          _CurrentProfileSummary(profile: currentProfile),
                          const SizedBox(height: 20),
                        ],
                        _ProfileSectionHeader(
                          title: appLocalizations.profiles,
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

class _CurrentProfileSummary extends StatelessWidget {
  const _CurrentProfileSummary({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
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
                  context.appLocalizations.profile,
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
                label: profile.type.name,
                color: surge.primary,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.realLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              color: surge.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          LastUpdateTimeText(
            lastUpdateDate: profile.lastUpdateDate,
            style: context.textTheme.bodySmall?.copyWith(
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
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final isSelected = profile.id == groupValue;
    return SurgeCard(
      backgroundColor: isSelected
          ? surge.primary.withValues(alpha: 0.055)
          : surge.card,
      border: Border.all(
        color: isSelected
            ? surge.primary.withValues(alpha: 0.18)
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
            SizedBox(
              width: 24,
              child: AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  Icons.check_rounded,
                  color: surge.primary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : CommonPopupBox(
                            key: const ValueKey('menu'),
                            popup: CommonPopupMenu(
                              items: [
                                PopupMenuItemData(
                                  icon: Icons.edit_outlined,
                                  label: appLocalizations.edit,
                                  onPressed: () {
                                    _handleShowEditExtendPage(context);
                                  },
                                ),
                                PopupMenuItemData(
                                  icon: Icons.visibility_outlined,
                                  label: appLocalizations.preview,
                                  onPressed: () {
                                    _handlePreview(context);
                                  },
                                ),
                                if (profile.type == ProfileType.url) ...[
                                  PopupMenuItemData(
                                    icon: Icons.sync_alt_sharp,
                                    label: appLocalizations.sync,
                                    onPressed: () {
                                      updateProfile();
                                    },
                                  ),
                                ],
                                PopupMenuItemData(
                                  icon: Icons.emergency_outlined,
                                  label: appLocalizations.more,
                                  subItems: [
                                    PopupMenuItemData(
                                      icon: Icons.extension_outlined,
                                      label: appLocalizations.override,
                                      onPressed: () {
                                        _handlePushGenProfilePage(
                                          context,
                                          profile.id,
                                        );
                                      },
                                    ),
                                    // PopupMenuItemData(
                                    //   icon: Icons.extension_outlined,
                                    //   label: appLocalizations.override + "1",
                                    //   onPressed: () {
                                    //     final overrideProfileView = OverrideProfileView(
                                    //       profileId: profile.id,
                                    //     );
                                    //     BaseNavigator.push(
                                    //       context,
                                    //       overrideProfileView,
                                    //     );
                                    //   },
                                    // ),
                                    if (profile.type == ProfileType.url) ...[
                                      PopupMenuItemData(
                                        icon: Icons.copy,
                                        label: appLocalizations.copyLink,
                                        onPressed: () {
                                          _handleCopyLink(context);
                                        },
                                      ),
                                    ],
                                    PopupMenuItemData(
                                      icon: Icons.file_copy_outlined,
                                      label: appLocalizations.exportFile,
                                      onPressed: () {
                                        _handleExportFile(context);
                                      },
                                    ),
                                  ],
                                ),
                                PopupMenuItemData(
                                  danger: true,
                                  icon: Icons.delete_outlined,
                                  label: appLocalizations.delete,
                                  onPressed: () {
                                    _handleDeleteProfile(context);
                                  },
                                ),
                              ],
                            ),
                            targetBuilder: (open) {
                              return IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                color: surge.textSecondary,
                                onPressed: () {
                                  open();
                                },
                                icon: const Icon(Icons.more_horiz_rounded),
                              );
                            },
                          ),
                  );
                },
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
