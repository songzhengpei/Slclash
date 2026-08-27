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
# Profile (marks + jank / profiling) — package com.slclash.app.profile, overlay-install OK
flutter build apk --profile --target-platform android-arm64 --dart-define=PHASE4_PERF=true
adb install -r build\app\outputs\flutter-apk\app-profile.apk
python tools/perf/phase4.py all --build-mode profile

# Production acceptance: measure the CI beta/main APK already on the phone.
# Do not locally assembleRelease for every Phase 4 iteration.
python tools/perf/phase4.py all --package com.slclash.app --build-mode release
```

Pass `--build-mode profile` explicitly for profiling APKs. `--package` defaults by mode:

| `--build-mode` | Default package |
|---|---|
| `debug` / omitted | `com.slclash.app.dev` |
| `profile` | `com.slclash.app.profile` |
| `release` | `com.slclash.app` |

## Command

```powershell
$env:Path = "D:\Code\Tools\Android\Sdk\platform-tools;$env:Path"
python tools/perf/phase4.py all --build-mode profile
```

Subcommands: `env`, `cold-start`, `memory`, `jank`, `vpn`, `background`, `power`, `running-reattach`, `navigation`, `proxy`, `ipc`, `compare`.

```powershell
python tools/perf/phase4.py compare --baseline .perf-captures/phase4/old/result.json --current .perf-captures/phase4/latest.json
python tools/perf/phase4.py navigation --build-mode profile --write-nav-baseline-doc docs/phase4/phase4-b0-navigation-baseline.md
python tools/perf/phase4.py navigation --build-mode profile --nav-session running
python tools/perf/phase4.py proxy --build-mode profile --proxy-session idle --delay-max 20
python tools/perf/phase4.py proxy --build-mode profile --proxy-session running --delay-max 20
python tools/perf/phase4.py vpn --build-mode profile --vpn-scenario all
python tools/perf/phase4.py power --build-mode profile
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
| vpn | Phase 4E observer-only lifecycle windows. `--vpn-scenario all\|start-stop\|reattach\|smart\|quick` records SessionPresence, native state transitions, Flutter-derived state, remote/UI PID, VpnService, real `tunN`, bind/disconnect, Tile/QuickAction dispatch, and raw ordered `[PHASE4]` lines. |
| running-reattach | VPN stays up; kill Flutter UI pid only (`run-as kill` / `am kill`, never `force-stop`); reopen MainActivity. Formal continuity requires `kill_ui_keep_remote.ok`, old UI pid gone, remote pid unchanged before/mid/post, presence-file `sessionId>0` identical, `state=RUNNING`, and `vpn_ready` before/post. Logcat is StartupTrace timing only. |
| navigation | Profile APK only. ADB sends `phase4_cmd` extras to already-exported `MainActivity` (`singleTop` / `onNewIntent`). Dart no-ops unless NavigationTrace is enabled. Records Flutter FrameTiming per tab transition. Frame budget uses the device refresh rate. Idle `dumpsys gfxinfo` is **not** this metric. `all` does not include navigation. Default `--nav-session idle` force-stops the package (VPN OFF). `--nav-session running` never force-stops: it requires VpnService + tun + `:remote` + presence `state=RUNNING` + `sessionId>0` + `vpn_ready`, and sets `ok=false` if remote pid / sessionId / tun / vpn_ready change. |
| proxy | Phase 4C.0. Never force-stops. Navigates Dashboard → Proxy, runs capped `delayTest` (product `map`+`batch(100)`), then Proxy → Dashboard → Proxy. Records delay peak_inflight, eager `_buildItems` counts, FrameTiming for those tab pairs, VPN continuity when `--proxy-session running`. `all` does not include proxy. |
| background | foreground vs HOME; CPU / PSS / focus; VPN active vs inactive |
| power | Phase 4F F0–F7 long windows: `/proc` CPU/context-switch/thread deltas, PSS/RSS, Core IPC, notification/network/suspend/GC marks, session/TUN continuity, controlled Device Idle, and separate health-observation opt-in cost. Formal baseline uses the default `--power-scale 1.0`. Settings and forced-idle state are restored in `finally`. |

Failures (`no_adb`, `no_device`, `multiple_devices`, `app_not_installed`, `pid_missing`, VPN not ready) exit non-zero. Missing timings stay `null`.

## Output

Device runs write to `.perf-captures/phase4/` (`result.json`, `summary.md`, plus `latest.json` / `latest.md`). That directory is gitignored.

Committed with this harness: `schema/`, `results/` (selected captures), and `collect_android_perf.ps1` (one-shot dumpsys dump). Formal Phase 4 reports live in [`docs/phase4/`](../../docs/phase4/); index: [`docs/README.md`](../../docs/README.md).

Phase status:

- Phase 4A (Startup): **CLOSED**
- Phase 4B (Navigation / Page Mounting): **CLOSED** — `docs/phase4/phase4-b-final-closeout.md`
- Phase 4C (Proxy / Group UX): **CLOSED** — `docs/phase4/phase4-c-final-closeout.md`
- Phase 4D (Runtime Polling / Core IPC): **CLOSED** — `docs/phase4/phase4-d-final-closeout.md`
- Phase 4E (VPN Lifecycle): **CLOSED** — `docs/phase4/phase4-e-final-closeout.md`
- Phase 4F (Background / Power): **CURRENT — 4F.0 audit/instrumentation baseline only.** — `docs/phase4/phase4-f0-background-power-baseline.md`
- Phase 4G (Animation polish): **FUTURE**

Phase 4D.0 IPC: `python tools/perf/phase4.py ipc --ipc-session idle|running`. Never force-stops. `all` does not include `ipc`.

Phase 4E.0 VPN lifecycle: `python tools/perf/phase4.py vpn --build-mode profile --vpn-scenario all`. The command mutates only the selected profile/debug test package, begins from a known STOPPED state, and retains each state/TUN/PID observation plus filtered raw marks. It does not classify observation flags as product bugs. `all` does not include this scenario.

Phase 4C.0 audit: `python tools/perf/phase4.py proxy`. Never force-stops. `all` does not include `proxy`. See `docs/phase4/phase4-c0-proxy-group-baseline.md`.

Phase 4C.1B evidence: same `proxy` command. Extra event-scoped dumps and selection traces are on by default (`--proxy-evidence`). `--delay-sizes 20,100` for IDLE; RUNNING should stay at 20. See `docs/phase4/phase4-c1b-proxy-performance-evidence.md`. These commands remain as retained diagnostic infrastructure.

## App instrumentation

`lib/common/perf_trace.dart` emits `dart:developer` Timeline marks and logcat lines:

`[PHASE4] mark=<name> elapsed_ms=<n>`

Enabled in debug/profile automatically. Release is off unless:

```text
--dart-define=PHASE4_PERF=true
```

Marks: `process_main_begin`, `system.version`, `globalState.init`, `dynamic_color`, `package_info`, `preferences`, `migration`, `database_profiles`, `localization`, `runApp`, `first_frame`, `globalState.attach`, `proxy_group_snapshot_hydration`, `initStatus.begin`, `updateStartTime`, `session_snapshot`, `connectCore`, `preload`, `ensureCoreReady`, `initCore`, `setupAction.initStatus`, `core_ready` / `core_skipped` / `core_connect_failed` / `core_init_failed`, `getProfile`, `setupConfig`, `startListener`, `applyProfile`, `applyProfile.groups`, `syncProviders`, `main_ready`.

Phase 4E native and Flutter marks use the same line format and are enabled only for `.profile` / `.dev`: `vpn_action_requested`, `vpn_permission_begin`, `vpn_permission_result`, `vpn_service_dispatch`, `vpn_service_result`, `vpn_state_transition`, `vpn_snapshot`, `vpn_session_presence`, `vpn_remote_bind_begin`, `vpn_remote_connected`, `vpn_remote_disconnected`, `vpn_remote_unbound`, `vpn_flutter_sync_begin`, `vpn_flutter_sync_end`, `vpn_flutter_state`, `vpn_listener_start`, `vpn_listener_stop`, `vpn_tun_observed`, `vpn_action_complete`, `vpn_quick_action`, `vpn_tile_state`, `smart_stop_begin`, `smart_stop_complete`, `smart_resume_begin`, `smart_resume_complete`.

Only a truly connected+initialized Core emits `core_ready`. Idle autoRun-off paths emit `core_skipped`.

`first_frame` is rasterized first frame. `main_ready` is after `initStatus` and `initProvider=true`.

Phase 4B navigation marks (same enablement, FrameTiming only while a transition is active): `nav_listener_ready`, `nav_begin`, `nav_animate_start`, `nav_target_first_build`, `nav_target_first_frame`, `nav_animation_complete`, `nav_scroll_to_top`, `nav_scroll_command`, `nav_scroll_animation_complete`, `nav_scroll_by`, `nav_complete`, `nav_page_counts`. `nav_complete` may include compact `hotspot_builds` / `hotspot_events` (Dashboard / chart counters during the active transition only). `target_first_build_latency_ms` is wait until target root `build()` is called, not build CPU. Production release without `PHASE4_PERF` does not register the timings callback. Ordinary production Release does not register `Phase4PerfPlugin` / `Phase4PerfReceiver`.

Idle `dumpsys gfxinfo` with `total_frames <= 0` is marked `jank_invalid_no_frames` and excluded from `compare`. Results record `git_head`, `dirty`, and `worktree_fingerprint` so the source tree that produced the run is visible.

Refresh-rate provenance: dumpsys may list both a physical/supported mode (e.g. 120 Hz) and a render hint (e.g. 60 Hz). `system_max_refresh_hz` is the highest candidate, **not** actual presentation Hz. FrameTiming `over_budget` uses Flutter `display.refreshRate` as `effective_budget_ms`. If Flutter Hz and system max Hz disagree, `refresh_rate_mismatch=true` and `over_budget_comparable=false`. Percentiles and `worst_frame_ms` remain valid.

## VPN readiness rule

- `start_observable`: VpnService **or** real `tunN` iface **or** `:remote` pid (weak).
- `vpn_ready`: VpnService **and** real `tunN` iface only. Remote pid alone never counts.
- `start_to_ready_ms` is set only when `vpn_ready` is true; otherwise `null`.
- Stop success requires VpnService gone and no `tunN` left; `stop_to_cleared_ms` follows that rule.
