# Phase 4 performance harness

Python + ADB harness for SlClash Phase 4. It records a baseline; it does **not** change startup, Core, VPN, Profile, or Proxy behavior.

Product baseline SHA: `b7e08b6ef84546e9b3d084a411c3a59e3e4df7c8`

## Command

```powershell
$env:Path = "D:\Code\Tools\Android\Sdk\platform-tools;$env:Path"
python tools/perf/phase4.py all
```

Subcommands: `env`, `cold-start`, `memory`, `jank`, `vpn`, `background`, `compare`.

```powershell
python tools/perf/phase4.py compare --baseline .perf-captures/phase4/old/result.json --current .perf-captures/phase4/latest.json
python -m unittest tools/perf/tests/test_harness.py
```

Options: `--package` (default `com.slclash.app.dev`), `--serial` / `ANDROID_SERIAL`, `--adb`, `--out`.

## What it measures

| Scenario | Method |
|---|---|
| env | `adb devices`, `getprop`, `dumpsys package`, `pidof` (Flutter + `:remote`) |
| cold-start | `am force-stop`, `am start -W`; warmup 2, measure 10; median / P90 / min / max |
| memory | `dumpsys meminfo` for app and `:remote` (PSS, Java/Native heap when present) |
| jank | `dumpsys gfxinfo reset` then `gfxinfo`; idle frames only, no UI automation |
| vpn | TempActivity `package.action.START` / `STOP`; service/tun/remote pid; ping probe |
| background | foreground vs HOME; CPU (`dumpsys cpuinfo`), PSS, focus. No mAh claim |

Failures (`no_adb`, `no_device`, `multiple_devices`, `app_not_installed`, `pid_missing`, VPN not observable) exit non-zero. Missing timings stay `null`.

## Output

Device runs write to `.perf-captures/phase4/` (`result.json`, `summary.md`, plus `latest.json` / `latest.md`). That directory is gitignored.

Committed: `schema/result.schema.json`, `schema/example-result.json`.

## App instrumentation

`lib/common/perf_trace.dart` emits `dart:developer` Timeline marks and logcat lines:

`[PHASE4] mark=<name> elapsed_ms=<n>`

Enabled in debug/profile automatically. Release is off unless:

```text
--dart-define=PHASE4_PERF=true
```

Marks: `process_main_begin`, `system.version`, `globalState.init`, `dynamic_color`, `package_info`, `preferences`, `migration`, `database_profiles`, `localization`, `runApp`, `first_frame`, `globalState.attach`, `proxy_group_snapshot_hydration`, `setupAction.initStatus`, `core_ready`, `main_ready`.

`first_frame` is rasterized first frame. `main_ready` is after `initStatus` and `initProvider=true`.
