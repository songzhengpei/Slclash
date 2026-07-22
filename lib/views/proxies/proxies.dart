import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
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
  bool _hasProviders() {
    final runtimeHasProviders = ref.watch(
      providersProvider.select((state) => state.isNotEmpty),
    );
    final currentProfileId = ref.watch(currentProfileIdProvider);
    final profileHasProviders =
        currentProfileId != null &&
        ref.watch(
          clashConfigProvider(currentProfileId).select((state) {
            final config = state.value;
            return config != null && hasExternalProviderDefinitions(config);
          }),
        );
    return runtimeHasProviders || profileHasProviders;
  }

  Future<void> _handleProvidersPressed(BuildContext context) async {
    await ref.read(proxiesActionProvider.notifier).ensureCurrentProfileReady();
    if (!context.mounted) return;
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return const ProvidersView();
      },
    );
  }

  List<SlAppBarAction> _buildActions(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final hasProviders = _hasProviders();
    return [
      SlAppBarOverflowAction(
        tooltip: appLocalizations.more,
        popup: CommonPopupMenu(
          items: [
            if (hasProviders)
              PopupMenuItemData(
                icon: SurgeIcons.providerDownload,
                label: appLocalizations.providers,
                onPressed: () {
                  unawaited(_handleProvidersPressed(context));
                },
              ),
            PopupMenuItemData(
              icon: SurgeIcons.tune,
              label: appLocalizations.settings,
              onPressed: () {
                showSheet(
                  context: context,
                  props: const SheetProps(isScrollControlled: true),
                  builder: (_) {
                    return AdaptiveSheetScaffold(
                      body: const ProxiesSetting(),
                      title: appLocalizations.settings,
                      appBarActions: const [],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(proxiesStyleSettingProvider.notifier).update((state) {
        return state.copyWith(type: ProxiesType.list);
      });

      final profileId = ref.read(currentProfileIdProvider);
      if (profileId != null) {
        ref.invalidate(clashConfigProvider(profileId));
      }

      await ref
          .read(proxiesActionProvider.notifier)
          .hydrateProxyGroupsSnapshot();

      final ownerProfileId = ref.read(groupsOwnerProfileIdProvider);
      final currentProfileId = ref.read(currentProfileIdProvider);
      final groupsEmpty =
          ownerProfileId != currentProfileId ||
          ref.read(groupsProvider).isEmpty;
      final lastRefresh = ref.read(lastGroupsRefreshAtProvider);
      final expired =
          lastRefresh == null ||
          DateTime.now().difference(lastRefresh) > const Duration(seconds: 30);

      if (groupsEmpty || expired) {
        unawaited(
          ref
              .read(proxiesActionProvider.notifier)
              .ensureCurrentProfileReady(forceApply: groupsEmpty),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final isLoading = ref.watch(loadingProvider(LoadingTag.proxies));
    return CommonScaffold(
      isLoading: isLoading,
      resizeToAvoidBottomInset: false,
      appBarActions: _buildActions(context),
      title: context.appLocalizations.proxies,
      backgroundColor: surge.background,
      body: ColoredBox(color: surge.background, child: const ProxiesListView()),
    );
  }
}
