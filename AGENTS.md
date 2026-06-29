# AGENTS.md

This is a private Android-only fork of FlClash, redesigned and trimmed for personal mobile use. Keep this file short: it should tell agents how to build, where tools are, and which project boundaries must not be crossed.

## Project Scope

- Target platform: Android only.
- Target ABI: `arm64-v8a` only.
- Flutter app code: `lib/`.
- Android native project: `android/`.
- Go core wrapper: `core/`.
- Required local components:
  - `plugins/setup/`
  - `plugins/wifi_ssid/`
  - `core/Clash.Meta` submodule

Do not reintroduce desktop platforms, desktop plugins, Rust IPC helpers, system tray, desktop hotkeys, desktop system proxy, distributor packaging, or non-arm64 Android ABIs unless the project scope explicitly changes.

## Local Environment

Load the local environment before building:

```powershell
dev-env.bat
```

Local tools:

| Tool | Path |
|------|------|
| Flutter | `D:\Code\Tools\flutter` |
| Go | `D:\Code\Tools\Go\go` |
| Android SDK | `D:\Code\Tools\Android\Sdk` |
| Android NDK | `D:\Code\Tools\Android\Sdk\ndk\28.2.13676358` |
| ADB | `D:\Code\Tools\Android\Sdk\platform-tools\adb.exe` |

Keep `.dev-tools/`; it stores local caches that make builds faster.

## Branch And Commands

- Main local development branch: `beta`.
- Stable/release flow: merge `beta` into `main`, push `main`, then tag.
- If Go core dependencies change, run `go mod tidy` in `core/`.

Common commands:

```powershell
flutter pub get
flutter test
flutter analyze
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --target-platform android-arm64
D:\Code\Tools\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
```

Focused checks:

```powershell
flutter test test\views\profiles\media_check_test.dart
cd core
go test ./...
```

`flutter analyze` may report existing Flutter deprecation `info` diagnostics. Treat new errors or warnings as blockers; do not fail a task only because of known info-level deprecations.

Run code generation after changing generated models, providers, or Drift schema:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Android / Go Core Build

Android builds invoke `plugins/setup/buildkit/gradle/plugin.gradle`, which runs the Dart build tool in `plugins/setup/buildkit/build_tool/`.

Supported build-tool targets:

```powershell
dart run build_tool android
dart run build_tool android --arch arm64
dart run build_tool android --target-platform android-arm64
```

The Go shared library outputs are:

- `libclash/android/arm64-v8a/libclash.so`
- `android/core/src/main/jniLibs/arm64-v8a/libclash.so`

## Implementation Notes

- Active runtime node features should prefer runtime merged proxy data from `coreController.getRuntimeLeafProxies()`, including provider nodes.
- Media detection modes must stay independent: `GPT`, `YouTube`, and `health` should not trigger each other.
- Opening the media-check page must not automatically start GPT or YouTube detection.
- Health checks should use bounded concurrency, cache results, and avoid repeatedly testing cooled-down bad nodes.
- Smart pause is Android-focused and should remain tied to trusted IP / CIDR networks.

When behavior changes, update the related tests with the implementation.
