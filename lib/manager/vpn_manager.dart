import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VpnManager extends ConsumerStatefulWidget {
  final Widget child;

  const VpnManager({super.key, required this.child});

  @override
  ConsumerState<VpnManager> createState() => _VpnContainerState();
}

class _VpnContainerState extends ConsumerState<VpnManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(vpnStateProvider, (prev, next) {
      if (_vpnPropsRequireRestart(prev?.vpnProps, next.vpnProps)) {
        showTip(next);
      }
    });
  }

  /// Compare VpnProps excluding smart auto stop fields, which don't require
  /// a VPN restart to take effect.
  bool _vpnPropsRequireRestart(VpnProps? prev, VpnProps next) {
    if (prev == null) return false;
    return prev.copyWith(
      smartAutoStop: next.smartAutoStop,
      smartAutoStopNetworks: next.smartAutoStopNetworks,
    ) != next;
  }

  void showTip(VpnState state) {
    throttler.call(
      FunctionTag.vpnTip,
      () {
        if (!ref.read(isStartProvider) || state == globalState.lastVpnState) {
          return;
        }
        globalState.showNotifier(
          currentAppLocalizations.vpnConfigChangeDetected,
          actionState: MessageActionState(
            actionText: currentAppLocalizations.restart,
            action: () async {
              final setupAction = ref.read(setupActionProvider.notifier);
              await setupAction.handleStop();
              await setupAction.updateStatus(true);
            },
          ),
        );
      },
      duration: const Duration(seconds: 6),
      fire: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
