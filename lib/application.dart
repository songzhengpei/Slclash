import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/phase4_perf.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/changelog_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'pages/pages.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateProfilesTaskTimer;
  DateTime? _lastCloseConnectionsTime;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CommonPageTransitionsBuilder(),
      TargetPlatform.windows: CommonPageTransitionsBuilder(),
      TargetPlatform.linux: CommonPageTransitionsBuilder(),
      TargetPlatform.macOS: CommonPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    required ThemeProps themeProps,
  }) {
    final useDynamic = themeProps.dynamicColor;
    final primaryColor = themeProps.primaryColor;
    return ref.read(
      genColorSchemeProvider(
        brightness,
        color: useDynamic
            ? null
            : (primaryColor == null ? null : Color(primaryColor)),
      ),
    );
  }

  SurgeTheme _getSurgeTheme({
    required Brightness brightness,
    required ThemeProps themeProps,
    required ColorScheme colorScheme,
  }) {
    if (themeProps.dynamicColor ||
        themeProps.primaryColor == legacyGraySeedColor) {
      return SurgeTheme.fromColorScheme(colorScheme);
    }
    return brightness == Brightness.dark
        ? SurgeTheme.dark()
        : SurgeTheme.light();
  }

  SystemUiOverlayStyle _getSystemUiOverlayStyle(SurgeTheme surge) {
    final brightness = ThemeData.estimateBrightnessForColor(surge.background);
    final iconBrightness = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: surge.background,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: brightness,
      systemNavigationBarColor: surge.background,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: surge.separator,
    );
  }

  NavigationBarThemeData _getNavigationBarTheme(
    SurgeTheme surge,
    SurgeTypography typography,
  ) {
    return NavigationBarThemeData(
      backgroundColor: surge.card,
      indicatorColor: surge.selectedFill,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return typography.navigationLabel.copyWith(
          color: selected ? surge.primary : surge.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? surge.primary : surge.textSecondary,
          size: 22,
        );
      }),
    );
  }

  SwitchThemeData _getSwitchTheme(SurgeTheme surge) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return surge.textSecondary.withValues(alpha: 0.45);
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return surge.textSecondary.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.selected)) {
          return surge.primary;
        }
        return surge.fill;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return surge.separator;
      }),
    );
  }

  RadioThemeData _getRadioTheme(SurgeTheme surge) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return surge.primary;
        }
        return surge.textSecondary.withValues(alpha: 0.78);
      }),
    );
  }

  CheckboxThemeData _getCheckboxTheme(SurgeTheme surge) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return surge.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(surge.onPrimary),
      side: BorderSide(color: surge.separator, width: 1.2),
    );
  }

  ThemeData _buildTheme({
    required Brightness brightness,
    required ThemeProps themeProps,
  }) {
    final useFixedSurge =
        !themeProps.dynamicColor &&
        themeProps.primaryColor != legacyGraySeedColor;
    final fixedSurge = brightness == Brightness.dark
        ? SurgeTheme.dark()
        : SurgeTheme.light();
    final baseColorScheme = _getAppColorScheme(
      brightness: brightness,
      themeProps: themeProps,
    );
    final colorScheme =
        (brightness == Brightness.dark
                ? baseColorScheme.toPureBlack(themeProps.pureBlack)
                : baseColorScheme)
            .copyWith(
              primary: useFixedSurge ? fixedSurge.primary : null,
              onPrimary: useFixedSurge ? fixedSurge.onPrimary : null,
              primaryContainer: useFixedSurge ? fixedSurge.fill : null,
              onPrimaryContainer: useFixedSurge ? fixedSurge.textPrimary : null,
              secondary: useFixedSurge ? fixedSurge.textSecondary : null,
              secondaryContainer: useFixedSurge ? fixedSurge.fill : null,
              onSecondaryContainer: useFixedSurge
                  ? fixedSurge.textPrimary
                  : null,
              tertiaryContainer: useFixedSurge ? fixedSurge.fill : null,
              onTertiaryContainer: useFixedSurge
                  ? fixedSurge.textPrimary
                  : null,
              surface: useFixedSurge ? fixedSurge.card : null,
              surfaceContainerLowest: useFixedSurge ? fixedSurge.card : null,
              surfaceContainerLow: useFixedSurge ? fixedSurge.card : null,
              surfaceContainer: useFixedSurge ? fixedSurge.background : null,
              surfaceContainerHigh: useFixedSurge ? fixedSurge.card : null,
              surfaceContainerHighest: useFixedSurge ? fixedSurge.fill : null,
              outline: useFixedSurge ? fixedSurge.separator : null,
              outlineVariant: useFixedSurge ? fixedSurge.separator : null,
            );
    final textTheme = buildSlclashTextTheme();
    final typography = SurgeTypography.fromTextTheme(textTheme);
    final surge = _getSurgeTheme(
      brightness: brightness,
      themeProps: themeProps,
      colorScheme: colorScheme,
    );
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      textTheme: textTheme,
      extensions: [surge, typography],
      scaffoldBackgroundColor: surge.background,
      canvasColor: surge.background,
      appBarTheme: AppBarTheme(
        backgroundColor: surge.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: surge.textPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: surge.textPrimary),
        actionsIconTheme: IconThemeData(color: surge.textPrimary),
        titleTextStyle: typography.appBarTitle.copyWith(
          color: surge.textPrimary,
        ),
      ),
      navigationBarTheme: _getNavigationBarTheme(surge, typography),
      switchTheme: _getSwitchTheme(surge),
      radioTheme: _getRadioTheme(surge),
      checkboxTheme: _getCheckboxTheme(surge),
      colorScheme: colorScheme,
    );
  }

  @override
  Widget build(context) {
    return Consumer(
      builder: (_, ref, child) {
        final locale = ref.watch(
          appSettingProvider.select((state) => state.locale),
        );
        final themeProps = ref.watch(themeSettingProvider);
        final currentBrightness = ref.watch(currentBrightnessProvider);
        final overlayBaseColorScheme = _getAppColorScheme(
          brightness: currentBrightness,
          themeProps: themeProps,
        );
        final overlayColorScheme = currentBrightness == Brightness.dark
            ? overlayBaseColorScheme.toPureBlack(themeProps.pureBlack)
            : overlayBaseColorScheme;
        final overlaySurge = _getSurgeTheme(
          brightness: currentBrightness,
          themeProps: themeProps,
          colorScheme: overlayColorScheme,
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: globalState.navigatorKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (_, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _getSystemUiOverlayStyle(overlaySurge),
              child: AppEnvManager(
                child: _buildApp(
                  child: _buildPlatformState(
                    child: _buildState(child: _buildPlatformApp(child: child!)),
                  ),
                ),
              ),
            );
          },
          scrollBehavior: BaseScrollBehavior(),
          title: appName,
          locale: utils.getLocaleForString(locale),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          themeMode: themeProps.themeMode,
          theme: _buildTheme(
            brightness: Brightness.light,
            themeProps: themeProps,
          ),
          darkTheme: _buildTheme(
            brightness: Brightness.dark,
            themeProps: themeProps,
          ),
          home: child!,
        );
      },
      child: const HomePage(),
    );
  }

  @override
  void initState() {
    super.initState();
    Phase4PerfCommands.attach();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (globalState.navigatorKey.currentContext != null) {
        StartupTrace.mark('globalState.attach.begin');
        await globalState.attach();
        StartupTrace.mark('globalState.attach');
      } else {
        exit(0);
      }
      await _showChangelogAfterUpdate();
      _autoUpdateProfilesTask();
      _initLink();
      app?.initShortcuts();
    });
  }

  Future<void> _showChangelogAfterUpdate() async {
    const entries = appChangelogEntries;
    if (entries.isEmpty) return;
    final wasUpdated = await app?.wasUpdated() ?? false;
    final lastShownVersion = await preferences.getString(
      lastShownChangelogVersionKey,
    );
    if (!shouldShowChangelogAfterUpdate(
      wasUpdated: wasUpdated,
      lastShownVersion: lastShownVersion,
      entries: entries,
    )) {
      return;
    }
    final confirmed = await globalState.showCommonDialog<bool>(
      child: const AppChangelogDialog(
        entries: entries,
        requireConfirmation: true,
      ),
      dismissible: false,
    );
    if (confirmed == true) {
      await preferences.setString(
        lastShownChangelogVersionKey,
        entries.first.version,
      );
    }
  }

  void _initLink() {
    linkManager.initAppLinksListen((url) async {
      final res = await globalState.showMessage(
        title: currentAppLocalizations.addProfile,
        message: TextSpan(
          children: [
            TextSpan(text: currentAppLocalizations.doYouWantToPass),
            TextSpan(
              text: ' $url ',
              style: context.typography.body.copyWith(
                color: context.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: context.colorScheme.primary,
              ),
            ),
            TextSpan(text: currentAppLocalizations.createProfile),
          ],
        ),
      );
      if (res != true) return;
      ref.read(profilesActionProvider.notifier).addProfileFormURL(url);
    });
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      StartupTrace.mark('profile_auto_update_begin');
      await ref.read(profilesActionProvider.notifier).autoUpdateProfiles();
      StartupTrace.mark('profile_auto_update_end');
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState({required Widget child}) {
    return AndroidManager(child: TileManager(child: child));
  }

  Widget _buildState({required Widget child}) {
    return AppStateManager(
      child: CoreManager(
        child: ConnectivityManager(
          onConnectivityChanged: (results) async {
            commonPrint.log('connectivityChanged ${results.toString()}');
            ref.read(connectivityResultsProvider.notifier).set(results);
            // Always update local IP — network has changed.
            ref.read(systemActionProvider.notifier).updateLocalIp();
            final hasVpn = results.contains(ConnectivityResult.vpn);

            // Close stale connections on network change (Wi-Fi ↔ 5G).
            // Reuses the existing appSetting.closeConnections toggle —
            // no separate setting is introduced.
            final isStart = ref.read(isStartProvider);
            final isSmartStopped = ref.read(isSmartStoppedProvider);
            final autoCloseConnections = ref.read(
              appSettingProvider.select((state) => state.closeConnections),
            );
            if (!system.isAndroid &&
                !hasVpn &&
                (isStart || isSmartStopped) &&
                autoCloseConnections) {
              final now = DateTime.now();
              final last = _lastCloseConnectionsTime;
              if (last == null || now.difference(last).inMilliseconds > 1000) {
                _lastCloseConnectionsTime = now;
                try {
                  final closed = await coreController.closeConnections();
                  if (!closed) {
                    commonPrint.log(
                      'some connections could not be closed after network change',
                      logLevel: LogLevel.warning,
                    );
                  }
                } catch (e) {
                  commonPrint.log(
                    'closeConnections on connectivity changed failed: $e',
                    logLevel: LogLevel.warning,
                  );
                }
              }
            }

            // Always trigger IP check so the UI reflects the new network.
            ref.read(checkIpNumProvider.notifier).add();
          },
          child: child,
        ),
      ),
    );
  }

  Widget _buildPlatformApp({required Widget child}) {
    return VpnManager(child: child);
  }

  Widget _buildApp({required Widget child}) {
    return StatusManager(child: ThemeManager(child: child));
  }

  @override
  void dispose() {
    StartupTrace.mark(
      'application_dispose',
      extras: {
        'scope': 'flutter_resources',
        'proxy_lifecycle': 'retained',
        'core_lifecycle': 'retained',
      },
    );
    linkManager.destroy();
    _autoUpdateProfilesTaskTimer?.cancel();
    super.dispose();
  }
}
