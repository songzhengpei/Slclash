# Phase 4A.1 — idle getRunTime probe skip

Device: `25042PN24C` / Android 16 (sdk 36). Formal **profiling** APK (`com.slclash.app`, versionCode 1) with StartupTrace. Before numbers are the Phase 4A.0 profile baseline in `docs/phase4-a0-baseline.md`. After numbers are `.perf-captures/phase4/20260819T042530Z`.

## Change

Idle cold start was binding `:remote` and waiting on `getSessionSnapshot()` only to learn VPN is off. That gap was ~276ms (`proxy_group_snapshot_hydration` ~95ms → `main_ready` ~371ms) and spawned ~45MB of `:remote` PSS.

`handleGetRunTime` now binds/snapshots only when `:remote` is already alive, the Flutter process is already bound, or cached `runTime > 0`. Idle force-stop starts return 0 without starting CommonService. VPN-already-running and `handleInit` / `start` bind paths are unchanged.

## Profile before / after

| Metric | 4A.0 before | 4A.1 after | Delta |
|---|---|---|---|
| TotalTime median / p90 ms | 414.0 / 428.7 | 410.0 / 458.2 | −4 / +29.5 |
| first_frame median / p90 ms | 105.0 / 113.2 | 102.5 / 113.9 | −2.5 / +0.7 |
| main_ready median / p90 ms | 371.5 / 394.6 | 124.5 / 144.8 | **−247 / −249.8** |
| core outcomes | 10× `core_skipped` | 10× `core_skipped` | — |
| idle app PSS kb | 343977 | 350445 | +6468 |
| idle `:remote` PSS kb | 45627 | **null (not running)** | **~−45MB process** |
| idle combined PSS kb | 389604 | 350445 | **−39159** |

`am start -W` TotalTime tracks first displayed activity, not Dart `main_ready`, so it barely moved. The critical-path win is `main_ready`.

New marks on the after run (elapsed from process start, medians):

- `initStatus.begin` 94.0ms
- `updateStartTime` 124.0ms (~30ms probe vs ~276ms bind+snapshot)
- `main_ready` 124.5ms

Idle jank still has `total_frames = 0` (`jank_invalid_no_frames`); excluded from formal compare. VPN ready stayed unconfirmed (no consent over ADB); STOP still cleared (`stop_to_cleared_ms` 359).

## Release acceptance

Local `flutter build apk --release` (no `PHASE4_PERF`) on the same device:

- TotalTime median / p90 / min / max ms: `404.0` / `416.3` / `393.0` / `419.0` (n=10)
- Idle memory: `:remote` not running (`remote_pid` null), app PSS `351150` kb

The local release APK still reports Android `DEBUGGABLE` (personal unsigned/local signing). It is production-mode Dart (`assembleRelease`), not a store build.

## Semantics kept

- Single snapshot / source preservation / RawConfig / Script once / DNS+TUN ownership unchanged.
- Opening the app idle does not start Core (`core_skipped`).
- Starting VPN still binds `:remote` (`handleInit` / `start`); harness observed `remote_pid` after START.
