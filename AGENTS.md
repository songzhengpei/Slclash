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
# 方法 1: cmd.exe 链式调用（推荐）
cmd /c "D:\Code\Clash myself\FlClash-dev\dev-env.bat && cd /d D:\Code\Clash myself\FlClash-dev && flutter build apk ..."

# 方法 2: PowerShell 直接设环境变量
$env:Path = "D:\Code\Tools\Go\go\bin;D:\Code\Tools\flutter\bin;D:\Code\Tools\Android\Sdk\platform-tools;$env:Path"
$env:GRADLE_USER_HOME = "D:\Code\Clash myself\FlClash-dev\.dev-tools\gradle"
$env:GOPATH = "D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg"
$env:GOMODCACHE = "D:\Code\Clash myself\FlClash-dev\.dev-tools\go-pkg\mod"
$env:PUB_CACHE = "D:\Code\Clash myself\FlClash-dev\.dev-tools\pub-cache"
$env:ANDROID_HOME = "D:\Code\Tools\Android\Sdk"
$env:ANDROID_NDK = "D:\Code\Tools\Android\Sdk\ndk\28.2.13676358"
```

**注意：** `dev-env.bat` 在 PowerShell 中直接执行不会使环境变量持久化到当前会话。
如果想省事，可以先把 `flutter`、`go`、`adb` 加到系统 PATH 中。

项目路径含空格 `Clash myself`，cmd.exe 链式调用时要用引号包好。推荐用 PowerShell + 内联 $env 的方式。

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
# ====== 标准流程（修改代码后） ======
flutter pub get

# 如果修改了 freezed 模型 / Riverpod provider / Drift schema，先跑代码生成
dart run build_runner build --delete-conflicting-outputs

# 静态分析（info 级 deprecation 可以接受，新 error/warning 必须修）
flutter analyze

# 构建 debug APK（arm64-v8a）
flutter build apk --debug --target-platform android-arm64

# 安装到设备
D:\Code\Tools\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk

# 构建 release APK（arm64-v8a 单 ABI）
flutter build apk --release --split-per-abi --target-platform android-arm64

# ====== 构建注意事项 ======

# 首次构建或 Go core 更新后，编译 libclash.so 需要 ~5-10 分钟
# 后续增量构建通常 < 2 分钟

# 如果 Gradle 卡死或无响应（输出文件超过 5 分钟无变化），杀掉进程重试：
Get-Process -Name "java","dart","dartvm" -ErrorAction SilentlyContinue | Stop-Process -Force

# 如果 Go 编译失败，检查 core/Clash.Meta 子模块是否正确初始化
git submodule update --init --recursive

# Gradle/Kotlin 版本警告不影响构建，可安全忽略

Focused checks:

```powershell
flutter test test\views\profiles\media_check_test.dart
cd core
go test ./...
```

`flutter analyze` may report existing Flutter deprecation `info` diagnostics. Treat new errors or warnings as blockers; do not fail a task only because of known info-level deprecations.

Run code generation after changing generated models, providers, or Drift schema.
**必须在 `flutter pub get` 之后、`flutter analyze` 之前运行：**

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

`build_runner` 会生成 ~500+ 个输出文件（`*.g.dart`、`*.freezed.dart`），首次运行耗时 ~1.5 分钟。

**注意：** `build_runner` 会更新 `lib/providers/generated/` 和 `lib/models/generated/` 中的文件。如果手动修改了这些生成文件会被覆盖，请改源文件（`lib/providers/app.dart`、`lib/models/state.dart` 等）。

## Android / Go Core Build

### 构建流程

Android 构建分两个阶段：

1. **Go core 编译** — Gradle plugin (`plugins/setup/buildkit/gradle/plugin.gradle`) 调用 Dart build tool 编译 Clash core
2. **Flutter/Dart 编译 + APK 打包** — 标准 `flutter build` 流程

第一阶段耗时最长（5-10 分钟），第二阶段通常 1-2 分钟。

Build tool 支持直接调用：

```powershell
dart run build_tool android --arch arm64
```

如果只需要调试 Flutter 代码、Go core 未改动，可以跳过 Go 编译直接打包 Flutter：
```powershell
flutter build apk --debug --target-platform android-arm64
```
（Gradle 会判断 `libclash.so` 是否存在，存在则跳过编译）

### Go 共享库输出

- `libclash/android/arm64-v8a/libclash.so` — CI 构建产物
- `android/core/src/main/jniLibs/arm64-v8a/libclash.so` — 本地 Gradle 打包用（build_runner 自动复制）

### 常见构建失败

| 症状 | 原因 | 解决 |
|------|------|------|
| `dev-env.bat` 执行后 flutter 找不到 | PowerShell 不继承 cmd 环境变量 | 用 `cmd /c` 链式调用或手设 $env |
| Gradle 卡在 `assembleDebug` 无输出 | 上一个 daemon 未清理 | `Stop-Process -Name "java" -Force` 重试 |
| `go: command not found` | Go 不在 PATH | 检查 dev-env.bat 或手设 $env:Path |
| `build_runner` 输出 `hasChecked` 找不到 | 模型修改后未重新生成 | 先 `dart run build_runner build` |
| 构建成功 APK 未生成 | Gradle 输出路径不同 | 检查 `build/app/outputs/flutter-apk/` |

## CI / CD

Beta release 通过 GitHub Actions 自动构建。工作流文件：`.github/workflows/slclash-android-beta.yml`

```powershell
# 触发 beta 构建（自动打 tag + 编译 + 发布 GitHub Release）
gh workflow run slclash-android-beta.yml --ref beta -f tag="YYYY.MM.DD-beta"
```

Tag 格式必须为 `YYYY.MM.DD-beta`（例如 `2026.07.04-beta`）。构建完成后：
1. APK 上传为 workflow artifact
2. 自动创建 GitHub Release（prerelease）

如果需要手动下载 APK：`gh run download <run-id>`

## Implementation Notes

- Active runtime node features should prefer runtime merged proxy data from `coreController.getRuntimeLeafProxies()`, including provider nodes.
- Media detection modes must stay independent: `GPT`, `YouTube`, and `health` should not trigger each other.
- Opening the media-check page must not automatically start GPT or YouTube detection.
- Health checks should use bounded concurrency, cache results, and avoid repeatedly testing cooled-down bad nodes.
- Smart pause is Android-focused and should remain tied to trusted IP / CIDR networks.

When behavior changes, update the related tests with the implementation.
