---
name: flutter-build
description: Run the full Flutter build pipeline for FlClash-dev (env setup → analyze → build → install)
---

# Flutter Build Pipeline

Execute the complete Flutter build workflow for the FlClash-dev Android project.

## Prerequisites

- Flutter SDK at `D:\Code\Tools\flutter`
- Go at `D:\Code\Tools\Go\go`
- Android SDK at `D:\Code\Tools\Android\Sdk`
- ADB at `D:\Code\Tools\Android\Sdk\platform-tools\adb.exe`

## Steps

All commands must run in the project directory `D:\Code\Clash myself\FlClash-dev`.

### 1. Set environment variables (PowerShell)

```powershell
$env:GRADLE_USER_HOME="D:\Code\Clash myself\FlClash-dev\.dev-tools\gradle"
$env:GOPATH="D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg"
$env:GOMODCACHE="D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg\mod"
$env:PUB_CACHE="D:\Code\Clash myself\FlClash-dev\.dev-tools\pub-cache"
$env:PATH="D:\Code\Tools\Go\go\bin;D:\Code\Tools\flutter\bin;D:\Code\Tools\Android\Sdk\platform-tools;" + $env:PATH
$env:ANDROID_HOME="D:\Code\Tools\Android\Sdk"
$env:ANDROID_NDK="D:\Code\Tools\Android\Sdk\ndk\28.2.13676358"
```

### 2. Run pipeline

```powershell
# Only if models/providers/Drift schema changed:
dart run build_runner build --delete-conflicting-outputs

# Always:
flutter analyze

# Build debug APK:
flutter build apk --debug --target-platform android-arm64

# Install:
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Variations

| Goal | Commands |
|------|----------|
| Quick check only | env → `flutter analyze` |
| After code gen changes | env → `build_runner` → `analyze` |
| Full build + install | env → `build_runner` (if needed) → `analyze` → `build apk` → `adb install` |
| Release build | Replace `--debug` with `--release` in build command |

## Notes

- `build_runner` takes ~20-75s depending on changes
- `flutter analyze` typically takes ~10-15s
- `flutter build apk --debug` takes ~40-200s (includes Go core build)
- ADB install requires a connected device via USB or wireless debugging
