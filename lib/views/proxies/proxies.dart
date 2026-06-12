import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/views/proxies/providers.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'setting.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> {
  List<Widget> _buildActions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final hasProviders = ref.watch(
      providersProvider.select((state) => state.isNotEmpty),
    );
    return [
      if (hasProviders)
        _ProxiesActionButton(
          tooltip: appLocalizations.providers,
          icon: Icons.cloud_sync_rounded,
          onPressed: () {
            showSheet(
              context: context,
              props: const SheetProps(isScrollControlled: true),
              builder: (_) {
                return const ProvidersView();
              },
            );
          },
        ),
      _ProxiesActionButton(
        tooltip: appLocalizations.settings,
        icon: Icons.tune_rounded,
        onPressed: () {
          showSheet(
            context: context,
            props: const SheetProps(isScrollControlled: true),
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: const ProxiesSetting(),
                title: appLocalizations.settings,
              );
            },
          );
        },
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(proxiesStyleSettingProvider.notifier).update((state) {
        return state.copyWith(type: ProxiesType.list);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isLoading = ref.watch(loadingProvider(LoadingTag.proxies));
    return CommonScaffold(
      isLoading: isLoading,
      resizeToAvoidBottomInset: false,
      actions: _buildActions(context),
      title: context.appLocalizations.proxies,
      backgroundColor: surge.background,
      body: ColoredBox(color: surge.background, child: const ProxiesListView()),
    );
  }
}

class _ProxiesActionButton extends StatelessWidget {
  const _ProxiesActionButton({
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
