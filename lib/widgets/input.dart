import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:fl_clash/widgets/null_status.dart';
import 'package:fl_clash/widgets/pop_scope.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'effect.dart';
import 'list.dart';
import 'theme.dart';

InputDecoration surgeInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? suffixText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
  bool useFloatingLabel = false,
}) {
  final surge = SurgeTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fillColor = isDark
      ? Color.lerp(surge.fill, surge.card, 0.10)!
      : surge.fill;
  final borderSide = BorderSide(
    color: isDark
        ? surge.separator.withValues(alpha: 0.36)
        : surge.separator.withValues(alpha: 0.82),
    width: 0.7,
  );
  final radius = BorderRadius.circular(surge.radii.card);
  final border = OutlineInputBorder(
    borderRadius: radius,
    borderSide: borderSide,
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(
      color: surge.primary.withValues(alpha: 0.42),
      width: 1.2,
    ),
  );
  final errorBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(
      color: surge.red.withValues(alpha: 0.72),
      width: 1.2,
    ),
  );
  final hintStyle = context.textTheme.bodyLarge?.copyWith(
    color: surge.textSecondary.withValues(alpha: 0.68),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  return InputDecoration(
    filled: true,
    fillColor: fillColor,
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: focusedBorder,
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
    isDense: true,
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    hintText: hintText ?? (useFloatingLabel ? null : labelText),
    labelText: useFloatingLabel ? labelText : null,
    hintStyle: hintStyle,
    labelStyle: hintStyle,
    floatingLabelStyle: context.textTheme.bodySmall?.copyWith(
      color: surge.primary,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    errorStyle: context.textTheme.labelSmall?.copyWith(
      color: surge.red,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    helperText: helperText,
    helperStyle: context.textTheme.labelSmall?.copyWith(
      color: surge.textSecondary,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    prefixIcon: prefixIcon,
    prefixIconColor: surge.textSecondary,
    suffixIcon: suffixIcon,
    suffixIconColor: surge.textSecondary,
    suffixText: suffixText,
  );
}

class SurgeDialogActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  const SurgeDialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final background = primary
        ? (onPressed == null
              ? surge.primary.withValues(alpha: 0.24)
              : surge.primary)
        : surge.fill.withValues(alpha: 0.82);
    final foreground = primary
        ? surge.onPrimary.withValues(alpha: onPressed == null ? 0.62 : 1)
        : surge.textPrimary.withValues(alpha: onPressed == null ? 0.42 : 1);
    return Expanded(
      child: SizedBox(
        height: 34,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            elevation: 0,
            minimumSize: const Size.fromHeight(34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: foreground,
            textStyle: context.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(surge.radii.card),
            ),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class SurgeDialogActionRow extends StatelessWidget {
  final String cancelLabel;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSubmit;

  const SurgeDialogActionRow({
    super.key,
    required this.cancelLabel,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SurgeDialogActionButton(label: cancelLabel, onPressed: onCancel),
        const SizedBox(width: 14),
        SurgeDialogActionButton(
          label: submitLabel,
          onPressed: onSubmit,
          primary: true,
        ),
      ],
    );
  }
}

class SurgeInlineTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final int maxLines;
  final double maxWidth;

  const SurgeInlineTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.maxLines = 1,
    this.maxWidth = 240,
  });

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(surge.radii.smallCard);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: surge.primary.withValues(alpha: 0.38),
        width: 1,
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 96, maxWidth: maxWidth),
      child: SizedBox(
        height: 36,
        child: TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          textInputAction: textInputAction,
          textAlign: TextAlign.end,
          maxLines: maxLines,
          minLines: 1,
          style: context.textTheme.bodyLarge?.copyWith(
            color: surge.textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: surge.fill.withValues(alpha: 0.72),
            hoverColor: Colors.transparent,
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: focusedBorder,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            hintText: hintText,
            hintStyle: context.textTheme.bodyLarge?.copyWith(
              color: surge.textSecondary.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class OptionsDialog<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final T value;
  final String Function(T value) textBuilder;

  const OptionsDialog({
    super.key,
    required this.title,
    required this.options,
    required this.textBuilder,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: title,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: RadioGroup(
        onChanged: (value) {
          Navigator.of(context).pop(value);
        },
        groupValue: value,
        child: Wrap(
          children: [
            for (final option in options)
              Builder(
                builder: (context) {
                  if (value == option) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Scrollable.ensureVisible(context);
                    });
                  }
                  return ListItem.radio(
                    delegate: RadioDelegate(
                      value: option,
                      onTab: () {
                        Navigator.of(context).pop(option);
                      },
                    ),
                    title: Text(textBuilder(option)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class CommonCheckBox extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool isCircle;

  const CommonCheckBox({
    required this.value,
    required this.onChanged,
    this.isCircle = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      shape: isCircle ? const CircleBorder() : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class InputDialog extends StatefulWidget {
  final String title;
  final String value;
  final String? suffixText;
  final String? labelText;
  final String? resetValue;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final bool? obscureText;
  final int? maxLength;

  const InputDialog({
    super.key,
    required this.title,
    required this.value,
    this.suffixText,
    this.resetValue,
    this.hintText,
    this.validator,
    this.obscureText,
    this.labelText,
    this.maxLength,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _textController;

  String get value => widget.value;

  String get title => widget.title;

  String? get suffixText => widget.suffixText;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: value);
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState?.validate() == false) return;
    final text = _textController.value.text;
    Navigator.of(context).pop<String>(text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: title,
      child: Form(
        autovalidateMode: widget.autovalidateMode,
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 18,
          children: [
            TextFormField(
              maxLength: widget.maxLength,
              obscureText: widget.obscureText ?? false,
              keyboardType: TextInputType.url,
              maxLines: widget.obscureText == true ? 1 : 5,
              minLines: 1,
              controller: _textController,
              onFieldSubmitted: (_) {
                _handleUpdate();
              },
              decoration: surgeInputDecoration(
                context,
                suffixText: suffixText,
                hintText: widget.hintText,
                labelText: widget.labelText,
              ),
              validator: widget.validator,
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
      ),
    );
  }
}

class ListInputPage extends ConsumerStatefulWidget {
  final String title;
  final List<String> items;
  final Widget Function(String item) titleBuilder;
  final Widget Function(String item)? subtitleBuilder;
  final Widget Function(String item)? leadingBuilder;
  final String? valueLabel;
  final String? valueHint;

  const ListInputPage({
    super.key,
    required this.title,
    required this.items,
    required this.titleBuilder,
    this.leadingBuilder,
    this.valueLabel,
    this.valueHint,
    this.subtitleBuilder,
  });

  @override
  ConsumerState createState() => _ListInputPageState();
}

class _ListInputPageState extends ConsumerState<ListInputPage> {
  List<String> _items = [];
  late List<String> _originItems;
  final _key = utils.id;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
    _originItems = List<String>.from(_items);
  }

  void _handleReorder(int oldIndex, newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final nextItems = List<String>.from(_items);
    final item = nextItems.removeAt(oldIndex);
    nextItems.insert(newIndex, item);
    _items = nextItems;
    setState(() {});
  }

  void _handleSelected(String value) {
    ref.read(itemsProvider(_key).notifier).update((state) {
      final newState = Set<String>.from(state)..addOrRemove(value);
      return newState;
    });
  }

  void _handleSelectAll() {
    final ids = _items.toSet();
    ref.read(itemsProvider(_key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleAddOrEdit([String? item]) async {
    final appLocalizations = context.appLocalizations;
    String? uniqueValidator(String? value) {
      final index = _items.indexWhere((entry) {
        return entry == value;
      });
      final current = item == value;
      if (index != -1 && !current) {
        return appLocalizations.existsTip(appLocalizations.value);
      }
      return null;
    }

    final value = await globalState.showCommonDialog<String>(
      child: AddDialog(
        valueHint: widget.valueHint,
        valueField: Field(
          label: widget.valueLabel ?? appLocalizations.value,
          value: item ?? '',
          validator: uniqueValidator,
        ),
        title: item != null ? appLocalizations.edit : appLocalizations.add,
      ),
    );

    if (value == null) return;
    final index = _items.indexWhere((entry) {
      return entry == item;
    });
    final nextItems = List<String>.from(_items);
    if (item != null) {
      nextItems[index] = value;
    } else {
      nextItems.add(value);
    }
    _items = nextItems;
    setState(() {});
  }

  void _handleDelete() {
    final selectedItems = ref.read(itemsProvider(_key));
    final newItems = _items
        .where((item) => !selectedItems.contains(item))
        .toList();
    _items = newItems;
    ref.read(itemsProvider(_key).notifier).value = {};
    setState(() {});
  }

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.resetPageChangesTip),
    );
    if (res != true) {
      return;
    }
    _items = _originItems;
    setState(() {});
  }

  Widget _buildItem({
    required String value,
    required int index,
    required int length,
    required bool isSelected,
    required bool isEditing,
  }) {
    final position = ItemPosition.get(index, length);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(value),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: SelectedDecorationListItem(
          title: widget.titleBuilder(value),
          isSelected: isSelected,
          isEditing: isEditing,
          onSelected: () {
            _handleSelected(value);
          },
          onPressed: () {
            _handleAddOrEdit(value);
          },
          leading: widget.leadingBuilder != null
              ? widget.leadingBuilder!(value)
              : null,
          subtitle: widget.subtitleBuilder != null
              ? widget.subtitleBuilder!(value)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final selectedItems = ref.watch(itemsProvider(_key));
    return CommonPopScope(
      onPop: (_) {
        if (selectedItems.isNotEmpty) {
          ref.read(itemsProvider(_key).notifier).value = {};
          return false;
        }
        Navigator.of(context).pop(_items);
        return false;
      },
      child: CommonScaffold(
        title: widget.title,
        actions: [
          if (selectedItems.isNotEmpty) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(width: 2),
          ] else if (!stringListEquality.equals(_items, _originItems)) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: _handleReset,
                icon: const Icon(Icons.replay),
              ),
            ),
            const SizedBox(width: 2),
          ],
          CommonMinFilledButtonTheme(
            child: selectedItems.isNotEmpty
                ? FilledButton(
                    onPressed: _handleSelectAll,
                    child: Text(appLocalizations.selectAll),
                  )
                : SurgeAddButton(
                    onPressed: () {
                      _handleAddOrEdit();
                    },
                    label: appLocalizations.add,
                  ),
          ),
          const SizedBox(width: 8),
        ],
        body: _items.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 16 + 64,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final value = _items[index];
                  return _buildItem(
                    value: value,
                    index: index,
                    length: _items.length,
                    isSelected: selectedItems.contains(value),
                    isEditing: selectedItems.isNotEmpty,
                  );
                },
                proxyDecorator: (child, index, animation) {
                  final value = _items[index];
                  return commonProxyDecorator(
                    _buildItem(
                      value: value,
                      index: index,
                      length: _items.length,
                      isSelected: selectedItems.contains(value),
                      isEditing: selectedItems.isNotEmpty,
                    ),
                    index,
                    animation,
                  );
                },
                onReorder: _handleReorder,
              ),
      ),
    );
  }
}

class MapInputPage extends ConsumerStatefulWidget {
  final String title;
  final Map<String, String> map;
  final Widget Function(MapEntry<String, String> item) titleBuilder;
  final Widget Function(MapEntry<String, String> item)? subtitleBuilder;
  final Widget Function(MapEntry<String, String> item)? leadingBuilder;
  final String? keyLabel;
  final String? valueLabel;

  const MapInputPage({
    super.key,
    required this.title,
    required this.map,
    required this.titleBuilder,
    this.leadingBuilder,
    this.keyLabel,
    this.valueLabel,
    this.subtitleBuilder,
  });

  @override
  ConsumerState<MapInputPage> createState() => _MapInputPageState();
}

class _MapInputPageState extends ConsumerState<MapInputPage> {
  List<MapEntry<String, String>> _items = [];
  late final List<MapEntry<String, String>> _originItems;
  final _key = utils.id;

  @override
  void initState() {
    super.initState();
    _items = List<MapEntry<String, String>>.from(widget.map.entries);
    _originItems = List<MapEntry<String, String>>.from(_items);
  }

  void _handleReorder(int oldIndex, newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final nextItems = List<MapEntry<String, String>>.from(_items);
    final item = nextItems.removeAt(oldIndex);
    nextItems.insert(newIndex, item);
    _items = nextItems;
    setState(() {});
  }

  void _handleSelected(MapEntry<String, String> value) {
    ref.read(itemsProvider(_key).notifier).update((state) {
      final newState = Set<String>.from(state)..addOrRemove(value.key);
      return newState;
    });
  }

  void _handleSelectAll() {
    final ids = _items.map((item) => item.key).toSet();
    ref.read(itemsProvider(_key).notifier).update((selected) {
      return selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleAddOrEdit([MapEntry<String, String>? item]) async {
    final appLocalizations = context.appLocalizations;
    String? uniqueValidator(String? value) {
      final index = _items.indexWhere((entry) {
        return entry.key == value;
      });
      final current = item?.key == value;
      if (index != -1 && !current) {
        return appLocalizations.existsTip(appLocalizations.key);
      }
      return null;
    }

    final keyField = Field(
      label: widget.keyLabel ?? appLocalizations.key,
      value: item == null ? '' : item.key,
      validator: uniqueValidator,
    );

    final valueField = Field(
      label: widget.valueLabel ?? appLocalizations.value,
      value: item == null ? '' : item.value,
    );

    final value = await globalState.showCommonDialog<MapEntry<String, String>>(
      child: AddDialog(
        keyField: keyField,
        valueField: valueField,
        title: item != null ? appLocalizations.edit : appLocalizations.add,
      ),
    );
    if (value == null) return;
    final index = _items.indexWhere((entry) {
      return entry.key == item?.key;
    });

    final nextItems = List<MapEntry<String, String>>.from(_items);
    if (item != null) {
      nextItems[index] = value;
    } else {
      nextItems.add(value);
    }
    _items = nextItems;
    setState(() {});
  }

  void _handleDelete() {
    final selectedItems = ref.read(itemsProvider(_key));
    final newItems = _items
        .where((item) => !selectedItems.contains(item.key))
        .toList();
    _items = newItems;
    ref.read(itemsProvider(_key).notifier).value = {};
    setState(() {});
  }

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: context.appLocalizations.resetPageChangesTip),
    );
    if (res != true) {
      return;
    }
    _items = _originItems;
    setState(() {});
  }

  Widget _buildItem({
    required MapEntry<String, String> value,
    required int index,
    required int length,
    required bool isSelected,
    required bool isEditing,
  }) {
    final position = ItemPosition.get(index, length);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(value),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: SelectedDecorationListItem(
          title: widget.titleBuilder(value),
          leading: widget.leadingBuilder != null
              ? widget.leadingBuilder!(value)
              : null,
          subtitle: widget.subtitleBuilder != null
              ? widget.subtitleBuilder!(value)
              : null,
          isSelected: isSelected,
          isEditing: isEditing,
          onSelected: () {
            _handleSelected(value);
          },
          onPressed: () {
            _handleAddOrEdit(value);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final selectedItems = ref.watch(itemsProvider(_key));
    return CommonPopScope(
      onPop: (_) {
        if (selectedItems.isNotEmpty) {
          ref.read(itemsProvider(_key).notifier).value = {};
          return false;
        }
        Navigator.of(context).pop(Map<String, String>.fromEntries(_items));
        return false;
      },
      child: CommonScaffold(
        title: widget.title,
        actions: [
          if (selectedItems.isNotEmpty) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(width: 2),
          ] else if (!stringAndStringMapEntryListEquality.equals(
            _items,
            _originItems,
          )) ...[
            CommonMinIconButtonTheme(
              child: IconButton.filledTonal(
                onPressed: _handleReset,
                icon: const Icon(Icons.replay),
              ),
            ),
            const SizedBox(width: 2),
          ],
          CommonMinFilledButtonTheme(
            child: selectedItems.isNotEmpty
                ? FilledButton(
                    onPressed: _handleSelectAll,
                    child: Text(appLocalizations.selectAll),
                  )
                : SurgeAddButton(
                    onPressed: () {
                      _handleAddOrEdit();
                    },
                    label: appLocalizations.add,
                  ),
          ),
          const SizedBox(width: 8),
        ],
        body: _items.isEmpty
            ? NullStatus(label: appLocalizations.noData)
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 16 + 64,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final value = _items[index];
                  return _buildItem(
                    value: value,
                    index: index,
                    length: _items.length,
                    isSelected: selectedItems.contains(value.key),
                    isEditing: selectedItems.isNotEmpty,
                  );
                },
                proxyDecorator: (child, index, animation) {
                  final value = _items[index];
                  return commonProxyDecorator(
                    _buildItem(
                      value: value,
                      index: index,
                      length: _items.length,
                      isSelected: selectedItems.contains(value.key),
                      isEditing: selectedItems.isNotEmpty,
                    ),
                    index,
                    animation,
                  );
                },
                onReorder: _handleReorder,
              ),
      ),
    );
  }
}

class AddDialog extends StatefulWidget {
  final String title;
  final Field? keyField;
  final Field valueField;
  final String? valueHint;

  const AddDialog({
    super.key,
    required this.title,
    this.keyField,
    required this.valueField,
    this.valueHint,
  });

  @override
  State<AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<AddDialog> {
  TextEditingController? _keyController;
  late TextEditingController _valueController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Field? get keyField => widget.keyField;

  Field get valueField => widget.valueField;

  @override
  void initState() {
    super.initState();
    if (keyField != null) {
      _keyController = TextEditingController(text: keyField!.value);
    }
    _valueController = TextEditingController(text: valueField.value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (keyField != null) {
      Navigator.of(context).pop<MapEntry<String, String>>(
        MapEntry(_keyController!.text, _valueController.text),
      );
    } else {
      Navigator.of(context).pop<String>(_valueController.text);
    }
  }

  @override
  void dispose() {
    _keyController?.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.title,
      child: Form(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 18,
          children: [
            if (keyField != null)
              TextFormField(
                maxLines: 3,
                minLines: 1,
                controller: _keyController,
                decoration: surgeInputDecoration(
                  context,
                  labelText: keyField!.label,
                ),
                validator: (String? value) {
                  String? res;
                  if (keyField!.validator != null) {
                    res = keyField!.validator!(value);
                  }
                  if (res != null) {
                    return res;
                  }
                  if (value == null || value.isEmpty) {
                    return appLocalizations.emptyTip(appLocalizations.key);
                  }
                  return null;
                },
              ),
            TextFormField(
              maxLines: 3,
              minLines: 1,
              keyboardType: TextInputType.text,
              controller: _valueController,
              decoration: surgeInputDecoration(
                context,
                labelText: valueField.label,
                hintText: widget.valueHint,
              ),
              onFieldSubmitted: (_) {
                _submit();
              },
              validator: (String? value) {
                String? res;
                if (valueField.validator != null) {
                  res = valueField.validator!(value);
                }
                if (res != null) {
                  return res;
                }
                if (value == null || value.isEmpty) {
                  return appLocalizations.emptyTip(appLocalizations.value);
                }
                return null;
              },
            ),
            SurgeDialogActionRow(
              cancelLabel: appLocalizations.cancel,
              submitLabel: appLocalizations.confirm,
              onCancel: () {
                Navigator.of(context).pop();
              },
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class NoInputBorder extends InputBorder {
  const NoInputBorder() : super(borderSide: BorderSide.none);

  @override
  NoInputBorder copyWith({BorderSide? borderSide}) => const NoInputBorder();

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  NoInputBorder scale(double t) => const NoInputBorder();

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawRect(rect, paint);
  }

  @override
  bool get preferPaintInterior => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {}
}
