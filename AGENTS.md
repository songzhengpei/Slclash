# AGENTS.md

This repository is a private Android-only fork of FlClash. Treat Android `arm64-v8a` as the only supported target.

## Project Scope

- Platform target: Android only
- ABI target: `arm64-v8a` only
- Flutter app code lives in `lib/`
- Android native project lives in `android/`
- Go core wrapper lives in `core/`
- Android Go shared library output lives in `libclash/android/arm64-v8a/`
- Local Flutter plugin build hook lives in `plugins/setup/`
- Wi-Fi SSID plugin lives in `plugins/wifi_ssid/`

Desktop platforms, desktop plugins, Rust helper IPC, system tray, desktop hotkeys, desktop system proxy, and distributor packaging have been removed.

## Local SDKs

| Tool | Path |
|------|------|
| Flutter SDK | `D:\Code\Tools\flutter` |
| Go SDK | `D:\Code\Tools\Go\go` |
| Android SDK | `D:\Code\Tools\Android\Sdk` |
| Android NDK | `D:\Code\Tools\Android\Sdk\ndk\28.2.13676358` |
| ADB | `D:\Code\Tools\Android\Sdk\platform-tools\adb.exe` |

## Environment

Use the local environment scripts before building:

```powershell
dev-env.bat
```

or in WSL:

```bash
source dev-env.sh
```

Important variables:

| Variable | Value |
|----------|-------|
| `GRADLE_USER_HOME` | `D:\Code\Clash myself\FlClash-dev\.dev-tools\gradle` |
| `GOPATH` | `D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg` |
| `GOMODCACHE` | `D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg\mod` |
| `PUB_CACHE` | `D:\Code\Clash myself\FlClash-dev\.dev-tools\pub-cache` |
| `ANDROID_HOME` | `D:\Code\Tools\Android\Sdk` |
| `ANDROID_NDK` | `D:\Code\Tools\Android\Sdk\ndk\28.2.13676358` |

## Common Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --target-platform android-arm64
```

The Android Gradle/buildkit setup defaults to `arm64-v8a`; use `--target-platform android-arm64` anyway so Flutter's own target selection is explicit.

## Go Core Build

Android builds invoke `plugins/setup/buildkit/gradle/plugin.gradle`, which runs the Dart build tool in `plugins/setup/buildkit/build_tool/`.

The build tool now supports only:

```powershell
dart run build_tool android
dart run build_tool android --arch arm64
dart run build_tool android --target-platform android-arm64
```

It compiles the Go core as a CGO shared library and copies outputs to:

- `libclash/android/arm64-v8a/libclash.so`
- `android/core/src/main/jniLibs/arm64-v8a/libclash.so`
- `android/core/src/main/cpp/includes/arm64-v8a/`

## Code Generation

Run this after modifying generated models, providers, or Drift schema:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Generated code covers Riverpod providers, Freezed/JSON models, and Drift database files.

## Testing Notes

- Use `flutter test`, not `dart test`, because models and providers use Flutter types.
- Root tests live under `test/`.
- `CoreController.test(mock)` can inject a mocked `CoreHandlerInterface`.
- Call `CoreController.resetInstance()` in `tearDown` when testing the singleton.
- For nested Freezed model round trips, test through `jsonEncode`/`jsonDecode`.

## Architecture Notes

Android uses Go core in library mode:

- Go builds `libclash.so` with `go build -buildmode=c-shared`
- Flutter talks to Android native service code through method channels and FFI-facing interfaces
- Dart Android core implementation is `lib/core/lib.dart`
- `lib/core/controller.dart` directly uses `coreLib`

Desktop `CoreService`, Rust IPC transport, named pipes, system tray, desktop windows, and desktop proxy managers are intentionally absent.

## Keep

- Keep `.dev-tools/`; it stores local build caches and speeds rebuilds.
- Keep `plugins/setup/`; it is still required for Android Go core builds.
- Keep `plugins/wifi_ssid/`; it has the Android Wi-Fi SSID implementation.
- Keep `core/Clash.Meta` submodule.

## Avoid

- Do not reintroduce desktop platform directories unless the project scope changes.
- Do not add non-arm64 Android ABIs unless the target device requirements change.
- Do not use `setup.dart`; it has been removed with distributor packaging.
