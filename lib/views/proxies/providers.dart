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
        IconButtonData(icon: Icons.sync_rounded, onPressed: _updateProviders),
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
        for (var i = 0; i < providers.length; i++) ...[
          ProviderItem(provider: providers[i]),
          if (i != providers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class ProviderItem extends StatelessWidget {
  const ProviderItem({super.key, required this.provider});

  final ExternalProvider provider;

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

    return SurgeCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      borderRadius: 18,
      shadow: true,
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
                      hasUpdated ? _providerDesc(context) : provider.type,
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
            ],
          ),
          if (provider.subscriptionInfo != null) ...[
            const SizedBox(height: 10),
            SubscriptionInfoView(subscriptionInfo: provider.subscriptionInfo),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ProviderActionButton(
                icon: Icons.upload_file_rounded,
                label: context.appLocalizations.upload,
                onTap: _handleSideLoadProvider,
              ),
              if (provider.vehicleType == 'HTTP') ...[
                const SizedBox(width: 8),
                Consumer(
                  builder: (_, ref, _) {
                    final isUpdating = ref.watch(
                      isUpdatingProvider(provider.updatingKey),
                    );
                    return _ProviderActionButton(
                      icon: Icons.sync_rounded,
                      label: context.appLocalizations.sync,
                      loading: isUpdating,
                      onTap: _handleUpdateProvider,
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderActionButton extends StatelessWidget {
  const _ProviderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final foreground = loading ? surge.textSecondary : surge.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: surge.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox.square(
                  dimension: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
