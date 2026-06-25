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
          leading: const Icon(Icons.view_list),
          delegate: const OpenDelegate(blur: false, widget: AccessView()),
        ),
      ListItem.open(
        title: Text(appLocalizations.addedRules),
        subtitle: Text(appLocalizations.controlGlobalAddedRules),
        leading: const Icon(Icons.library_books),
        delegate: const OpenDelegate(widget: AddedRulesView(), blur: false),
      ),
      ListItem.open(
        title: Text(appLocalizations.script),
        subtitle: Text(appLocalizations.overrideScript),
        leading: const Icon(Icons.rocket, fontWeight: FontWeight.w900),
        delegate: const OpenDelegate(widget: ScriptsView(), blur: false),
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.advancedConfig,
      body: generateListView(items),
    );
  }
}
