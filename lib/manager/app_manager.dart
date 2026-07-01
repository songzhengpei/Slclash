import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.a && next.c) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(storeActionProvider.notifier)
            .savePreferencesDebounce();
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(proxiesActionProvider.notifier)
            .updateGroupsDebounce();
      }
    });
    // Initialize smart auto stop manager (keepAlive, starts listening once)
    ref.read(smartAutoStopManagerProvider);
    // Initialize health observation scheduler (keepAlive, starts tick timer)
    ref.read(healthObservationSchedulerProvider);
    // Mark scheduler engine ready once app initialization completes
    // (profile loaded, groups available, core connected).
    ref.listenManual(initProvider, (prev, next) {
      if (next == true) {
        ref.read(healthObservationSchedulerProvider.notifier).markEngineReady();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      final isStart = ref.read(isStartProvider);
      if (prev != next && isStart) {
        debouncer.call(FunctionTag.suspend, () async {
          if (next == true) {
            await coreController.stopListener();
          } else {
            await coreController.startListener();
          }
          ref.read(checkIpNumProvider.notifier).add();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    final container = globalState.container;
    final setupAction = container.read(setupActionProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      container.read(appForegroundProvider.notifier).set(true);
      render?.resume();
      container
          .read(healthObservationSchedulerProvider.notifier)
          .onLifecycleChanged(DateTime.now());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setupAction.resumeUiStatsTimerIfNeeded();
        setupAction.tryCheckIp();
        if (system.isAndroid) {
          final isStart = container.read(isStartProvider);
          final hasGroups = container.read(groupsProvider).isNotEmpty;
          // Only restart core when proxy is running or groups are empty
          // (initial load). Avoid resetting computed group selections
          // when the app just returns to foreground while proxy is off.
          if (isStart || !hasGroups) {
            container.read(coreActionProvider.notifier).tryStartCore();
          }
        }
      });
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      container.read(appForegroundProvider.notifier).set(false);
      container
          .read(healthObservationSchedulerProvider.notifier)
          .onLifecycleChanged(DateTime.now());
      setupAction.cancelUiStatsTimer();
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.container.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      onPointerDown: (_) {
        globalState.container
            .read(lastUserInteractionAtProvider.notifier)
            .touch();
      },
      onPointerMove: (_) {
        globalState.container
            .read(lastUserInteractionAtProvider.notifier)
            .touch();
      },
      onPointerUp: (_) {
        globalState.container
            .read(lastUserInteractionAtProvider.notifier)
            .touch();
      },
      onPointerSignal: (_) {
        globalState.container
            .read(lastUserInteractionAtProvider.notifier)
            .touch();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: 'PRE',
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  // Widget _buildLoading() {
  //   return Consumer(
  //     builder: (_, ref, _) {
  //       final loading = ref.watch(loadingProvider);
  //       final isMobileView = ref.watch(isMobileViewProvider);
  //       return loading && !isMobileView
  //           ? RotatedBox(
  //               quarterTurns: 1,
  //               child: const LinearProgressIndicator(),
  //             )
  //           : Container();
  //     },
  //   );
  // }

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    return Material(color: context.colorScheme.surfaceContainer, child: child);
    // if (!system.isMacOS) {
    //   return Material(
    //     color: context.colorScheme.surfaceContainer,
    //     child: child,
    //   );
    // }
    // return child;
    // return TransparentMacOSSidebar(
    //   child: Material(color: Colors.transparent, child: child),
    // );
  }

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  void _handleToPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(appSettingProvider).showLabel;
    return Row(
      children: [
        _buildBackground(
          context: context,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (system.isMacOS) const SizedBox(height: 22),
                const SizedBox(height: 10),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: HiddenBarScrollBehavior(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: NavigationRail(
                            scrollable: true,
                            minExtendedWidth: 200,
                            backgroundColor: Colors.transparent,
                            selectedLabelTextStyle: context
                                .textTheme
                                .labelLarge!
                                .copyWith(color: context.colorScheme.onSurface),
                            unselectedLabelTextStyle: context
                                .textTheme
                                .labelLarge!
                                .copyWith(color: context.colorScheme.onSurface),
                            destinations: navigationItems
                                .map(
                                  (e) => NavigationRailDestination(
                                    icon: e.icon,
                                    label: Text(Intl.message(e.label.name)),
                                  ),
                                )
                                .toList(),
                            onDestinationSelected: (index) {
                              _handleToPage(navigationItems[index].label);
                            },
                            extended: false,
                            selectedIndex: currentIndex,
                            labelType: showLabel
                                ? NavigationRailLabelType.all
                                : NavigationRailLabelType.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .update(
                          (state) =>
                              state.copyWith(showLabel: !state.showLabel),
                        );
                  },
                  icon: Icon(
                    Icons.menu,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (_, constraints) {
                _updateSideBarWidth(ref, constraints.maxWidth);
                return child;
              },
            ),
          ),
        ),
      ],
    );
  }
}
