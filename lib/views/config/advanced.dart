import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/config/scripts.dart';
import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';

import 'rules.dart';

class AdvancedConfigView extends StatelessWidget {
  const AdvancedConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final List<Widget> items = [
      if (system.isAndroid)
        ListItem.open(
          title: Text(appLocalizations.accessControl),
          subtitle: Text(appLocalizations.accessControlDesc),
          leading: const Icon(SurgeIcons.list),
          delegate: const OpenDelegate(blur: false, widget: AccessView()),
        ),
      ListItem.open(
        title: Text(appLocalizations.addedRules),
        subtitle: Text(appLocalizations.controlGlobalAddedRules),
        leading: const Icon(SurgeIcons.library),
        delegate: const OpenDelegate(widget: AddedRulesView(), blur: false),
      ),
      ListItem.open(
        title: Text(appLocalizations.script),
        subtitle: Text(appLocalizations.overrideScript),
        leading: const Icon(SurgeIcons.rocket),
        delegate: const OpenDelegate(widget: ScriptsView(), blur: false),
      ),
    ];
    return CommonScaffold(
      title: appLocalizations.advancedConfig,
      body: generateListView(items),
    );
  }
}
