import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/services/backup/backup_file_guard.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/fade_box.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BackupAndRestore extends ConsumerStatefulWidget {
  const BackupAndRestore({super.key});

  @override
  ConsumerState<BackupAndRestore> createState() => _BackupAndRestoreState();
}

class _BackupAndRestoreState extends ConsumerState<BackupAndRestore>
    with UniqueKeyStateMixin {
  final _isCompleter = ValueNotifier<bool?>(null);
  DAVProps? _lastProps;
  DAVClient? _client;

  Future<void> _updateDAVClient(DAVProps? props) async {
    _client = props == null ? null : DAVClient(props);
    final rawProps = props?.copyWith(fileName: '');
    final rawLastProps = _lastProps?.copyWith(fileName: '');
    _lastProps = props;
    if (rawProps == rawLastProps) {
      return;
    } else {
      _isCompleter.value == null;
      final res = await _client?.ping() ?? false;
      if (mounted) {
        _isCompleter.value = res;
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _showAddWebDAV(DAVProps? dav) async {
    await globalState.showCommonDialog<String>(
      child: WebDAVFormDialog(dav: dav?.copyWith()),
    );
  }

  Future<bool> _showBackupConfirmation({
    required String title,
    required String message,
    String? confirmLabel,
  }) async {
    return await globalState.showCommonDialog<bool>(
          child: _SoftOsBackupDialog(
            title: title,
            message: message,
            actions: [
              _SoftOsDialogAction(
                label: context.appLocalizations.cancel,
                onPressed: () => Navigator.pop(context, false),
              ),
              _SoftOsDialogAction(
                label: confirmLabel ?? context.appLocalizations.confirm,
                primary: true,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showBackupInfo({
    required String title,
    required String message,
  }) => globalState.showCommonDialog<void>(
    child: _SoftOsBackupDialog(
      title: title,
      message: message,
      actions: [
        _SoftOsDialogAction(
          label: context.appLocalizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        _SoftOsDialogAction(
          label: context.appLocalizations.confirm,
          primary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );

  Future<void> _backupOnWebDAV() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.loadingRun<bool>(
      () async {
        final path = await globalState.container
            .read(backupActionProvider.notifier)
            .backup();
        if (path.isEmpty) {
          return false;
        }
        return _client!.backup(path);
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.backup,
    );
    if (res != true) return;
    _showBackupInfo(
      title: appLocalizations.backup,
      message: appLocalizations.backupSuccess,
    );
  }

  Future<void> _restoreOnWebDAV() async {
    final appLocalizations = context.appLocalizations;
    if (_client == null) return;

    final files = await globalState.loadingRun<List<DAVFileEntry>>(
      () => _client!.listFiles(),
      tag: LoadingTag.backup_restore,
      title: '正在读取备份...',
    );
    if (files == null || files.isEmpty) {
      _showBackupInfo(title: appLocalizations.restore, message: '没有可用备份。');
      return;
    }

    final selected = await globalState.showCommonDialog<String>(
      child: _CenteredWebDAVFileList(files: files),
    );
    if (selected == null || !context.mounted) return;

    final confirmed = await _showBackupConfirmation(
      title: appLocalizations.restore,
      message: '请注意，只会恢复订阅数据，不会恢复其他设置。',
      confirmLabel: appLocalizations.restore,
    );
    if (confirmed != true || !context.mounted) return;

    final outcome = await globalState.loadingRun<BackupRestoreOutcome>(
      () async {
        await _client!.restoreFile(selected);
        return globalState.container
            .read(backupActionProvider.notifier)
            .restore();
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (outcome != null) _showRestoreOutcome(outcome);
  }

  Future<void> _backupOnLocal() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.loadingRun<bool>(
      () async {
        final path = await globalState.container
            .read(backupActionProvider.notifier)
            .backup();
        if (path.isEmpty) {
          return false;
        }
        final value = await picker.saveFileWithPath(
          utils.getBackupFileName(),
          path,
        );
        if (value == null) return false;
        return true;
      },
      title: appLocalizations.backup,
      tag: LoadingTag.backup_restore,
    );
    if (res != true) return;
    _showBackupInfo(
      title: appLocalizations.backup,
      message: appLocalizations.backupSuccess,
    );
  }

  Future<void> _restoreOnLocal() async {
    final appLocalizations = context.appLocalizations;
    final file = await picker.pickerFile(withData: false);
    final path = file?.path;
    if (path == null) return;
    final confirmed = await _showBackupConfirmation(
      title: appLocalizations.restore,
      message: '请注意，只会恢复订阅数据，不会恢复其他设置。',
      confirmLabel: appLocalizations.restore,
    );
    if (confirmed != true || !mounted) return;
    final outcome = await globalState.loadingRun<BackupRestoreOutcome>(
      () async {
        await validateBackupArchiveFile(File(path));
        await File(path).safeCopy(await appPath.backupFilePath);
        return globalState.container
            .read(backupActionProvider.notifier)
            .restore();
      },
      tag: LoadingTag.backup_restore,
      title: appLocalizations.restore,
    );
    if (outcome != null) _showRestoreOutcome(outcome);
  }

  void _showRestoreOutcome(BackupRestoreOutcome outcome) {
    final appLocalizations = context.appLocalizations;
    final message = outcome.activationSucceeded
        ? '订阅数据已恢复。'
        : '订阅数据已恢复，代理暂未加载。';
    _showBackupInfo(title: appLocalizations.restore, message: message);
  }

  void _handleChange(String? value, WidgetRef ref) {
    if (value == null) {
      return;
    }
    ref
        .read(davSettingProvider.notifier)
        .update((state) => state?.copyWith(fileName: value));
  }

  Future<void> _handleUpdateRestoreStrategy() async {
    final restoreStrategy = ref.read(
      appSettingProvider.select((state) => state.restoreStrategy),
    );
    final res = await globalState.showCommonDialog(
      child: _SoftOsRestoreStrategyDialog(value: restoreStrategy),
    );
    if (res == null) {
      return;
    }
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(restoreStrategy: res));
  }

  Future<void> _handleFactoryReset() async {
    final res = await _showBackupConfirmation(
      title: context.appLocalizations.factoryReset,
      message: context.appLocalizations.confirmFactoryReset,
      confirmLabel: context.appLocalizations.factoryReset,
    );
    if (res != true) {
      return;
    }
    await globalState.container
        .read(storeActionProvider.notifier)
        .handleClear();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final dav = ref.watch(davSettingProvider);
    final isLoading = ref.watch(loadingProvider(LoadingTag.backup_restore));
    _updateDAVClient(dav);
    return CommonScaffold(
      isLoading: isLoading,
      title: appLocalizations.backupAndRestore,
      appBarActions: const [],
      body: ListView(
        padding: EdgeInsets.only(
          top: 12,
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SurgeSection(
            title: appLocalizations.remote,
            showDividers: true,
            children: [
              if (dav == null)
                ListItem(
                  leading: const Icon(SurgeIcons.accountBox),
                  title: Text(appLocalizations.noInfo),
                  subtitle: Text(appLocalizations.pleaseBindWebDAV),
                  trailing: _BackupPillButton(
                    label: appLocalizations.bind,
                    onPressed: () {
                      _showAddWebDAV(dav);
                    },
                  ),
                )
              else ...[
                ListItem(
                  leading: const Icon(SurgeIcons.accountBox),
                  title: TooltipText(
                    text: Text(
                      dav.user,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(appLocalizations.connectivity),
                        const SizedBox(width: 8),
                        ValueListenableBuilder(
                          valueListenable: _isCompleter,
                          builder: (_, isCompleter, _) {
                            return Center(
                              child: FadeThroughBox(
                                child: isCompleter == null
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1,
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: !isCompleter
                                              ? context.colorScheme.error
                                              : Colors.green.harmonizeWith(
                                                  context.colorScheme.primary,
                                                ),
                                        ),
                                        width: 12,
                                        height: 12,
                                      ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  trailing: _BackupPillButton(
                    label: appLocalizations.edit,
                    onPressed: () {
                      _showAddWebDAV(dav);
                    },
                  ),
                ),
                ListItem.input(
                  title: Text(appLocalizations.file),
                  subtitle: Text(dav.fileName),
                  delegate: InputDelegate(
                    title: appLocalizations.file,
                    value: dav.fileName,
                    resetValue: defaultDavFileName,
                    onChanged: (value) {
                      _handleChange(value, ref);
                    },
                  ),
                ),
                ListItem(
                  onTap: () {
                    _backupOnWebDAV();
                  },
                  title: Text(appLocalizations.backup),
                  subtitle: Text(appLocalizations.remoteBackupDesc),
                ),
                ListItem(
                  onTap: () {
                    _restoreOnWebDAV();
                  },
                  title: Text(appLocalizations.restore),
                  subtitle: Text(appLocalizations.restoreFromWebDAVDesc),
                ),
              ],
            ],
          ),
          SurgeSection(
            title: appLocalizations.local,
            showDividers: true,
            children: [
              ListItem(
                onTap: () {
                  _backupOnLocal();
                },
                title: Text(appLocalizations.backup),
                subtitle: Text(appLocalizations.localBackupDesc),
              ),
              ListItem(
                onTap: () {
                  _restoreOnLocal();
                },
                title: Text(appLocalizations.restore),
                subtitle: Text(appLocalizations.restoreFromFileDesc),
              ),
            ],
          ),
          SurgeSection(
            title: appLocalizations.options,
            showDividers: true,
            children: [
              Consumer(
                builder: (_, ref, _) {
                  final restoreStrategy = ref.watch(
                    appSettingProvider.select((state) => state.restoreStrategy),
                  );
                  return ListItem(
                    onTap: () {
                      _handleUpdateRestoreStrategy();
                    },
                    title: Text(appLocalizations.restoreStrategy),
                    trailing: _BackupPillButton(
                      label: Intl.message(
                        'restoreStrategy_${restoreStrategy.name}',
                      ),
                      onPressed: _handleUpdateRestoreStrategy,
                    ),
                  );
                },
              ),
              ListItem(
                onTap: _handleFactoryReset,
                title: Text(appLocalizations.factoryReset),
                subtitle: Text(appLocalizations.factoryResetDesc),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebDAVFileList extends StatelessWidget {
  const _WebDAVFileList({
    required this.files,
    required this.selected,
    required this.onSelected,
  });

  final List<DAVFileEntry> files;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _WebDAVFileItem(
        entry: files[index],
        selected: selected == files[index].name,
        onTap: () => onSelected(files[index].name),
      ),
    );
  }
}

class _CenteredWebDAVFileList extends StatefulWidget {
  const _CenteredWebDAVFileList({required this.files});

  final List<DAVFileEntry> files;

  @override
  State<_CenteredWebDAVFileList> createState() =>
      _CenteredWebDAVFileListState();
}

class _CenteredWebDAVFileListState extends State<_CenteredWebDAVFileList> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return _SoftOsBackupDialog(
      title: '选择备份',
      maxContentHeight: 350,
      childScrolls: true,
      actions: [
        _SoftOsDialogAction(
          label: context.appLocalizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        _SoftOsDialogAction(
          label: context.appLocalizations.restore,
          primary: true,
          onPressed: selected == null
              ? null
              : () => Navigator.pop(context, selected),
        ),
      ],
      child: _WebDAVFileList(
        files: widget.files,
        selected: selected,
        onSelected: (value) => setState(() => selected = value),
      ),
    );
  }
}

class _WebDAVFileItem extends StatelessWidget {
  const _WebDAVFileItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final DAVFileEntry entry;
  final bool selected;
  final VoidCallback onTap;

  String _clientLabel(String name) {
    if (name.contains('android')) return 'Android';
    if (name.contains('windows')) return 'Windows';
    return 'Worker';
  }

  Color _clientColor(String name, SurgeTheme surge) {
    if (name.contains('android')) return surge.green;
    if (name.contains('windows')) return surge.primary;
    return surge.purple;
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final label = _clientLabel(entry.name);
    final color = _clientColor(entry.name, surge);
    final dateStr = DateFormat('MM-dd HH:mm').format(entry.lastModified);
    final sizeStr = entry.size > 1024 * 1024
        ? '${(entry.size / 1024 / 1024).toStringAsFixed(1)}MB'
        : '${(entry.size / 1024).toStringAsFixed(0)}KB';

    return SurgePressable(
      onTap: onTap,
      semanticLabel: '恢复 ${entry.name}',
      borderRadius: BorderRadius.circular(surge.radii.list),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: selected
              ? surge.primary.withValues(alpha: 0.10)
              : surge.fill.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(surge.radii.list),
          border: Border.all(
            color: selected
                ? surge.primary.withValues(alpha: 0.28)
                : surge.separator,
            width: surge.spacing.hairline,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.rowTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr  ·  $sizeStr',
                      style: context.typography.supporting,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(surge.radii.button),
                  border: Border.all(
                    color: color.withValues(alpha: 0.20),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: context.typography.badgeLabel.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                selected ? SurgeIcons.confirm : SurgeIcons.chevronRight,
                size: SurgeIconSize.compact,
                color: selected ? surge.primary : surge.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupPillButton extends StatelessWidget {
  const _BackupPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: surge.textPrimary,
        backgroundColor: surge.textSecondary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surge.radii.button),
        ),
      ),
      child: Text(
        label,
        style: context.typography.badgeLabel.copyWith(color: surge.textPrimary),
      ),
    );
  }
}

class WebDAVFormDialog extends ConsumerStatefulWidget {
  final DAVProps? dav;

  const WebDAVFormDialog({super.key, this.dav});

  @override
  ConsumerState<WebDAVFormDialog> createState() => _WebDAVFormDialogState();
}

class _WebDAVFormDialogState extends ConsumerState<WebDAVFormDialog> {
  late TextEditingController _uriController;
  late TextEditingController _userController;
  late TextEditingController _passwordController;
  final _obscureController = ValueNotifier<bool>(true);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController(text: widget.dav?.uri);
    _userController = TextEditingController(text: widget.dav?.user);
    _passwordController = TextEditingController(text: widget.dav?.password);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(davSettingProvider.notifier).value = DAVProps(
      uri: _uriController.text,
      user: _userController.text,
      password: _passwordController.text,
    );
    Navigator.pop(context);
  }

  void _delete() {
    ref.read(davSettingProvider.notifier).value = null;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _obscureController.dispose();
    _uriController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return _SoftOsBackupDialog(
      title: appLocalizations.webDAVConfiguration,
      actions: [
        _SoftOsDialogAction(
          label: widget.dav == null
              ? appLocalizations.cancel
              : appLocalizations.delete,
          destructive: widget.dav != null,
          onPressed: widget.dav == null
              ? () => Navigator.pop(context)
              : _delete,
        ),
        _SoftOsDialogAction(
          label: appLocalizations.save,
          primary: true,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            TextFormField(
              controller: _uriController,
              maxLines: 5,
              minLines: 1,
              keyboardType: TextInputType.url,
              decoration: surgeInputDecoration(
                context,
                hintText: appLocalizations.address,
                prefixIcon: const Icon(SurgeIcons.link),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty || !value.isUrl) {
                  return appLocalizations.addressTip;
                }
                return null;
              },
            ),
            TextFormField(
              controller: _userController,
              decoration: surgeInputDecoration(
                context,
                hintText: appLocalizations.account,
                prefixIcon: const Icon(SurgeIcons.account),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return appLocalizations.emptyTip(appLocalizations.account);
                }
                return null;
              },
            ),
            ValueListenableBuilder(
              valueListenable: _obscureController,
              builder: (_, obscure, _) {
                return TextFormField(
                  controller: _passwordController,
                  obscureText: obscure,
                  decoration: surgeInputDecoration(
                    context,
                    hintText: appLocalizations.password,
                    prefixIcon: const Icon(SurgeIcons.password),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? SurgeIcons.visibility
                            : SurgeIcons.visibilityOff,
                      ),
                      onPressed: () {
                        _obscureController.value = !obscure;
                      },
                    ),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.emptyTip(
                        appLocalizations.password,
                      );
                    }
                    return null;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftOsBackupDialog extends StatelessWidget {
  const _SoftOsBackupDialog({
    required this.title,
    required this.actions,
    this.message,
    this.child,
    this.maxContentHeight = 500,
    this.childScrolls = false,
  });

  final String title;
  final String? message;
  final Widget? child;
  final List<Widget> actions;
  final double maxContentHeight;
  final bool childScrolls;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return CommonDialog(
      title: title,
      overrideScroll: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null && message!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: child == null ? 0 : 18),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surge.fill.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(surge.radii.card),
                  border: Border.all(
                    color: surge.separator,
                    width: surge.spacing.hairline,
                  ),
                ),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.typography.supporting.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
              ),
            ),
          if (child != null)
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxContentHeight),
                child: childScrolls
                    ? child
                    : SingleChildScrollView(child: child),
              ),
            ),
          const SizedBox(height: 20),
          if (actions.length == 2)
            Row(
              children: [
                Expanded(child: actions.first),
                const SizedBox(width: 14),
                Expanded(child: actions.last),
              ],
            )
          else
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
        ],
      ),
    );
  }
}

class _SoftOsDialogAction extends StatelessWidget {
  const _SoftOsDialogAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final enabled = onPressed != null;
    final background = destructive
        ? surge.red.withValues(alpha: 0.10)
        : primary
        ? enabled
              ? surge.primary
              : surge.primary.withValues(alpha: 0.14)
        : surge.fill;
    final foreground = destructive
        ? surge.red
        : primary
        ? enabled
              ? surge.onPrimary
              : surge.textSecondary.withValues(alpha: 0.72)
        : surge.textPrimary;
    return Semantics(
      button: true,
      label: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(45),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: foreground,
          backgroundColor: background,
          disabledForegroundColor: foreground,
          disabledBackgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surge.radii.button),
            side: primary
                ? BorderSide.none
                : BorderSide(
                    color: destructive
                        ? surge.red.withValues(alpha: 0.18)
                        : surge.separator,
                    width: surge.spacing.hairline,
                  ),
          ),
          textStyle: context.typography.controlLabel,
        ),
        child: Text(label),
      ),
    );
  }
}

class _SoftOsRestoreStrategyDialog extends StatefulWidget {
  const _SoftOsRestoreStrategyDialog({required this.value});

  final RestoreStrategy value;

  @override
  State<_SoftOsRestoreStrategyDialog> createState() =>
      _SoftOsRestoreStrategyDialogState();
}

class _SoftOsRestoreStrategyDialogState
    extends State<_SoftOsRestoreStrategyDialog> {
  late RestoreStrategy selected = widget.value;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return _SoftOsBackupDialog(
      title: currentAppLocalizations.restoreStrategy,
      message: '选择恢复方式。',
      actions: [
        _SoftOsDialogAction(
          label: context.appLocalizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        _SoftOsDialogAction(
          label: context.appLocalizations.submit,
          primary: true,
          onPressed: () => Navigator.pop(context, selected),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final strategy in RestoreStrategy.values) ...[
            SurgePressable(
              onTap: () => setState(() => selected = strategy),
              semanticLabel: Intl.message('restoreStrategy_${strategy.name}'),
              borderRadius: BorderRadius.circular(surge.radii.list),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: strategy == selected
                      ? surge.primary.withValues(alpha: 0.10)
                      : surge.fill.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(surge.radii.list),
                  border: Border.all(
                    color: strategy == selected
                        ? surge.primary.withValues(alpha: 0.24)
                        : surge.separator,
                    width: surge.spacing.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        Intl.message('restoreStrategy_${strategy.name}'),
                        style: context.typography.rowTitle,
                      ),
                    ),
                    if (strategy == selected)
                      Icon(
                        SurgeIcons.confirm,
                        color: surge.primary,
                        size: SurgeIconSize.regular,
                      ),
                  ],
                ),
              ),
            ),
            if (strategy != RestoreStrategy.values.last)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
