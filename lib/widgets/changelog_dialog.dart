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
      title: context.appLocalizations.changelog,
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
                label: context.appLocalizations.confirm,
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
            _ChangelogLine(
              text: _localizedChange(context, entry.changes[index]),
            ),
            if (index != entry.changes.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _localizedChange(BuildContext context, String key) {
    final l10n = context.appLocalizations;
    return switch (key) {
      'changelog207Item1' => l10n.changelog207Item1,
      'changelog207Item2' => l10n.changelog207Item2,
      'changelog207Item3' => l10n.changelog207Item3,
      'changelog207Item4' => l10n.changelog207Item4,
      'changelog205Item1' => l10n.changelog205Item1,
      'changelog205Item2' => l10n.changelog205Item2,
      'changelog205Item3' => l10n.changelog205Item3,
      'changelog204Item1' => l10n.changelog204Item1,
      'changelog204Item2' => l10n.changelog204Item2,
      'changelog204Item3' => l10n.changelog204Item3,
      _ => key,
    };
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
