import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
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
  bool _preHasVpn = false;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: commonSharedXPageTransitions,
      TargetPlatform.windows: commonSharedXPageTransitions,
      TargetPlatform.linux: commonSharedXPageTransitions,
      TargetPlatform.macOS: commonSharedXPageTransitions,
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) {
    return ref.read(
      genColorSchemeProvider(brightness, color: Color(primaryColor ?? 0)),
    );
  }

  SurgeTheme _getSurgeTheme(Brightness brightness) {
    return brightness == Brightness.dark
        ? SurgeTheme.dark()
        : SurgeTheme.light();
  }

  SystemUiOverlayStyle _getSystemUiOverlayStyle(Brightness brightness) {
    final surge = brightness == Brightness.dark
        ? SurgeColors.dark()
        : SurgeColors.light();
    final iconBrightness = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: surge.background,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: brightness,
      systemNavigationBarColor: surge.card,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: surge.separator,
    );
  }

  NavigationBarThemeData _getNavigationBarTheme(SurgeColors surge) {
    return NavigationBarThemeData(
      backgroundColor: surge.card,
      indicatorColor: surge.textSecondary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? surge.primary : surge.textSecondary,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: 0,
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

  SwitchThemeData _getSwitchTheme(SurgeColors surge) {
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
        return surge.textSecondary.withValues(alpha: 0.16);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return surge.separator;
      }),
    );
  }

  RadioThemeData _getRadioTheme(SurgeColors surge, ThemeProps themeProps) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (!themeProps.dynamicColor && states.contains(WidgetState.selected)) {
          return surge.textSecondary;
        }
        if (states.contains(WidgetState.selected)) {
          return surge.primary;
        }
        return surge.textSecondary.withValues(alpha: 0.78);
      }),
    );
  }

  CheckboxThemeData _getCheckboxTheme(SurgeColors surge) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return surge.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(color: surge.separator, width: 1.2),
    );
  }

  ThemeData _buildTheme({
    required Brightness brightness,
    required ThemeProps themeProps,
  }) {
    final surge = brightness == Brightness.dark
        ? SurgeColors.dark()
        : SurgeColors.light();
    final baseColorScheme = _getAppColorScheme(
      brightness: brightness,
      primaryColor: themeProps.primaryColor,
    );
    final colorScheme =
        (brightness == Brightness.dark
                ? baseColorScheme.toPureBlack(themeProps.pureBlack)
                : baseColorScheme)
            .copyWith(
              primary: themeProps.dynamicColor ? null : surge.primary,
              onPrimary: themeProps.dynamicColor ? null : Colors.white,
              primaryContainer: themeProps.dynamicColor
                  ? null
                  : const Color(0xFFF1F2F5),
              onPrimaryContainer: themeProps.dynamicColor
                  ? null
                  : surge.textPrimary,
              secondary: themeProps.dynamicColor ? null : surge.textSecondary,
              secondaryContainer: themeProps.dynamicColor
                  ? null
                  : const Color(0xFFF1F2F5),
              onSecondaryContainer: themeProps.dynamicColor
                  ? null
                  : surge.textPrimary,
              tertiaryContainer: themeProps.dynamicColor
                  ? null
                  : const Color(0xFFF1F2F5),
              onTertiaryContainer: themeProps.dynamicColor
                  ? null
                  : surge.textPrimary,
              surface: themeProps.dynamicColor ? null : surge.card,
              surfaceContainerLowest: themeProps.dynamicColor
                  ? null
                  : surge.card,
              surfaceContainerLow: themeProps.dynamicColor ? null : surge.card,
              surfaceContainer: themeProps.dynamicColor
                  ? null
                  : surge.background,
              surfaceContainerHigh: themeProps.dynamicColor ? null : surge.card,
              surfaceContainerHighest: themeProps.dynamicColor
                  ? null
                  : surge.textSecondary.withValues(alpha: 0.14),
              outline: themeProps.dynamicColor ? null : surge.separator,
              outlineVariant: themeProps.dynamicColor ? null : surge.separator,
            );
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      extensions: [_getSurgeTheme(brightness)],
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
        titleTextStyle: TextStyle(
          color: surge.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      navigationBarTheme: _getNavigationBarTheme(surge),
      switchTheme: _getSwitchTheme(surge),
      radioTheme: _getRadioTheme(surge, themeProps),
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
              value: _getSystemUiOverlayStyle(currentBrightness),
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
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (globalState.navigatorKey.currentContext != null) {
        await globalState.attach();
      } else {
        exit(0);
      }
      _autoUpdateProfilesTask();
      _initLink();
      app?.initShortcuts();
    });
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
              style: TextStyle(
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
      await ref.read(profilesActionProvider.notifier).autoUpdateProfiles();
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
            ref.read(systemActionProvider.notifier).updateLocalIp();
            final hasVpn = results.contains(ConnectivityResult.vpn);
            if (_preHasVpn == hasVpn) {
              ref.read(checkIpNumProvider.notifier).add();
            }
            _preHasVpn = hasVpn;
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
  Future<void> dispose() async {
    linkManager.destroy();
    _autoUpdateProfilesTaskTimer?.cancel();
    await coreController.destroy();
    await ref.read(systemActionProvider.notifier).handleExit();
    super.dispose();
  }
}
