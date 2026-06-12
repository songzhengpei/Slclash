# SlClash

SlClash 是基于 FlClash 私有裁剪和重设计的 Android 代理客户端，面向自用移动端场景。项目保留 Clash Meta 内核能力、订阅管理、代理组选择、Provider 同步、流量与连接状态展示，并围绕 Android 手机端重新整理了界面与发布流程。

## 项目定位

- 仅支持 Android。
- 仅支持 `arm64-v8a` ABI。
- 不包含桌面端、系统托盘、桌面热键、桌面系统代理、Rust IPC、分发器打包等能力。
- Go core 以 Android shared library 方式集成，Flutter 通过 Android 原生服务与 FFI 相关接口调用。

## 当前特性

- Surge-like 移动端首页，展示当前订阅、连接状态、流量、速率和网络概览。
- 代理页固定列表模式，支持代理组展开、当前节点选择、单节点延迟测试和整组延迟测试。
- 配置页支持当前订阅展开查看全部节点，并可一键测试当前订阅全部节点延迟。
- Provider 页支持批量同步、单个同步和本地上传。
- 订阅管理使用底部 sheet，支持二维码、文件、URL 添加和拖动排序。
- Android release 通过 GitHub Actions 构建 `arm64-v8a` split APK 并发布到 GitHub Release。

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `lib/` | Flutter 应用代码 |
| `android/` | Android 原生工程 |
| `core/` | Go core wrapper 与 Clash.Meta 子模块 |
| `libclash/android/arm64-v8a/` | Android arm64 Go shared library 输出 |
| `plugins/setup/` | 本地 Flutter plugin build hook，用于 Go core 构建 |
| `plugins/wifi_ssid/` | Android Wi-Fi SSID 插件 |

## 本地环境

本仓库使用本地 SDK 和仓库内缓存目录：

| 工具 | 路径 |
| --- | --- |
| Flutter SDK | `D:\Code\Tools\flutter` |
| Go SDK | `D:\Code\Tools\Go\go` |
| Android SDK | `D:\Code\Tools\Android\Sdk` |
| Android NDK | `D:\Code\Tools\Android\Sdk\ndk\28.2.13676358` |
| ADB | `D:\Code\Tools\Android\Sdk\platform-tools\adb.exe` |

构建前加载环境：

```powershell
dev-env.bat
```

或在 WSL 中：

```bash
source dev-env.sh
```

## 常用命令

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --target-platform android-arm64
```

本地 debug 构建并安装：

```powershell
cmd /c "cd /d D:\Code\Clash myself\FlClash-dev && set JAVA_HOME=D:\Code\Tools\Java\jdk-21.0.11+10&& call dev-env.bat && D:\Code\Tools\flutter\bin\flutter.bat build apk --debug --target-platform android-arm64 && D:\Code\Tools\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk"
```

## Go Core 构建

Android 构建会调用 `plugins/setup/buildkit/gradle/plugin.gradle`，再运行 `plugins/setup/buildkit/build_tool/` 下的 Dart 构建工具。

当前只支持：

```powershell
dart run build_tool android
dart run build_tool android --arch arm64
dart run build_tool android --target-platform android-arm64
```

构建产物会写入：

- `libclash/android/arm64-v8a/libclash.so`
- `android/core/src/main/jniLibs/arm64-v8a/libclash.so`
- `android/core/src/main/cpp/includes/arm64-v8a/`

## 代码生成

修改 Freezed/JSON model、Riverpod provider 或 Drift schema 后运行：

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## 发布

推送形如 `v1.1.0` 的 tag 会触发 `.github/workflows/slclash-android-release.yml`。

Workflow 会执行：

- 安装 Flutter、Go、JDK、Android NDK。
- 运行 `flutter analyze --no-fatal-infos`。
- 构建 Android `arm64-v8a` release split APK。
- 上传 workflow artifact。
- 发布 GitHub Release。

Release APK 命名格式：

```text
SlClash-vX.Y.Z-arm64-v8a.apk
```

最新发布可在 [GitHub Releases](https://github.com/songzhengpei/Slclash/releases) 查看。

## 维护说明

- `.dev-tools/` 存放本地构建缓存，应保留。
- `plugins/setup/` 仍是 Android Go core 构建链路的一部分，应保留。
- `plugins/wifi_ssid/` 提供 Android Wi-Fi SSID 能力，应保留。
- `core/Clash.Meta` 是内核子模块，应保留。
- 不要重新引入桌面平台目录或非 `arm64-v8a` ABI，除非项目目标发生变化。

## 致谢

本项目基于 FlClash 和 Clash.Meta 生态裁剪、适配与重设计。当前仓库是面向自用 Android 设备的私有发布线。
