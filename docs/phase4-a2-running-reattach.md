# Phase 4A.2 — running session fast reattach

Device: `25042PN24C` / Android 16 (sdk 36). Formal **profiling** APK `com.slclash.app.profile` (versionCode 1). Product baseline SHA for this phase’s before: `7a585e0d`. After captures: running-reattach `.perf-captures/phase4/20260819T054103Z`, idle cold-start `.perf-captures/phase4/20260819T054710Z`, idle memory `.perf-captures/phase4/20260819T054806Z`.

## Change

Closing the Flutter UI (kill UI pid, swipe away, not `am force-stop`) used to unbind the last client of `RemoteService`. Android then destroyed that service, wrote `STOPPED`, and tore down VPN. Reopening the app showed proxy as off even though the user had just started it.

4A.2 keeps a RUNNING/PAUSED session alive across UI restarts:

- `RemoteService` calls `startService` while the session is not `STOPPED`, so the last UI unbind does not destroy it.
- `:remote` writes `files/remote_session_presence.txt`. A new UI process hydrates from that file when `Os.kill(pid, 0)` shows the pid is still alive. Hidden `/proc` listings must not delete the file.
- RUNNING reattach skips the 300ms `connectCore` delay and defers `initCore` group work so `applyProfile` is the single owner. Config identity was not small enough to skip `applyProfile`.
- Idle `force-stop` still skips Core (`core_skipped`) and must not spawn `:remote`.

## Running reattach (VPN stays up)

Harness: `python tools/perf/phase4.py running-reattach --package com.slclash.app.profile --build-mode profile`. UI kill only (`run-as kill` / `am kill`). Continuity is remote pid + sessionId, not a mid-kill `vpn_ready=None` flicker.

Before `7a585e0d` on this device, the same scenario was not a real reattach: 9/10 measure runs emitted `core_skipped` / `session_id=0` / `STOPPED`, and VpnService disappeared after UI kill. Those ~144ms `main_ready` numbers are false-idle, not a before for this table.

| Metric | After (n=9 marks / 10 am-start) |
|---|---|
| TotalTime median / p90 ms | 424.5 / 446.1 |
| first_frame median / p90 ms | 104.0 / 108.0 |
| session_snapshot / updateStartTime median ms | 146.0 / 146.0 |
| connectCore / preload median ms | 157.0 / 157.0 |
| core_ready / initCore median ms | 170.0 / 168.0 |
| setupConfig / startListener median ms | 464.0 / 464.0 |
| applyProfile / applyProfile.groups median ms | 505.0 / 490.0 |
| main_ready median / p90 ms | 505.0 / 517.8 |
| core outcomes | 9× `core_ready`, 0× `core_skipped` |
| remote pid | `8094` unchanged |
| session | `session_id=1787118002461` `RUNNING` across kill |
| vpn_ready after reopen | true (`tun0`) |

`connectCore` no longer waits 300ms on RUNNING (preload ~16ms after snapshot). `main_ready` is still dominated by `setupConfig`/`applyProfile` (~300ms after `getProfile`); that apply is kept on purpose.

## Idle cold start (4A.1 must hold)

| Metric | 4A.1 after | 4A.2 after | Delta |
|---|---|---|---|
| TotalTime median / p90 ms | 410.0 / 458.2 | 511.5 / 538.7 | +101.5 / +80.5 |
| first_frame median / p90 ms | 102.5 / 113.9 | 132.0 / 139.8 | +29.5 / +25.9 |
| main_ready median / p90 ms | 124.5 / 144.8 | 184.0 / 188.0 | +59.5 / +43.2 |
| core outcomes | 10× `core_skipped` | 10× `core_skipped` | — |
| idle `:remote` PSS | not running | **not running** | — |
| idle app PSS kb | 350445 | 342362 | −8083 |

`updateStartTime` median 183.5ms vs `initStatus.begin` 154.5ms (~29ms probe, no idle bind). `am start -W` TotalTime is still first Activity, not Dart `main_ready`. Idle `:remote` stayed down.

## Semantics kept

- Single snapshot / source preservation / RawConfig / Script once / DNS+TUN ownership unchanged.
- Opening the app idle does not start Core.
- Explicit in-app Stop still stops VPN (`stopSelf` when snapshot is `STOPPED`).
- PAUSED restores smart-stop UI and does not take the RUNNING delay/group fast path.
- `applyProfile` is not skipped without a proven profileId + config fingerprint.
