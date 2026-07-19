import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

class AppChangelogDialog extends StatelessWidget {
  const AppChangelogDialog({
    super.key,
    this.entries = appChangelogEntries,
    this.requireConfirmation = false,
  });

  final List<AppChangelogEntry> entries;
  final bool requireConfirmation;

  @override
  Widget build(BuildContext context) {
    final dialog = CommonDialog(
      title: '更新日志',
      overrideScroll: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _ChangelogCard(entry: entries[index]),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SurgeDialogActionButton(
                label: '确定',
                primary: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    return PopScope(canPop: !requireConfirmation, child: dialog);
  }
}

class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({required this.entry});

  final AppChangelogEntry entry;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(surge.radii.card),
        border: Border.all(color: surge.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.version,
                  style: context.typography.cardTitle.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
              ),
              Text(
                entry.date,
                style: context.typography.supporting.copyWith(
                  color: surge.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < entry.changes.length; index++) ...[
            _ChangelogLine(text: entry.changes[index]),
            if (index != entry.changes.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ChangelogLine extends StatelessWidget {
  const _ChangelogLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: surge.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: context.typography.supporting.copyWith(
              color: surge.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
