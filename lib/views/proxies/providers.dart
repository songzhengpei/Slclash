import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common.dart';

class ProvidersView extends ConsumerStatefulWidget {
  const ProvidersView({super.key});

  @override
  ConsumerState<ProvidersView> createState() => _ProvidersViewState();
}

class _ProvidersViewState extends ConsumerState<ProvidersView> {
  Future<void> _updateProviders() async {
    final ref = globalState.container;
    final providers = ref.read(providersProvider);
    final messages = <UpdatingMessage>[];
    final updateProviders = providers.map<Future>((provider) async {
      final message = await ref
          .read(proxiesActionProvider.notifier)
          .updateProvider(provider);
      if (message.isNotEmpty) {
        messages.add(UpdatingMessage(label: provider.name, message: message));
      }
    });
    await Future.wait(updateProviders);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    if (messages.isNotEmpty) {
      globalState.showAllUpdatingMessagesDialog(messages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    final providers = ref.watch(providersProvider);
    final proxyProviders = providers
        .where((item) => item.type == 'Proxy')
        .toList();
    final ruleProviders = providers
        .where((item) => item.type == 'Rule')
        .toList();

    return AdaptiveSheetScaffold(
      actions: [
        IconButtonData(icon: SurgeIcons.sync, onPressed: _updateProviders),
      ],
      body: ColoredBox(
        color: surge.background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (proxyProviders.isNotEmpty)
              _ProviderSection(
                title: appLocalizations.proxyProviders,
                providers: proxyProviders,
              ),
            if (proxyProviders.isNotEmpty && ruleProviders.isNotEmpty)
              const SizedBox(height: 14),
            if (ruleProviders.isNotEmpty)
              _ProviderSection(
                title: appLocalizations.ruleProviders,
                providers: ruleProviders,
              ),
          ],
        ),
      ),
      title: appLocalizations.providers,
    );
  }
}

class _ProviderSection extends StatelessWidget {
  const _ProviderSection({required this.title, required this.providers});

  final String title;
  final List<ExternalProvider> providers;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              color: surge.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < providers.length; i++)
              ProviderItem(
                provider: providers[i],
                rowPosition: providers.length == 1
                    ? ProxyListRowPosition.single
                    : i == 0
                    ? ProxyListRowPosition.first
                    : i == providers.length - 1
                    ? ProxyListRowPosition.last
                    : ProxyListRowPosition.middle,
                showDivider: i != providers.length - 1,
              ),
          ],
        ),
      ],
    );
  }
}

class ProviderItem extends StatelessWidget {
  const ProviderItem({
    super.key,
    required this.provider,
    this.rowPosition = ProxyListRowPosition.single,
    this.showDivider = false,
  });

  final ExternalProvider provider;
  final ProxyListRowPosition rowPosition;
  final bool showDivider;

  Future<void> _handleUpdateProvider() async {
    if (provider.vehicleType != 'HTTP') return;
    final ref = globalState.container;
    await globalState.safeRun(() async {
      final message = await ref
          .read(proxiesActionProvider.notifier)
          .updateProvider(provider);
      if (message.isNotEmpty) throw message;
    }, silence: false);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  Future<void> _handleSideLoadProvider() async {
    final ref = globalState.container;
    await globalState.safeRun<void>(() async {
      final platformFile = await picker.pickerFile();
      final bytes = platformFile?.bytes;
      if (bytes == null || provider.path == null) return;
      await File(provider.path!).safeWriteAsBytes(bytes);
      final message = await coreController.sideLoadExternalProvider(
        providerName: provider.name,
        data: utf8.decode(bytes),
      );
      if (message.isNotEmpty) throw message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await coreController.getExternalProvider(provider.name));
    });
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  String _providerDesc(BuildContext context) {
    final baseInfo = provider.updateAt.getLastUpdateTimeDesc(context);
    final count = provider.count;
    return count == 0
        ? baseInfo
        : '$baseInfo  ·  $count${context.appLocalizations.entries}';
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final hasUpdated = provider.updateAt.microsecondsSinceEpoch > 0;
    final radius = BorderRadius.vertical(
      top:
          rowPosition == ProxyListRowPosition.first ||
              rowPosition == ProxyListRowPosition.single
          ? Radius.circular(surge.radii.card)
          : Radius.zero,
      bottom:
          rowPosition == ProxyListRowPosition.last ||
              rowPosition == ProxyListRowPosition.single
          ? Radius.circular(surge.radii.card)
          : Radius.zero,
    );
    final border = Border(
      left: BorderSide(
        color: surge.separator.withValues(alpha: 0.78),
        width: 0.5,
      ),
      right: BorderSide(
        color: surge.separator.withValues(alpha: 0.78),
        width: 0.5,
      ),
      top:
          rowPosition == ProxyListRowPosition.first ||
              rowPosition == ProxyListRowPosition.single
          ? BorderSide(
              color: surge.separator.withValues(alpha: 0.78),
              width: 0.5,
            )
          : BorderSide.none,
      bottom:
          rowPosition == ProxyListRowPosition.last ||
              rowPosition == ProxyListRowPosition.single
          ? BorderSide(
              color: surge.separator.withValues(alpha: 0.78),
              width: 0.5,
            )
          : BorderSide.none,
    );

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          color: surge.card,
          borderRadius: radius,
          border: border,
          boxShadow:
              rowPosition == ProxyListRowPosition.first ||
                  rowPosition == ProxyListRowPosition.single
              ? [
                  BoxShadow(
                    color: surge.shadow.withValues(alpha: 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.titleSmall?.copyWith(
                                color: surge.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              hasUpdated
                                  ? _providerDesc(context)
                                  : provider.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: surge.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ProviderActionDock(
                        uploadLabel: context.appLocalizations.upload,
                        syncLabel: context.appLocalizations.sync,
                        canSync: provider.vehicleType == 'HTTP',
                        onUpload: _handleSideLoadProvider,
                        onSync: _handleUpdateProvider,
                        updatingKey: provider.updatingKey,
                      ),
                    ],
                  ),
                  if (provider.subscriptionInfo != null) ...[
                    const SizedBox(height: 10),
                    SubscriptionInfoView(
                      subscriptionInfo: provider.subscriptionInfo,
                    ),
                  ],
                ],
              ),
            ),
            if (showDivider)
              Positioned(
                left: 14,
                right: 14,
                bottom: 0,
                child: Divider(
                  height: 0,
                  thickness: 0.5,
                  color: surge.separator.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProviderActionDock extends ConsumerWidget {
  const _ProviderActionDock({
    required this.uploadLabel,
    required this.syncLabel,
    required this.canSync,
    required this.onUpload,
    required this.onSync,
    required this.updatingKey,
  });

  final String uploadLabel;
  final String syncLabel;
  final bool canSync;
  final VoidCallback onUpload;
  final VoidCallback onSync;
  final String updatingKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUpdating = canSync && ref.watch(isUpdatingProvider(updatingKey));

    return SoftOsControlDock(
      children: [
        SoftOsDockButton(
          tooltip: uploadLabel,
          icon: SurgeIcons.uploadFile,
          onTap: onUpload,
        ),
        if (canSync) ...[
          const SoftOsDockDivider(),
          SoftOsDockButton(
            tooltip: syncLabel,
            icon: SurgeIcons.sync,
            loading: isUpdating,
            onTap: onSync,
          ),
        ],
      ],
    );
  }
}
