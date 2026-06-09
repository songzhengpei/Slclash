# AGENTS.md

This file provides guidance for AI coding agents working with code in this repository.

## Project Overview

FlClash is a multi-platform proxy client based on ClashMeta (mihomo), built with Flutter. Supports Android, Windows,
macOS, and Linux. Material You design with Surfboard-like UI.

## Common Development Commands

### Building

```bash
# Update submodules first (ClashMeta Go core lives in core/Clash.Meta/)
git submodule update --init --recursive

# Full package build (Go core + Flutter + packaging) via setup.dart
dart setup.dart macos
dart setup.dart linux
dart setup.dart windows
dart setup.dart android

# Build only the Go core (skip Flutter packaging)
bash plugins/setup/buildkit/run_build_tool.sh macos
bash plugins/setup/buildkit/run_build_tool.sh linux
bash plugins/setup/buildkit/run_build_tool.sh windows
bash plugins/setup/buildkit/run_build_tool.sh android
```

### Flutter Development

```bash
# Project is pinned with FVM (.fvmrc currently uses Flutter 3.35.7)
fvm flutter pub get
fvm flutter run
fvm flutter test

# Plain Flutter also works when your global SDK matches the project constraints
flutter pub get
flutter run        # Run on connected device/desktop
flutter test        # Run all tests (use flutter test, not dart test — models pull in Flutter types)
```

### Code Generation

Required after modifying models, providers, or database schema:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch  # Continuous regeneration
```

Code generation covers: Riverpod providers (`riverpod_generator`), models (`freezed`, `json_serializable`), and database
tables (`drift_dev`).

### Testing

Tests use `package:test/test.dart` for pure Dart logic (common utils, models) and `flutter_test` for provider/widget tests.
`mocktail` is the mocking framework.

```bash
flutter test test/models/      # Model serialization & extension round-trip tests
flutter test test/core/        # CoreController tests (mocked CoreHandlerInterface)
flutter test test/providers/   # Riverpod provider tests (config & app state notifiers)
flutter test test/common/      # Utility function tests (utils, string, iterable, fixed, etc.)
flutter test test/database/    # Database type converter tests
flutter test test/widgets/     # Widget-level rendering/interaction tests
flutter test test/setup_test.dart
flutter test plugins/proxy/test/proxy_test.dart  # Dart tests for bundled plugin packages
```

Root `flutter test` only discovers the root package's `test/` directory by default. Include bundled plugin Dart tests by
passing their paths explicitly, or run `flutter test` from that plugin package directory. Native plugin tests under
platform folders (for example Windows C++ tests) are not run by `flutter test`.

**Mocking `CoreHandlerInterface`:** Use `CoreController.test(mock)` to inject a mock interface. Call
`CoreController.resetInstance()` in `tearDown` to clean up the singleton between tests. Remember to
`registerFallbackValue()` for freezed params used with `any()` matchers.

**Provider tests:** Use `ProviderContainer` directly (no widget tree needed for simple notifiers). The Riverpod
generated `update()` method takes a callback: `notifier.update((state) => newValue)`.

**Model round-trip tests:** Always go through `jsonEncode`/`jsonDecode` when testing freezed models with
nested objects — `toJson()` stores child objects directly (not as maps), so direct `fromJson(toJson())`
fails for nested freezed types.

### Build Dependencies

**Linux:** `sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev`

**Windows:** GCC and Inno Setup. `ANDROID_NDK` env var for Android builds.

**macOS:** `npm install -g appdmg` for DMG creation.

### Windows Android Debug Build Notes

On this workspace, `flutter`, `dart`, `adb`, and `go` may not be on `PATH` even though they are installed. Prefer these
known local tool paths when plain commands are not found:

```powershell
D:\Code\Tools\flutter\bin\flutter.bat
D:\Code\Tools\flutter\bin\dart.bat
D:\Code\Tools\Android\Sdk\platform-tools\adb.exe
D:\Code\Tools\Go\go\bin\go.exe
```

Android debug builds trigger the `plugins/setup` Gradle hook, which builds the Go ClashMeta core before Flutter packages
the APK. The build tool reads `ANDROID_NDK` directly from the environment; `android/local.properties` with `sdk.dir` is
not enough. If `ANDROID_NDK` is missing, the failure looks like:

```txt
PathNotFoundException: Directory listing failed, path = 'null\toolchains\llvm\prebuilt\*'
Execution failed for task ':setup:buildGoCore'
```

Use a one-shot environment setup when building from PowerShell:

```powershell
Set-Location -LiteralPath 'D:\Code\Clash myself\FlClash-dev'
$env:ANDROID_NDK='D:\Code\Tools\Android\Sdk\ndk\28.2.13676358'
$env:PATH='D:\Code\Tools\Go\go\bin;' + $env:PATH
& 'D:\Code\Tools\flutter\bin\flutter.bat' build apk --debug
```

If `go` is missing from `PATH`, the Go core step fails with:

```txt
'go' is not recognized as an internal or external command
Command failed: go build ...
```

To install the debug build on the connected phone:

```powershell
& 'D:\Code\Tools\Android\Sdk\platform-tools\adb.exe' devices
& 'D:\Code\Tools\Android\Sdk\platform-tools\adb.exe' -s 0604B44041A00540 install -r 'build\app\outputs\flutter-apk\app-debug.apk'
& 'D:\Code\Tools\Android\Sdk\platform-tools\adb.exe' -s 0604B44041A00540 shell monkey -p com.follow.clash.dev -c android.intent.category.LAUNCHER 1
```

The debug application id is `com.follow.clash.dev`; release/fallback release builds may use a different suffix depending
on signing config. First-time Go dependency downloads can make the Android build take several minutes. Flutter commands
can also refresh platform generated plugin registrant files or line endings; check `git diff` content before treating
those generated files as intentional source changes.

## Architecture

### Core Integration (Go ClashMeta <-> Flutter)

This is the most important architectural concept. The Go proxy core (`core/`) operates in two modes:

- **Android (lib mode):** Go core compiled as C shared library (`libclash.so`) via `go build -buildmode=c-shared` with
  CGO. Flutter calls it via FFI through the `service` plugin. Dart-side: `lib/core/lib.dart` (`CoreLib` class).

- **Desktop (core mode):** Go core runs as a separate process with `CGO_ENABLED=0`. Flutter communicates via
  JSON-over-socket (Unix socket on macOS/Linux, TCP on Windows). Dart-side: `lib/core/service.dart` (`CoreService`
  class).

`lib/core/controller.dart` (`CoreController`) selects the implementation based on platform. `lib/core/interface.dart`
defines the shared `CoreHandlerInterface`.

Go core key files: `core/hub.go` (handler functions), `core/action.go` (dispatch), `core/lib.go` (CGO exports),
`core/server.go` (socket server).

### State Management (Riverpod)

Provider files in `lib/providers/`:

- `app.dart` - Runtime/UI state (logs, traffic, delays, loading, navigation)
- `config.dart` - Persistent config providers (app settings, theme, VPN, proxy style)
- `state.dart` - Derived/computed providers (navigation, proxy, tray, color scheme)
- `action.dart` - Business logic notifiers (setup, backup, core lifecycle, proxy selection)
- `database.dart` - Drift database provider wrappers

`globalState` (`lib/state.dart`) is a singleton holding app lifecycle, timers, theme, and the start/stop state.
Providers are generated into `lib/providers/generated/`.

### Database (Drift/SQLite)

Type-safe SQLite via Drift in `lib/database/`. Current schema version is 2. Tables are `Profiles`, `Scripts`, `Rules`,
`ProfileRuleLinks` (`profile_rule_mapping`), `ProxyGroups`, and `IconRecords` (`icon_records`). Rule scenes distinguish
global added rules, profile added rules, profile custom rules, and disabled links. Uses fractional indexing for rule and
proxy-group ordering.

Generated Drift output lives in `lib/database/generated/database.g.dart`. After schema changes, run code generation and
add/update focused database tests under `test/database/` when converter or migration behavior changes.

### Manager Stack (Widget Tree)

Managers are nested InheritedWidgets/StatefulWidgets in `lib/application.dart`:

```
AppEnvManager > StatusManager > ThemeManager
  > [Desktop: WindowManager > TrayManager > HotKeyManager > ProxyManager]
  > ConnectivityManager > CoreManager > AppStateManager
  > [Mobile: AndroidManager > VpnManager | Desktop: WindowHeaderContainer]
```

Each manager in `lib/manager/` handles a specific platform concern. Desktop-only managers are conditionally inserted.

### Core Controller + Actions

`lib/core/controller.dart` (`CoreController`) is a singleton facade over `CoreHandlerInterface`. All 25+ public methods
delegate to the platform-specific interface (Android FFI or desktop socket). Has `@visibleForTesting` constructor and
`resetInstance()` for test injection.

Business logic lives in Riverpod notifier classes in `lib/providers/action.dart` (~960 lines, should be split):

- `CommonAction` — update check, common UI operations
- `SetupAction` — config setup, TUN management
- `BackupAction` — backup/restore with WebDAV sync
- `CoreAction` — core lifecycle (init, connect, restart, shutdown)
- `SystemAction` — system integration (tray, exit, brightness)
- `StoreAction` — profile storage operations
- `ThemeAction` — theme state updates
- `ProxiesAction` — group management, proxy selection
- `ProfilesAction` — profile CRUD, auto-update, import

### Platform Managers (`lib/manager/`)

Desktop: `WindowManager`, `TrayManager`, `HotKeyManager`, `ProxyManager`
Mobile: `AndroidManager`, `TileManager`, `VpnManager`
Shared: `ConnectivityManager`, `CoreManager`, `AppStateManager`, `StatusManager`, `ThemeManager`

### Build System

`setup.dart` (project root) is the release build orchestrator:

1. On Windows, pre-builds Go core via `dart run build_tool windows` and reads `core_sha256.json`
2. Writes `env.json` (APP_ENV)
3. Passes SHA256 as `--dart-define=CORE_SHA256=$val` (compile-time embedded, secure; Windows only)
4. Activates `flutter_distributor` for packaging

Go core building is handled by `build_tool`, a standalone Dart CLI in `plugins/setup/buildkit/build_tool/`.
Platform build hooks inside `flutter build` trigger `build_tool` automatically:

- **macOS:** podspec script phase → `build_pod.sh` → `build_tool macos`
- **Linux:** CMake include → `buildkit/cmake/buildkit.cmake` → `build_tool linux`
- **Windows:** CMake include → `buildkit/cmake/buildkit.cmake` → `build_tool windows` (debug: `--dev` via `CMAKE_BUILD_TYPE`)
- **Android:** Gradle include → `buildkit/gradle/plugin.gradle` → `build_tool android`

**Windows helper auth (release):** Core SHA256 is embedded in both the Flutter app (`--dart-define`) and the Rust
helper (`TOKEN` env var during cargo build). The Dart app pings the helper and verifies the token matches.

**Windows helper auth (debug):** The Rust helper skips token verification when built in debug mode
(`cfg!(debug_assertions)`), so `flutter run` works without any SHA256 dance.

`plugins/setup/` is an FFI plugin that exists solely as a build harness — it carries no Dart API, only platform build hooks
(podspec, CMake, Gradle) that trigger Go compilation. Windows builds also compile a Rust helper (`services/helper/`) via
`RustBuilder`.

Build configuration defaults live in `build_tool/lib/src/options.dart` and can be overridden via `build_config.yaml`
in the project root.

Architecture detection is automatic (host arch via `uname -m` on Unix, `PROCESSOR_ARCHITECTURE` on Windows). The
`--description` flag passed to flutter_distributor adds arch suffix to artifact names (e.g.,
`FlClash-0.8.93-macos-arm64.dmg`).

### Local Plugins (`plugins/`)

- `setup` - Build harness FFI plugin (triggers Go/Rust compilation per platform)
- `proxy` - System proxy configuration
- `rust_api` - Flutter Rust Bridge FFI plugin (named pipe / local socket communication)
- `tray_manager` - System tray (forked/custom)
- `wifi_ssid` - Wi-Fi SSID detection
- `window_ext` - Window extensions
- `flutter_distributor` - App packaging/distribution

### Rust Helper Service (`services/helper/`)

Windows-only privileged helper for starting the core as admin and managing TUN. Built with
`cargo build --release --features windows-service`. Token-based auth with Flutter app.

### Localization

ARB files in `arb/`. Generated via `flutter_intl` into `lib/l10n/`. Use `AppLocalizations.of(context)!` for strings.

**Supported locales:** `en`, `zh_CN`, `ja`, `ru`

**Access patterns:**

- In widgets with BuildContext: `context.appLocalizations.key` (import `common.dart`)
- In controllers/providers/non-widget code: `currentAppLocalizations.key` (import `app_localizations.dart`)
