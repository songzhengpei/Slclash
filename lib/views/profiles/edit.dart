import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class EditProfileView extends StatefulWidget {
  final Profile profile;
  final BuildContext context;

  const EditProfileView({
    super.key,
    required this.context,
    required this.profile,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  late final TextEditingController _autoUpdateDurationController;
  late bool _autoUpdate;
  String? _rawText;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _fileInfoNotifier = ValueNotifier<FileInfo?>(null);
  Uint8List? _fileData;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.profile.label);
    _urlController = TextEditingController(text: widget.profile.url);
    _autoUpdate = widget.profile.autoUpdate;
    _autoUpdateDurationController = TextEditingController(
      text: widget.profile.autoUpdateDuration.inMinutes.toString(),
    );
    _updateFileInfo();
  }

  Future<void> _updateFileInfo() async {
    final file = await widget.profile.file;
    if (!await file.exists()) {
      return;
    }
    final lastModified = await file.lastModified();
    final size = await file.length();
    if (!mounted) {
      return;
    }
    _fileInfoNotifier.value = FileInfo(size: size, lastModified: lastModified);
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    var profile = widget.profile.copyWith(
      url: _urlController.text,
      label: _labelController.text,
      autoUpdate: _autoUpdate,
      autoUpdateDuration: Duration(
        minutes: int.parse(_autoUpdateDurationController.text),
      ),
    );
    final profilesAction = globalState.container.read(
      profilesActionProvider.notifier,
    );
    final hasUpdate = widget.profile.url != profile.url;
    if (_fileData != null) {
      if (profile.type == ProfileType.url && _autoUpdate) {
        final appLocalizations = context.appLocalizations;
        final res = await globalState.showMessage(
          title: appLocalizations.tip,
          message: TextSpan(text: appLocalizations.profileHasUpdate),
        );
        if (res == true) {
          profile = profile.copyWith(autoUpdate: false);
        }
      }
      profilesAction.putProfile(await profile.saveFile(_fileData!));
    } else if (!hasUpdate) {
      profilesAction.putProfile(profile);
    } else {
      globalState.safeRun(() async {
        await Future.delayed(commonDuration);
        if (hasUpdate) {
          await profilesAction.updateProfile(profile);
        }
      });
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _setAutoUpdate(bool value) {
    if (_autoUpdate == value) return;
    setState(() {
      _autoUpdate = value;
    });
  }

  Future<void> _handleSaveEdit(BuildContext context, String data) async {
    final message = await globalState.safeRun<String>(() async {
      final message = await coreController.validateConfigWithData(data);
      return message;
    }, silence: false);
    if (message?.isNotEmpty == true) {
      globalState.showMessage(
        title: currentAppLocalizations.tip,
        message: TextSpan(text: message),
      );
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop(data);
    }
  }

  Future<void> _editProfileFile() async {
    if (_rawText == null) {
      final profilePath = await appPath.getProfilePath(
        widget.profile.id.toString(),
      );
      final file = File(profilePath);
      if (await file.exists()) {
        _rawText = await file.readAsString();
      }
    }
    if (!mounted) return;
    final title = widget.profile.label.takeFirstValid([
      widget.profile.id.toString(),
    ]);
    final editorPage = EditorPage(
      title: title,
      content: _rawText!,
      onSave: (context, _, content) {
        _handleSaveEdit(context, content);
      },
      onPop: (context, _, content) async {
        if (content == _rawText) {
          return true;
        }
        final res = await globalState.showMessage(
          title: title,
          message: TextSpan(text: context.appLocalizations.hasCacheChange),
        );
        if (res == true && context.mounted) {
          _handleSaveEdit(context, content);
        } else {
          return true;
        }
        return false;
      },
    );
    final data = await BaseNavigator.push<String>(context, editorPage);
    if (data == null) {
      return;
    }
    _rawText = data;
    _fileData = Uint8List.fromList(utf8.encode(data));
    _fileInfoNotifier.value = _fileInfoNotifier.value?.copyWith(
      size: _fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _uploadProfileFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile?.bytes == null) return;
    _fileData = platformFile?.bytes;
    if (!mounted) {
      return;
    }
    _fileInfoNotifier.value = _fileInfoNotifier.value?.copyWith(
      size: _fileData?.length ?? 0,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _handleBack() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.fileIsUpdate),
    );
    if (res == true) {
      _handleConfirm();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _fileInfoNotifier.dispose();
    _autoUpdateDurationController.dispose();
    super.dispose();
    globalState.container.read(setupActionProvider.notifier).autoApplyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonPopScope(
      onPop: (context) {
        if (_fileData == null) {
          return true;
        }
        _handleBack();
        return false;
      },
      child: AdaptiveSheetScaffold(
        title: appLocalizations.edit,
        backAction: () {
          if (_fileData == null) {
            Navigator.of(context).pop();
            return;
          }
          _handleBack();
        },
        actions: [
          IconButtonData(icon: Icons.check_rounded, onPressed: _handleConfirm),
        ],
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _ProfileEditField(
                label: appLocalizations.name,
                child: TextFormField(
                  textInputAction: TextInputAction.next,
                  controller: _labelController,
                  decoration: surgeInputDecoration(
                    context,
                    hintText: appLocalizations.name,
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.profileNameNullValidationDesc;
                    }
                    return null;
                  },
                ),
              ),
              if (widget.profile.type == ProfileType.url) ...[
                const SizedBox(height: 14),
                _ProfileEditField(
                  label: appLocalizations.url,
                  child: TextFormField(
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.url,
                    controller: _urlController,
                    maxLines: 4,
                    minLines: 1,
                    decoration: surgeInputDecoration(
                      context,
                      hintText: appLocalizations.url,
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return appLocalizations.profileUrlNullValidationDesc;
                      }
                      if (!value.isUrl) {
                        return appLocalizations.profileUrlInvalidValidationDesc;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileEditSwitchRow(
                  label: appLocalizations.autoUpdate,
                  value: _autoUpdate,
                  onChanged: _setAutoUpdate,
                ),
                if (_autoUpdate) ...[
                  const SizedBox(height: 14),
                  _ProfileEditField(
                    label: appLocalizations.autoUpdateInterval,
                    child: TextFormField(
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                      controller: _autoUpdateDurationController,
                      decoration: surgeInputDecoration(
                        context,
                        hintText: appLocalizations.autoUpdateInterval,
                      ),
                      validator: (String? value) {
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
                ],
              ],
              const SizedBox(height: 18),
              ValueListenableBuilder<FileInfo?>(
                valueListenable: _fileInfoNotifier,
                builder: (_, fileInfo, _) {
                  return FadeThroughBox(
                    alignment: Alignment.centerLeft,
                    child: fileInfo == null
                        ? const SizedBox.shrink()
                        : _ProfileEditFileActions(
                            description: fileInfo.getDesc(context),
                            onEdit: _editProfileFile,
                            onUpload: _uploadProfileFile,
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEditField extends StatelessWidget {
  const _ProfileEditField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? surge.textSecondary
        : Color.lerp(surge.textSecondary, surge.textPrimary, 0.22)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ProfileEditSwitchRow extends StatelessWidget {
  const _ProfileEditSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(surge.radii.card);
    final border = Border.all(
      color: isDark
          ? surge.separator.withValues(alpha: 0.36)
          : surge.separator.withValues(alpha: 0.82),
      width: 0.7,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onChanged(!value);
        },
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: surge.fill,
            borderRadius: radius,
            border: border,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
              SurgeSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEditFileActions extends StatelessWidget {
  const _ProfileEditFileActions({
    required this.description,
    required this.onEdit,
    required this.onUpload,
  });

  final String description;
  final VoidCallback onEdit;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final appLocalizations = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelSmall?.copyWith(
              color: surge.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ProfileEditActionButton(
                icon: Icons.edit_rounded,
                label: appLocalizations.edit,
                onPressed: onEdit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileEditActionButton(
                icon: Icons.upload_rounded,
                label: appLocalizations.upload,
                onPressed: onUpload,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileEditActionButton extends StatelessWidget {
  const _ProfileEditActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: surge.fill,
          foregroundColor: surge.textPrimary,
          textStyle: context.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surge.radii.smallCard),
          ),
        ),
      ),
    );
  }
}
