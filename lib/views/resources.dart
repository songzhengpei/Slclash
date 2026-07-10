import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' hide context;

const _resourceAutoUpdateModeKey = 'resource_auto_update_mode';
const _resourceAutoUpdateLastRunKey = 'resource_auto_update_last_run';

enum _ResourceAutoUpdateMode {
  off,
  daily,
  everyThreeDays,
  everySevenDays;

  int get intervalDays {
    return switch (this) {
      _ResourceAutoUpdateMode.off => 0,
      _ResourceAutoUpdateMode.daily => 1,
      _ResourceAutoUpdateMode.everyThreeDays => 3,
      _ResourceAutoUpdateMode.everySevenDays => 7,
    };
  }

  String get title {
    return switch (this) {
      _ResourceAutoUpdateMode.off => '关闭',
      _ResourceAutoUpdateMode.daily => '每日',
      _ResourceAutoUpdateMode.everyThreeDays => '三日',
      _ResourceAutoUpdateMode.everySevenDays => '七日',
    };
  }

  String get subtitle {
    return switch (this) {
      _ResourceAutoUpdateMode.off => '仅手动更新资源文件',
      _ResourceAutoUpdateMode.daily => '每天首次打开资源页自动更新',
      _ResourceAutoUpdateMode.everyThreeDays => '满三天后首次打开自动更新',
      _ResourceAutoUpdateMode.everySevenDays => '满七天后首次打开自动更新',
    };
  }

  String get statusText {
    return switch (this) {
      _ResourceAutoUpdateMode.off => '手动',
      _ResourceAutoUpdateMode.daily => '自动更新：每日',
      _ResourceAutoUpdateMode.everyThreeDays => '自动更新：3日',
      _ResourceAutoUpdateMode.everySevenDays => '自动更新：7日',
    };
  }

  static _ResourceAutoUpdateMode fromName(String? name) {
    return _ResourceAutoUpdateMode.values.firstWhere(
      (item) => item.name == name,
      orElse: () => _ResourceAutoUpdateMode.everySevenDays,
    );
  }
}

const _newDefaultGeoXUrls = <String, String>{
  'mmdb':
      'https://testingcf.jsdelivr.net/gh/Loyalsoldier/geoip@release/Country.mmdb',
  'geoip':
      'https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat',
  'geosite':
      'https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat',
  'asn':
      'https://testingcf.jsdelivr.net/gh/xishang0128/geoip@release/GeoLite2-ASN.mmdb',
};

const _oldDefaultGeoXUrls = <String, String>{
  'mmdb':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb',
  'geoip':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat',
  'geosite':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat',
  'asn':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb',
};

@immutable
class GeoItem {
  const GeoItem({
    required this.label,
    required this.key,
    required this.fileName,
    required this.icon,
  });

  final String label;
  final String key;
  final String fileName;
  final IconData icon;
}

const _geoItems = <GeoItem>[
  GeoItem(
    label: 'GEOIP',
    fileName: GEOIP,
    key: 'geoip',
    icon: SurgeIcons.network,
  ),
  GeoItem(
    label: 'GEOSITE',
    fileName: GEOSITE,
    key: 'geosite',
    icon: SurgeIcons.explore,
  ),
  GeoItem(label: 'MMDB', fileName: MMDB, key: 'mmdb', icon: SurgeIcons.map),
  GeoItem(label: 'ASN', fileName: ASN, key: 'asn', icon: SurgeIcons.hub),
];

class ResourcesView extends ConsumerStatefulWidget {
  const ResourcesView({super.key});

  @override
  ConsumerState<ResourcesView> createState() => _ResourcesViewState();
}

class _ResourcesViewState extends ConsumerState<ResourcesView> {
  final _updatingItems = ValueNotifier<Set<String>>({});
  var _autoUpdateMode = _ResourceAutoUpdateMode.everySevenDays;
  var _autoChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _migrateGeoXUrls());
    _loadAutoUpdateMode();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _runAutoUpdateIfNeeded(),
    );
  }

  @override
  void dispose() {
    _updatingItems.dispose();
    super.dispose();
  }

  Future<void> _loadAutoUpdateMode() async {
    final modeName = await preferences.getString(_resourceAutoUpdateModeKey);
    if (!mounted) return;
    setState(() {
      _autoUpdateMode = _ResourceAutoUpdateMode.fromName(modeName);
    });
  }

  Future<void> _setAutoUpdateMode(_ResourceAutoUpdateMode mode) async {
    await preferences.setString(_resourceAutoUpdateModeKey, mode.name);
    if (!mounted) return;
    setState(() {
      _autoUpdateMode = mode;
    });
  }

  void _migrateGeoXUrls() {
    if (!mounted) return;
    final config = ref.read(patchClashConfigProvider);
    final map = Map<String, Object?>.from(config.geoXUrl.toJson());
    var changed = false;
    for (final entry in _oldDefaultGeoXUrls.entries) {
      if (map[entry.key] == entry.value) {
        map[entry.key] = _newDefaultGeoXUrls[entry.key];
        changed = true;
      }
    }
    if (!changed) return;
    ref.read(patchClashConfigProvider.notifier).update((state) {
      return state.copyWith(geoXUrl: GeoXUrl.fromJson(map));
    });
  }

  bool _shouldRunAutoUpdate(int? lastRun) {
    if (_autoUpdateMode == _ResourceAutoUpdateMode.off) return false;
    if (lastRun == null || lastRun <= 0) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastRun);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    return today.difference(lastDay).inDays >= _autoUpdateMode.intervalDays;
  }

  Future<void> _runAutoUpdateIfNeeded() async {
    if (_autoChecked) return;
    _autoChecked = true;
    final modeName = await preferences.getString(_resourceAutoUpdateModeKey);
    final mode = _ResourceAutoUpdateMode.fromName(modeName);
    final lastRun = await preferences.getInt(_resourceAutoUpdateLastRunKey);
    if (!mounted || mode == _ResourceAutoUpdateMode.off) return;
    setState(() {
      _autoUpdateMode = mode;
    });
    if (!_shouldRunAutoUpdate(lastRun)) return;
    await _handleUpdateAll(silence: true);
    await preferences.setInt(
      _resourceAutoUpdateLastRunKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _updateItem(GeoItem item) async {
    _updatingItems.value = {..._updatingItems.value, item.key};
    try {
      final message = await coreController.updateGeoData(
        UpdateGeoDataParams(geoName: item.fileName, geoType: item.label),
      );
      if (message.isNotEmpty) throw message;
    } finally {
      final next = Set<String>.from(_updatingItems.value)..remove(item.key);
      _updatingItems.value = next;
    }
  }

  Future<void> _handleUpdateItem(GeoItem item) async {
    await globalState.safeRun<void>(() async {
      await _updateItem(item);
    }, silence: false);
    if (mounted) setState(() {});
  }

  Future<void> _handleUpdateAll({bool silence = false}) async {
    if (_updatingItems.value.isNotEmpty) return;
    await globalState.safeRun<void>(() async {
      for (final item in _geoItems) {
        await _updateItem(item);
      }
    }, silence: silence);
    if (mounted) setState(() {});
  }

  void _showAutoUpdateSheet() {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return AdaptiveSheetScaffold(
          title: '资源自动更新',
          body: _ResourceAutoUpdateSheet(
            value: _autoUpdateMode,
            onChanged: (mode) async {
              await _setAutoUpdateMode(mode);
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildActions() {
    return [
      IconButton(
        onPressed: () => _handleUpdateAll(),
        icon: const Icon(SurgeIcons.sync),
      ),
      IconButton(
        onPressed: _showAutoUpdateSheet,
        icon: const Icon(SurgeIcons.schedule),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return CommonScaffold(
      title: context.appLocalizations.resources,
      backgroundColor: surge.background,
      actions: _buildActions(),
      body: ValueListenableBuilder(
        valueListenable: _updatingItems,
        builder: (_, updatingItems, _) {
          return ListView(
            padding: EdgeInsets.only(
              top: 4,
              bottom: SurgeBottomNavLayout.mainPageBottomPadding(context),
            ),
            children: [
              _ResourceStatusCard(mode: _autoUpdateMode),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                child: _ResourceListSurface(
                  child: Column(
                    children: [
                      for (var index = 0; index < _geoItems.length; index++)
                        _ResourceItemCard(
                          item: _geoItems[index],
                          updating: updatingItems.contains(
                            _geoItems[index].key,
                          ),
                          showDivider: index != _geoItems.length - 1,
                          onUpdate: () => _handleUpdateItem(_geoItems[index]),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResourceStatusCard extends StatelessWidget {
  const _ResourceStatusCard({required this.mode});

  final _ResourceAutoUpdateMode mode;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SurgeCard(
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: surge.textSecondary.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                mode == _ResourceAutoUpdateMode.off
                    ? SurgeIcons.pause
                    : SurgeIcons.update,
                size: 15,
                color: surge.textPrimary.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode.statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: surge.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  if (mode != _ResourceAutoUpdateMode.off) ...[
                    const SizedBox(height: 4),
                    Text(
                      mode.subtitle,
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
          ],
        ),
      ),
    );
  }
}

class _ResourceListSurface extends StatelessWidget {
  const _ResourceListSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SurgeCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      shadow: false,
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }
}

class _ResourceItemCard extends ConsumerWidget {
  const _ResourceItemCard({
    required this.item,
    required this.updating,
    required this.showDivider,
    required this.onUpdate,
  });

  final GeoItem item;
  final bool updating;
  final bool showDivider;
  final VoidCallback onUpdate;

  Future<void> _updateUrl(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final defaultMap = defaultGeoXUrl.toJson();
    final newUrl = await globalState.showCommonDialog<String>(
      child: UpdateGeoUrlFormDialog(
        title: item.label,
        url: url,
        defaultValue: defaultMap[item.key],
      ),
    );
    if (newUrl != null && newUrl != url) {
      try {
        if (!newUrl.isUrl) throw 'Invalid url';
        ref.read(patchClashConfigProvider.notifier).update((state) {
          final map = state.geoXUrl.toJson();
          map[item.key] = newUrl;
          return state.copyWith(geoXUrl: GeoXUrl.fromJson(map));
        });
      } catch (e) {
        globalState.showMessage(
          title: item.label,
          message: TextSpan(text: e.toString()),
        );
      }
    }
  }

  Future<FileInfo> _getGeoFileLastModified(String fileName) async {
    final homePath = await appPath.homeDirPath;
    final file = File(join(homePath, fileName));
    final lastModified = await file.lastModified();
    final size = await file.length();
    return FileInfo(size: size, lastModified: lastModified);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surge = SurgeTheme.of(context);
    final url = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.geoXUrl.toJson()[item.key],
      ),
    );
    if (url == null) return const SizedBox();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: surge.textSecondary.withValues(alpha: 0.055),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: surge.separator.withValues(alpha: 0.38),
                      width: surge.spacing.hairline,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    size: 17,
                    color: surge.textPrimary.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: surge.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<FileInfo>(
                        future: _getGeoFileLastModified(item.fileName),
                        builder: (_, snapshot) {
                          final text = snapshot.data?.getDesc(context) ?? '读取中';
                          return Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: surge.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: surge.textSecondary.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SoftOsControlDock(
                  height: 34,
                  tapHeight: 44,
                  children: [
                    SoftOsDockButton(
                      tooltip: context.appLocalizations.edit,
                      icon: SurgeIcons.edit,
                      onTap: () => _updateUrl(context, ref, url),
                    ),
                    const SoftOsDockDivider(height: 15),
                    SoftOsDockButton(
                      tooltip: context.appLocalizations.sync,
                      icon: SurgeIcons.sync,
                      loading: updating,
                      onTap: onUpdate,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: Divider(
              height: 0,
              thickness: surge.spacing.hairline,
              color: surge.separator.withValues(alpha: 0.56),
            ),
          ),
      ],
    );
  }
}

class _ResourceAutoUpdateSheet extends StatefulWidget {
  const _ResourceAutoUpdateSheet({
    required this.value,
    required this.onChanged,
  });

  final _ResourceAutoUpdateMode value;
  final ValueChanged<_ResourceAutoUpdateMode> onChanged;

  @override
  State<_ResourceAutoUpdateSheet> createState() =>
      _ResourceAutoUpdateSheetState();
}

class _ResourceAutoUpdateSheetState extends State<_ResourceAutoUpdateSheet> {
  late var _value = widget.value;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
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
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              '更新频率',
              style: context.textTheme.titleSmall?.copyWith(
                color: surge.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            '首次打开资源页时触发',
            style: context.textTheme.labelSmall?.copyWith(
              color: surge.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          SurgeCard(
            padding: EdgeInsets.zero,
            borderRadius: 18,
            shadow: true,
            child: Column(
              children: [
                for (final mode in _ResourceAutoUpdateMode.values)
                  _ResourceSheetOption(
                    icon: mode == _ResourceAutoUpdateMode.off
                        ? SurgeIcons.pause
                        : SurgeIcons.update,
                    title: mode.title,
                    subtitle: mode.subtitle,
                    selected: mode == _value,
                    onTap: () {
                      setState(() {
                        _value = mode;
                      });
                      widget.onChanged(mode);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceSheetOption extends StatelessWidget {
  const _ResourceSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final foreground = selected ? surge.textPrimary : surge.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? surge.primary.withValues(alpha: 0.1)
                      : surge.textSecondary.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: surge.separator.withValues(alpha: 0.38),
                    width: surge.spacing.hairline,
                  ),
                ),
                child: Icon(icon, size: 15, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: surge.textPrimary,
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: surge.textSecondary,
                        fontSize: 11,
                        height: 1.1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SurgeSelectIndicator(
                selected: selected,
                size: 18,
                iconSize: 12,
                showCheck: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateGeoUrlFormDialog extends StatefulWidget {
  final String title;
  final String url;
  final String? defaultValue;

  const UpdateGeoUrlFormDialog({
    super.key,
    required this.title,
    required this.url,
    this.defaultValue,
  });

  @override
  State<UpdateGeoUrlFormDialog> createState() => _UpdateGeoUrlFormDialogState();
}

class _UpdateGeoUrlFormDialogState extends State<UpdateGeoUrlFormDialog> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.url);
  }

  Future<void> _handleUpdate() async {
    final url = _urlController.value.text;
    if (url.isEmpty) return;
    Navigator.of(context).pop<String>(url);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          SurgeField(
            label: appLocalizations.url,
            child: TextField(
              maxLines: 5,
              minLines: 1,
              keyboardType: TextInputType.url,
              controller: _urlController,
              decoration: surgeInputDecoration(
                context,
                hintText: appLocalizations.url,
              ),
            ),
          ),
          SurgeDialogActionRow(
            cancelLabel: appLocalizations.cancel,
            submitLabel: appLocalizations.submit,
            onCancel: () {
              Navigator.of(context).pop();
            },
            onSubmit: _handleUpdate,
          ),
        ],
      ),
    );
  }
}
