# AGENTS.md

Private Android-only FlClash fork for personal mobile use. Keep agent work narrow, concise, and aligned with this scope.

## Scope

- Android only; ABI only `arm64-v8a`.
- App code: `lib/`; Android native project: `android/`; Go core wrapper: `core/`.
- Required local components: `plugins/setup/`, `plugins/wifi_ssid/`, `core/Clash.Meta`.
- Do not reintroduce desktop platforms/plugins, Rust IPC helpers, system tray, desktop hotkeys, desktop system proxy, distributor packaging, or non-arm64 Android ABIs unless scope changes.
- Main local development branch: `beta`. Stable flow: merge `beta` into `main`, push `main`, then tag.

## Environment

Project path contains a space; use quoted paths or PowerShell `Set-Location -LiteralPath`.

```powershell
$env:Path = "D:\Code\Tools\Go\go\bin;D:\Code\Tools\flutter\bin;D:\Code\Tools\Android\Sdk\platform-tools;$env:Path"
$env:GRADLE_USER_HOME = "D:\Code\Clash myself\FlClash-dev\.dev-tools\gradle"
$env:GOPATH = "D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg"
$env:GOMODCACHE = "D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg\mod"
$env:PUB_CACHE = "D:\Code\Clash myself\FlClash-dev\.dev-tools\pub-cache"
$env:ANDROID_HOME = "D:\Code\Tools\Android\Sdk"
$env:ANDROID_NDK = "D:\Code\Tools\Android\Sdk\ndk\28.2.13676358"
```

Tool roots: Flutter `D:\Code\Tools\flutter`, Go `D:\Code\Tools\Go\go`, Android SDK `D:\Code\Tools\Android\Sdk`, ADB `D:\Code\Tools\Android\Sdk\platform-tools\adb.exe`.

Keep `.dev-tools/`; it stores local Gradle/Go/Pub caches that make builds faster.

## Commands

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --split-per-abi --target-platform android-arm64
D:\Code\Tools\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
```

- Run `build_runner` only after changing generated models, Riverpod providers, or Drift schema, and always after `flutter pub get` but before `flutter analyze`.
- Do not edit generated files in `lib/providers/generated/` or `lib/models/generated/`; edit their sources.
- `flutter analyze` may include existing info-level deprecations. New errors or warnings block completion.
- Focused checks: `flutter test test\views\profiles\media_check_test.dart`; in `core/`, `go test ./...`.
- If Go core dependencies change, run `go mod tidy` in `core/`.
- If Go submodule is missing, run `git submodule update --init --recursive`.
- If Gradle stalls for over 5 minutes with no output, retry after stopping stale `java`, `dart`, and `dartvm` processes.

## Android / Go Build

- Android build has two stages: Go core via `plugins/setup/buildkit/gradle/plugin.gradle`, then Flutter/APK packaging.
- Direct Go core build: `dart run build_tool android --arch arm64`.
- Go shared libraries:
  - `libclash/android/arm64-v8a/libclash.so` for CI output.
  - `android/core/src/main/jniLibs/arm64-v8a/libclash.so` for local Gradle packaging.

## CI

Beta workflow: `.github/workflows/slclash-android-beta.yml`.

```powershell
gh workflow run slclash-android-beta.yml --ref beta -f tag="YYYY.MM.DD-beta"
```

Tag format must be `YYYY.MM.DD-beta`.

## Behavior Notes

- Prefer runtime merged proxy data from `coreController.getRuntimeLeafProxies()`, including provider nodes.
- Media detection modes stay independent: `GPT`, `YouTube`, and `health` must not trigger each other.
- Opening the media-check page must not automatically start GPT or YouTube detection.
- Health checks should use bounded concurrency, cache results, and avoid repeatedly testing cooled-down bad nodes.
- Smart pause is Android-focused and tied to trusted IP/CIDR networks.
- When behavior changes, update related tests.
