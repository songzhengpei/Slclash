import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      vpnSettingProvider.select((state) => state.enable),
    );
    return ListItem.switchItem(
      title: const Text('VPN'),
      subtitle: Text(appLocalizations.vpnEnableDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(enable: value));
        },
      ),
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.tun),
      subtitle: Text(appLocalizations.tunDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith.tun(enable: value));
        },
      ),
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final allowBypass = ref.watch(
      vpnSettingProvider.select((state) => state.allowBypass),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.allowBypass),
      subtitle: Text(appLocalizations.allowBypassDesc),
      delegate: SwitchDelegate(
        value: allowBypass,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(allowBypass: value));
        },
      ),
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final systemProxy = ref.watch(
      vpnSettingProvider.select((state) => state.systemProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(systemProxy: value));
        },
      ),
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.systemProxyDesc),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(systemProxy: value));
        },
      ),
    );
  }
}

class Ipv6Item extends ConsumerWidget {
  const Ipv6Item({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final ipv6 = ref.watch(vpnSettingProvider.select((state) => state.ipv6));
    return ListItem.switchItem(
      title: const Text('IPv6'),
      subtitle: Text(appLocalizations.ipv6InboundDesc),
      delegate: SwitchDelegate(
        value: ipv6,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(ipv6: value));
        },
      ),
    );
  }
}

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final autoSetSystemDns = ref.watch(
      networkSettingProvider.select((state) => state.autoSetSystemDns),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoSetSystemDns),
      delegate: SwitchDelegate(
        value: autoSetSystemDns,
        onChanged: (bool value) async {
          ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(autoSetSystemDns: value));
        },
      ),
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final stack = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.stack),
    );

    return ListItem.options(
      title: Text(appLocalizations.stackMode),
      subtitle: Text(stack.name),
      delegate: OptionsDelegate<TunStack>(
        value: stack,
        options: TunStack.values,
        textBuilder: (value) => value.name,
        onChanged: (value) {
          if (value == null) {
            return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith.tun(stack: value));
        },
        title: appLocalizations.stackMode,
      ),
    );
  }
}

class BypassDomainItem extends ConsumerWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final bypassDomain = ref.watch(
      networkSettingProvider.select((state) => state.bypassDomain),
    );
    return ListItem.open(
      title: Text(appLocalizations.bypassDomain),
      subtitle: Text(appLocalizations.bypassDomainDesc),
      delegate: OpenDelegate(
        blur: false,
        widget: ListInputPage(
          title: appLocalizations.bypassDomain,
          items: bypassDomain,
          titleBuilder: (item) => Text(item),
        ),
        onChanged: (items) {
          ref
              .read(networkSettingProvider.notifier)
              .update(
                (state) => state.copyWith(bypassDomain: List.from(items)),
              );
        },
      ),
    );
  }
}

class DNSHijackingItem extends ConsumerWidget {
  const DNSHijackingItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final dnsHijacking = ref.watch(
      vpnSettingProvider.select((state) => state.dnsHijacking),
    );
    return ListItem<RouteMode>.switchItem(
      title: Text(appLocalizations.dnsHijacking),
      delegate: SwitchDelegate(
        value: dnsHijacking,
        onChanged: (value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(dnsHijacking: value));
        },
      ),
    );
  }
}

class RouteModeItem extends ConsumerWidget {
  const RouteModeItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final routeMode = ref.watch(
      networkSettingProvider.select((state) => state.routeMode),
    );
    return ListItem<RouteMode>.options(
      title: Text(appLocalizations.routeMode),
      subtitle: Text(Intl.message('routeMode_${routeMode.name}')),
      delegate: OptionsDelegate<RouteMode>(
        title: appLocalizations.routeMode,
        options: RouteMode.values,
        onChanged: (RouteMode? value) {
          if (value == null) {
            return;
          }
          ref
              .read(networkSettingProvider.notifier)
              .update((state) => state.copyWith(routeMode: value));
        },
        textBuilder: (routeMode) => Intl.message('routeMode_${routeMode.name}'),
        value: routeMode,
      ),
    );
  }
}

class RouteAddressItem extends ConsumerWidget {
  const RouteAddressItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final bypassPrivate = ref.watch(
      networkSettingProvider.select(
        (state) => state.routeMode == RouteMode.bypassPrivate,
      ),
    );
    if (bypassPrivate) {
      return Container();
    }
    final routeAddress = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.routeAddress),
    );
    return ListItem.open(
      title: Text(appLocalizations.routeAddress),
      subtitle: Text(appLocalizations.routeAddressDesc),
      delegate: OpenDelegate(
        blur: false,
        maxWidth: 360,
        widget: ListInputPage(
          title: appLocalizations.routeAddress,
          items: routeAddress,
          titleBuilder: (item) => Text(item),
        ),
        onChanged: (items) {
          ref
              .read(patchClashConfigProvider.notifier)
              .update(
                (state) => state.copyWith.tun(routeAddress: List.from(items)),
              );
        },
      ),
    );
  }
}

class SmartAutoStopItem extends ConsumerWidget {
  const SmartAutoStopItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final smartAutoStop = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStop),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.smartAutoStop),
      subtitle: Text(appLocalizations.smartAutoStopDesc),
      delegate: SwitchDelegate(
        value: smartAutoStop,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .update((state) => state.copyWith(smartAutoStop: value));
        },
      ),
    );
  }
}

class SmartAutoStopNetworksItem extends ConsumerWidget {
  const SmartAutoStopNetworksItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final networks = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStopNetworks),
    );
    final smartAutoStop = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStop),
    );
    if (!smartAutoStop) return const SizedBox.shrink();
    return ListItem.open(
      title: Text(appLocalizations.trustedNetworks),
      subtitle: Text(
        networks.isEmpty
            ? appLocalizations.networksEmpty
            : networks.join(', '),
      ),
      delegate: OpenDelegate(
        widget: _SmartAutoStopNetworksPage(networks: networks),
      ),
    );
  }
}

class _SmartAutoStopNetworksPage extends ConsumerStatefulWidget {
  final List<String> networks;
  const _SmartAutoStopNetworksPage({required this.networks});

  @override
  ConsumerState<_SmartAutoStopNetworksPage> createState() =>
      _SmartAutoStopNetworksPageState();
}

class _SmartAutoStopNetworksPageState
    extends ConsumerState<_SmartAutoStopNetworksPage> {
  void _addNetwork() {
    _showEditSheet(
      title: context.appLocalizations.addNetwork,
      onSave: (value) {
        ref.read(vpnSettingProvider.notifier).update(
              (state) => state.copyWith(
                smartAutoStopNetworks: [
                  ...state.smartAutoStopNetworks,
                  value,
                ],
              ),
            );
      },
    );
  }

  void _editNetwork(int index) {
    final networks = ref.read(
      vpnSettingProvider.select((state) => state.smartAutoStopNetworks),
    );
    _showEditSheet(
      title: context.appLocalizations.editNetwork,
      initialValue: networks[index],
      onSave: (value) {
        final newList = List<String>.from(networks);
        newList[index] = value;
        ref.read(vpnSettingProvider.notifier).update(
              (state) => state.copyWith(smartAutoStopNetworks: newList),
            );
      },
    );
  }

  void _removeNetwork(int index) {
    ref.read(vpnSettingProvider.notifier).update(
          (state) => state.copyWith(
            smartAutoStopNetworks: List<String>.from(
              state.smartAutoStopNetworks,
            )..removeAt(index),
          ),
        );
  }

  void _showEditSheet({
    required String title,
    String? initialValue,
    required ValueChanged<String> onSave,
  }) {
    showSheet(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: initialValue ?? '');
        return AdaptiveSheetScaffold(
          title: title,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: context.appLocalizations.networkAddress,
                    hintText: context.appLocalizations.networkAddressHint,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isNotEmpty) {
                        onSave(value);
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(context.appLocalizations.save),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final networks = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStopNetworks),
    );
    return AdaptiveSheetScaffold(
      title: appLocalizations.trustedNetworks,
      actions: [
        IconButtonData(icon: Icons.add, onPressed: _addNetwork),
      ],
      body: networks.isEmpty
          ? Center(child: Text(appLocalizations.networksEmpty))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: networks.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(networks[index]),
                  onTap: () => _editNetwork(index),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeNetwork(index),
                  ),
                );
              },
            ),
    );
  }
}

class NetworkListView extends StatelessWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return generateListView([
      if (system.isAndroid) const VPNItem(),
      if (system.isAndroid)
        ...generateSection(
          items: [
            const VpnSystemProxyItem(),
            const BypassDomainItem(),
            const AllowBypassItem(),
            const Ipv6Item(),
            const DNSHijackingItem(),
            const SmartAutoStopItem(),
            const SmartAutoStopNetworksItem(),
          ],
        ),
      if (system.isDesktop)
        ...generateSection(
          title: appLocalizations.system,
          items: [const SystemProxyItem(), const BypassDomainItem()],
        ),
      ...generateSection(
        title: appLocalizations.options,
        items: [
          if (system.isDesktop) const TUNItem(),
          if (system.isMacOS) const AutoSetSystemDnsItem(),
          const TunStackItem(),
          if (!system.isDesktop) ...[
            const RouteModeItem(),
            const RouteAddressItem(),
          ],
        ],
      ),
    ]);
  }
}
