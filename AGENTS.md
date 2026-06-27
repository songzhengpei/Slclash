# AGENTS.md

This is a private Android-only fork of FlClash. Keep this file short and practical: it should preserve the constraints and project knowledge that prevent repeated investigation.

## Project Scope

- Target platform: Android only.
- Target ABI: `arm64-v8a` only.
- Flutter app code: `lib/`.
- Android native project: `android/`.
- Go core wrapper: `core/`.
- Android Go shared library outputs:
  - `libclash/android/arm64-v8a/libclash.so`
  - `android/core/src/main/jniLibs/arm64-v8a/libclash.so`
- Required local plugins:
  - `plugins/setup/`
  - `plugins/wifi_ssid/`
  - `core/Clash.Meta` submodule

Do not reintroduce desktop platforms, desktop plugins, Rust IPC helpers, system tray, desktop hotkeys, desktop system proxy, distributor packaging, or non-arm64 Android ABIs unless the project scope explicitly changes.

## Local Environment

Use the local environment before building:

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

Important local caches live under `.dev-tools/`; keep them because they make builds much faster.

## Branch And Commands

- Local development branch: `beta`.
- Stable/release flow: merge `beta` into `main`, push `main`, then tag.
- For Go core changes, work on `beta`; if `go.mod` or `go.sum` changes, run `go mod tidy`.

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

`flutter analyze` may report existing Flutter deprecation `info` diagnostics. Treat new errors or warnings as blockers; do not fail a task only because of the known info-level deprecations.

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

The build tool compiles the Go core as a CGO shared library with `go build -buildmode=c-shared`.

## Runtime Proxy Data

There are two Go-side proxy sources:

| Source | Content |
|--------|---------|
| `tunnel.Proxies()` | Direct `proxies:` plus `proxy-groups` |
| `tunnel.Providers()` | Downloaded `proxy-providers:` nodes |

Frontend node features should use runtime merged data, not `Group.all` search-word filtering:

```text
handleGetProxies()
  -> ProxiesData.proxies
  -> coreController.getRuntimeLeafProxies()
  -> getLeafProxiesFromProxiesData()
```

Key files:

- Go merge/filter source: `core/hub.go`
- Dart runtime resolver: `lib/core/controller.dart`
- Leaf-node filtering: `lib/common/profile_proxy_resolver.dart`

Leaf-node filtering must exclude:

- Built-ins such as `DIRECT`, `REJECT`, `GLOBAL`, `PASS`, `PASS-RULE`, `COMPATIBLE`, `REJECT-DROP`
- Proxy group types such as `select`, `url-test`, `fallback`, `load-balance`, `relay`, `PassRule`
- Names containing direct-routing text such as `直连` or `DIRECT`
- Nested group references

`resolveProfileProxies(profileId)` is still useful for inactive/offline profile data because it reads the profile config plus provider cache files. Active runtime screens should prefer `getRuntimeLeafProxies()`.

## Media Check

Main files:

- Page/UI: `lib/views/profiles/media_check.dart`
- Shared data/cache/settings: `lib/common/media_check_data.dart`
- Go check logic: `core/media_check.go`
- Tests: `test/views/profiles/media_check_test.dart`, `core/media_check_test.go`

Behavior constraints:

- Opening the media-check page must not automatically start GPT or YouTube detection.
- Manual detection targets one selected subscription and one selected mode.
- Keep `GPT`, `YouTube`, and `health` independent.
- Health mode is delay/HTTPS health sampling only; it must not run GPT or YouTube unlock checks.
- Cache entries are mode-aware; clearing one mode must not wipe other mode results for the same node.
- The subscription selector must reload targets for the selected subscription.
- Result lists should stay bounded in height and scroll internally when many nodes are shown.
- UI wording should stay compact: use `GPT`, `YouTube`, `解锁(US)`, `阻断`, etc.

## Health Observation

Health observation is intended to run while the app is alive, regardless of system proxy state or smart-pause state. Android background limitations are acceptable, but the app should keep trying in foreground/background when the scheduler is due and enabled.

Current strategy:

- Scheduler: `lib/providers/health_observation.dart`
- Settings/cache: `lib/common/media_check_data.dart`
- Targets: selected subscription, resolved through `coreController.getRuntimeLeafProxies()`
- Each automatic round tests all eligible nodes for the selected subscription.
- Manual health checks ignore observation cooldown.
- Automatic health checks skip nodes temporarily cooled down by bad history.
- Bounded concurrency is used to avoid one-by-one long runs.

Cooldown policy:

- Cool down a node for 24 hours after repeated timeout/failure or repeated high latency.
- Current slow threshold: `observeSlowDelayThreshold = 1500`.
- Current cooldown duration: `observeCooldownDuration = 24h`.
- Healthy low-latency samples clear the bad/slow streaks.
- Debug builds allow a 2-minute observation interval for testing; release/profile builds do not.

Avoid reintroducing a long idle-only gate unless explicitly requested. If the scheduler behavior changes, update this section and the related tests together.

## Debugging Shortcuts

If provider nodes are missing or tests return timeout unexpectedly, check this path first:

1. `handleGetProxies()` in `core/hub.go` includes both `tunnel.Proxies()` and `tunnel.Providers()`.
2. `ProxiesData.proxies` contains the node name before Dart parsing.
3. `getLeafProxiesFromProxiesData()` does not filter out a real node by type/name.
4. `coreController.getDelay()` / `handleAsyncTestDelay` can find provider nodes.
5. `mediaCheck()` / Go media check can resolve provider nodes through runtime or provider fallback.

Use `adb logcat` with the app's `commonPrint` output when investigating runtime data.
