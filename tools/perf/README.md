# Phase 4 performance harness

Python + ADB harness for SlClash Phase 4. It records a baseline; it does **not** change startup, Core, VPN, Profile, or Proxy behavior.

Product baseline SHA: `b7e08b6ef84546e9b3d084a411c3a59e3e4df7c8`

## Build mode rules

| Flutter mode | Harness role | Formal baseline? | Use for |
|---|---|---|---|
| `debug` | `diagnostic_only` | **No** | Harness / instrumentation debugging only. Never claim improvement %. |
| `profile` | `profiling` | Yes | StartupTrace / Timeline / DevTools / jank / CPU on a real device. Prefer `--dart-define=PHASE4_PERF=true`. |
| `release` | `production` | Yes | Final cold start, memory, VPN start/stop, background CPU, UX acceptance. Default: no extra perf instrumentation. |

`--write-baseline-doc` refuses `diagnostic_only` / debug builds.

```powershell
# Profile (marks + jank / profiling)
flutter build apk --profile --target-platform android-arm64 --dart-define=PHASE4_PERF=true
python tools/perf/phase4.py all --build-mode profile --write-baseline-doc docs/phase4-a0-baseline.md

# Release / beta production acceptance (no PHASE4_PERF by default)
flutter build apk --release --split-per-abi --target-platform android-arm64
python tools/perf/phase4.py all --package com.slclash.app --build-mode release
```

Pass `--build-mode profile` explicitly for profiling APKs (non-debuggable packages otherwise default to `release`).

## Command

```powershell
$env:Path = "D:\Code\Tools\Android\Sdk\platform-tools;$env:Path"
python tools/perf/phase4.py all --build-mode profile
```

Subcommands: `env`, `cold-start`, `memory`, `jank`, `vpn`, `background`, `compare`.

```powershell
python tools/perf/phase4.py compare --baseline .perf-captures/phase4/old/result.json --current .perf-captures/phase4/latest.json
python -m unittest tools/perf/tests/test_harness.py
```

Options: `--package`, `--serial` / `ANDROID_SERIAL`, `--adb`, `--build-mode`, `--out`, `--write-baseline-doc`.

## What it measures

| Scenario | Method |
|---|---|
| env | `adb devices`, `getprop`, `dumpsys package` (incl. DEBUGGABLE → build mode), `pidof` |
| cold-start | `am force-stop`, `am start -W`; warmup 2, measure 10; median / P90 / min / max; startup marks aggregated across all measure runs |
| memory | `dumpsys meminfo` for app and `:remote` (PSS, Java/Native heap when present) |
| jank | `dumpsys gfxinfo reset` then `gfxinfo`; idle frames only, no UI automation |
| vpn | TempActivity START/STOP; `start_observable` vs confirmed `vpn_ready`; stop latency |
| background | foreground vs HOME; CPU / PSS / focus; VPN active vs inactive |

Failures (`no_adb`, `no_device`, `multiple_devices`, `app_not_installed`, `pid_missing`, VPN not ready) exit non-zero. Missing timings stay `null`.

## Output

Device runs write to `.perf-captures/phase4/` (`result.json`, `summary.md`, plus `latest.json` / `latest.md`). That directory is gitignored.

Committed: `schema/result.schema.json`, `schema/example-result.json`, `docs/phase4-a0-baseline.md` (aggregates only).

## App instrumentation

`lib/common/perf_trace.dart` emits `dart:developer` Timeline marks and logcat lines:

`[PHASE4] mark=<name> elapsed_ms=<n>`

Enabled in debug/profile automatically. Release is off unless:

```text
--dart-define=PHASE4_PERF=true
```

Marks: `process_main_begin`, `system.version`, `globalState.init`, `dynamic_color`, `package_info`, `preferences`, `migration`, `database_profiles`, `localization`, `runApp`, `first_frame`, `globalState.attach`, `proxy_group_snapshot_hydration`, `setupAction.initStatus`, `core_ready` / `core_skipped` / `core_connect_failed` / `core_init_failed`, `main_ready`.

Only a truly connected+initialized Core emits `core_ready`. Idle autoRun-off paths emit `core_skipped`.

`first_frame` is rasterized first frame. `main_ready` is after `initStatus` and `initProvider=true`.

## VPN readiness rule

- `start_observable`: VpnService **or** real `tunN` iface **or** `:remote` pid (weak).
- `vpn_ready`: VpnService **and** real `tunN` iface only. Remote pid alone never counts.
- `start_to_ready_ms` is set only when `vpn_ready` is true; otherwise `null`.
- Stop success requires VpnService gone and no `tunN` left; `stop_to_cleared_ms` follows that rule.
