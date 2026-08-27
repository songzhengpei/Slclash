# SlClash Phase 4F.0 — Background & Power Work Attribution Baseline

## 1. Provenance

- Repository/branch: `songzhengpei/Slclash`, `beta`
- Accepted Phase 4E HEAD: `d1051d5bcd0aa34c4844c8f55a6df75ccccc92bd`
- Phase 4E closeout / `PHASE4F_BASELINE`: `482972a1f0e52647252f7967c62f695c0feaacf4`
- Phase 4F instrumentation: `ffb28e83f176acceda625de88e479eb93763a27a`
- Formal evidence build: profile, `com.slclash.app.profile`, `PHASE4_PERF=true`, clean worktree
- Device: Xiaomi `25042PN24C`, Android 16 / API 36, serial `0604B44041A00540`
- Capture: 2026-08-21, stable Wi-Fi, AC powered, battery saver off
- Full harness artifact: `.perf-captures/phase4/phase4-f0-20260821/result.json` (gitignored local evidence)
- Mihomo before/after: `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`; submodule clean after build patch restoration

## 2. Scope

This is an observer-only audit and attribution baseline. It adds profile/dev marks and an F0–F7 harness. It does not change timers, lifecycle, DNS, TUN, routing, notification policy, health policy, GC policy, or Mihomo. CPU values are process CPU time derived from `/proc/<pid>/stat`, not battery mAh. Context-switch fields come from the process leader's `/proc/<pid>/status`; a zero for the multithreaded remote process is available-but-not-process-wide and must not be interpreted as zero work.

## 3. Work Source Inventory

| source | file | layer | trigger | cadence | foreground? | background? | screen-off? | Doze? | network? | Core IPC? | user-visible purpose | classification |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| SetupAction UI stats | `lib/providers/action.dart` | Flutter | VPN RUNNING + app foreground | timer 1 s; chart 2 s; total/runtime 5 s | yes | no (verified) | no | no | no | `getTrafficSnapshot` on Dashboard | speed/chart/runtime | UI_ONLY |
| Dashboard network diagnostics | `lib/views/dashboard/widgets/network_overview_card.dart`, `lib/common/network_diagnostics_session.dart` | Flutter | Dashboard active + foreground-derived gate; route/state events | 60 s periodic plus coalesced events | yes | no in ordinary F3/F4/F5 (verified) | no | no | yes | `getConnections`, country lookup | GitHub/YouTube/ChatGPT latency and route | UI_ONLY |
| Dashboard memory card | `lib/views/dashboard/widgets/memory_info.dart` | Flutter | widget mounted | one-shot every 10 s | possible | possible if retained | possible | unknown | no | `getMemory` | visible memory card | UI_ONLY / WATCH; no executions observed in F0–F7 |
| Connections page refresh | `lib/views/connection/connections.dart` | Flutter | foreground + RUNNING + correct page + listener active | 1 s | yes | no by explicit gate | no | no | no | `getConnections` | live connection list | UI_ONLY |
| NetworkDetection | `lib/providers/app.dart` | Flutter | check-IP provider change / explicit request | debounced; 13 s hard timeout; 2 s failure display | yes/event | only if event starts it | possible until bounded timeout | no evidence | yes | no | public IP display | EVENT_DRIVEN_LOW_COST |
| HealthObservationScheduler | `lib/providers/health_observation.dart` | Flutter | user enabled + due + idle | one-shot; configured 20/40/60/120 min in profile/release | yes when idle | yes | yes, max 5 workers | paused only in power-save; otherwise possible | yes | `getProxies`, `mediaCheck` | opt-in node health cache | USER_OPT_IN_MAINTENANCE |
| SmartAutoStopManager | `lib/providers/smart_auto_stop.dart` | Flutter | connectivity/config/session event | 2 s debounce; one startup guard timer | event | event | possible on event | possible on event | yes | native service control, local-IP query | trusted-network SMART_STOP/RESUME | EVENT_DRIVEN_LOW_COST |
| App background GC | `lib/manager/app_manager.dart` | Flutter | actual `paused` lifecycle | once per transition, 60 s throttle | no | transition only | transition only | no loop | no | `forceGc` | memory reclamation | EVENT_DRIVEN_LOW_COST / WATCH |
| Profile auto-update | `lib/application.dart` | Flutter | app lifetime; per-profile auto-update policy inside action | recursive one-shot every 20 min | yes | yes | possible | timer subject to OS scheduling | yes when a profile is due | may apply/reload profile | subscription/profile maintenance | USER_OPT_IN_MAINTENANCE |
| ConnectivityManager app callback | `lib/manager/connectivity_manager.dart`, `lib/application.dart` | Flutter | connectivity stream | event-driven | yes | listener remains | possible | OS-delivered | yes | may close connections/update local IP/check IP | network convergence | EVENT_DRIVEN_LOW_COST |
| Log/request batching | `lib/providers/app.dart` | Flutter | incoming Core listener events | short one-shot batch timers | yes | if events arrive | possible | possible | no | listener event source | bound UI update pressure | EVENT_DRIVEN_LOW_COST |
| Status/debounce/throttle/UI timers | `lib/manager/status_manager.dart`, `lib/common/function.dart`, `lib/widgets/builder.dart`, view files | Flutter | transient UI/action events or mounted widget | bounded one-shot; TimerBuilder periodic while mounted | yes | normally disposed/gated | no evidence | no evidence | usually no | action-dependent | UX feedback and coalescing | UI_ONLY |
| Core listener/event system | `lib/manager/core_manager.dart`, `lib/core/*`, remote service | Flutter/Android/Core | listener attached and Core emits | event-driven | yes | data-plane events may continue; Flutter UI timer stops | possible | possible | yes | event channel, no fixed poll found | runtime logs/requests/state | DATA_PLANE_REQUIRED |
| NotificationModule | `android/service/.../NotificationModule.kt` | remote service | VPN service installed | ticker 10 s | yes | yes | ticker yes, evaluation no | ticker observed | no external network | direct native Core speed/traffic read only when screen on | required foreground notification | ANDROID_LIFECYCLE_REQUIRED; ticker WATCH |
| NetworkObserveModule | `android/service/.../NetworkObserveModule.kt` | remote service | Android `NetworkCallback` | event-driven; CONFLATED generation channel | yes | yes | possible only on event | possible only on event | yes | direct `Core.updateDNS` only on changed nonempty DNS | DNS/routing correctness | DATA_PLANE_REQUIRED / EVENT_DRIVEN_LOW_COST |
| SuspendModule | `android/service/.../SuspendModule.kt` | remote service | SCREEN_ON/OFF broadcast; initial sample | event-driven | yes | yes | one screen-off sample | no device-idle-change listener | no | direct `Core.suspended` | Core suspend hint | DATA_PLANE_REQUIRED; correctness finding |
| CommonService/VpnService/RemoteService/module lifecycle | `android/service/src/main/java/com/follow/clash/service/*` | Android remote | start/bind/stop/revoke/SMART action | event-driven coroutines | yes | yes while session exists | yes | yes | data plane | JNI/service calls | VPN/TUN/session/foreground service | ANDROID_LIFECYCLE_REQUIRED + DATA_PLANE_REQUIRED |
| QuickAction/Tile/TempActivity | `android/app/src/main/kotlin/com/follow/clash/*` | Android app | explicit user/system click/update | event-driven | yes | may launch without Flutter UI | yes if invoked | possible if invoked | no continuous work | service command | external controls | EVENT_DRIVEN_LOW_COST |
| App links/scanner/icon streams | `lib/common/link.dart`, `lib/pages/scan.dart`, icon views | Flutter | OS/user events; mounted page | subscriptions, lifecycle-gated where relevant | yes | page-dependent | no evidence | no | event-specific | no | import/scan/icon UX | UI_ONLY |

Repository-wide searches found no SlClash `WakeLock`, `AlarmManager`, `WorkManager`, `JobScheduler`, `ScheduledExecutor`, or retained background polling loop beyond the listed timers/tickers. Device `dumpsys alarm` had no package match; jobscheduler only showed package accounting/TopAppTimer state, not a SlClash scheduled job.

## 4. Foreground Baseline

F1 RUNNING Dashboard is the reference workload: main 9,640 ms CPU/min, remote 6,290 ms/min, 210 Flutter Core IPC/min. It included 64 `getTrafficSnapshot`, 144 diagnostic `asyncTestDelay`, one `getIsInit`, one `getProxies`, six notification ticks/evaluations, and one periodic diagnostics refresh. F2 RUNNING Proxies fell to main 210 ms/min and remote 620 ms/min with zero Core IPC. The UI timer still woke 63 times but its non-Dashboard path issued no traffic snapshot; Dashboard diagnostics had no stable-window refresh.

## 5. Background Screen-On

F3 (HOME, 90 s) measured main 140 ms/min, remote 480 ms/min, zero Flutter Core IPC, zero UI-stat ticks, zero diagnostics refreshes, zero network callbacks, and zero DNS updates. Notification tick/evaluation ran 9 times (6/min), but no `NotificationManager.notify` call occurred because parameters were unchanged. Entry produced exactly one GC request/completion; there was no repeated GC during the window.

## 6. Screen-Off

F4 (120 s) kept RUNNING/session/TUN continuous. Main was 50 ms/min and remote 2,370 ms/min. The notification ticker emitted 12 times, while notification evaluation, direct Core traffic-text computation, and notify were all zero. Flutter Core IPC, UI polling, diagnostics, network callbacks, and DNS updates were zero. The higher remote CPU than F3 is measured variance/residual data-plane work; no control-plane source was identified that explains it, so it is not classified as a fix.

## 7. Device Idle / Doze

`dumpsys deviceidle force-idle` succeeded and `get deep` returned `IDLE`. F5 retained RUNNING, the same session ID/PID, and exactly one `tun0`. Main was 45 ms/min; remote was 325 ms/min; Core IPC/network callbacks/DNS updates were zero. The 10 s notification ticker emitted 13 times but performed zero evaluations/updates.

Ordered evidence:

- SCREEN_OFF: `screen_on=false`, `device_idle=false`, `core_suspend_requested=false`.
- Transition to confirmed deep `IDLE` without another screen broadcast: no `screen_state`, `device_idle_state`, or `core_suspend_requested` event.
- Wake: `screen_on=true`, `device_idle=false`, `core_suspend_requested=false`.

Therefore Core did not receive `suspended(true)` when Android entered Device Idle after screen-off. This is a reproduced power-correctness finding. It is not fixed in 4F.0.

## 8. PAUSED

F6 entered the frozen SMART_PAUSED path. Session ID `1787299469239` and remote PID `15033` remained stable; TUN was absent before and after. Main measured 30 ms/min, remote 75 ms/min, Core IPC zero, network/DNS zero, and one notification tick with no evaluation/update. No lifecycle behavior was changed.

## 9. Health Observation Opt-In

Ordinary F0–F6 forced health observation disabled and restored the previous value afterwards. The formal F7 recorded 168 `mediaCheck` dispatches, main 995 ms/min and remote 8,210 ms/min, but observation began during the foreground-to-background transition.

A separate controlled background F7 refreshed the user-interaction timestamp before marking work due. The scheduler first deferred twice, then began with `foreground=false`, screen on, power saver off, Wi-Fi/non-cellular, 185 eligible proxies, and 5 workers. It completed successfully in 33,057 ms with 185 `mediaCheck` calls. Across the 120 s observation window: main 1,785 ms/min, remote 11,035 ms/min, total Core IPC 163/min, and TUN bytes increased by 13,837 RX + 88,969 TX bytes. This is an upper bound because the same window coincided with one 20-minute profile auto-update and three diagnostic refreshes. It is a deliberate USER_OPT_IN workload, not unavoidable VPN idle cost. The previous health setting (`enabled=false`, interval 60 min) was restored.

## 10. Notification Module

| condition | ticks | evaluations/Core traffic-text reads | actual updates |
|---|---:|---:|---:|
| F1 foreground screen on, 60 s | 6 | 6 | 0 |
| F3 background screen on, 90 s | 9 | 9 | 0 |
| F4 screen off, 120 s | 12 | 0 | 0 |
| F5 deep idle, 120 s | 13 | 0 | 0 |
| F6 PAUSED screen off, 120 s | 1 | 0 | 0 |

The current screen-off filter works: no Core traffic reads occur while screen off. The ticker itself remains scheduled in RUNNING screen-off/Doze. Its independent CPU cost cannot be isolated from data-plane work, and there is no evidence of meaningful cost sufficient for a 4F.0 product change.

## 11. Network Observe

F0–F7 stable windows recorded zero `onAvailable`, `onLosing`, `onLost`, `onLinkPropertiesChanged`, enqueue/apply, and `Core.updateDNS` events. Source audit confirms callback-driven behavior, CONFLATED updates, stale-generation rejection, and DNS equality suppression. Stable-network expectation is satisfied.

## 12. Suspend Module

The module listens only to SCREEN_ON/OFF and samples `isDeviceIdleMode` at those events. It has no `ACTION_DEVICE_IDLE_MODE_CHANGED` listener. The device sequence reproduced the resulting missed `suspended(true)` transition. Wake correctly emitted `suspended(false)`.

## 13. Background GC

F3 entry emitted one `background_gc_requested`, one `forceGc` dispatch, and one completion. No repeat occurred during 90 s. F4 was a separate eligible foreground-to-paused transition more than 60 s later and likewise emitted one request/completion; F6 within the throttle interval emitted none. The existing transition + 60 s throttle contract is verified. CPU/memory trade-off remains WATCH; PSS movement is not claimed as battery improvement.

## 14. Core IPC

| window | total/min | methods (count in window) |
|---|---:|---|
| F0 | 0 | none dispatched; four pre-invoke not-ready outcomes from visible stopped-Dashboard diagnostics |
| F1 | 210 | `getTrafficSnapshot` 64, `asyncTestDelay` 144, `getIsInit` 1, `getProxies` 1 |
| F2 | 0 | none |
| F3 | 0 | none; one transition-only `forceGc` |
| F4 | 0 | none; one transition-only `forceGc` |
| F5 | 0 | none |
| F6 | 0 | none |
| F7 formal | 84 | `mediaCheck` 168 over 120 s |
| F7 controlled background | 163 | `mediaCheck` 185 plus contaminated `asyncTestDelay` 124, `getConnections` 9, `getCountryCode` 3, `getProxies` 2, `getTrafficSnapshot` 2, `getIsInit` 1 |

No dispatched-window null/error outcomes occurred. Native Notification/Core DNS calls are counted by their native marks because they do not traverse Flutter `CoreIpcTrace`.

## 15. CPU / Context Switches

| window | duration | main CPU ms/min | remote CPU ms/min | main ctx/min | remote leader ctx/min | main PSS KiB before→after | remote PSS KiB before→after |
|---|---:|---:|---:|---:|---:|---:|---:|
| F0 | 60 s | 9440 | unavailable | 1532 | unavailable | 386450→363663 | unavailable |
| F1 | 60 s | 9640 | 6290 | 1643 | 0 | 369355→366449 | 166123→164681 |
| F2 | 60 s | 210 | 620 | 85 | 0 | 383173→377208 | 163181→163327 |
| F3 | 90 s | 140 | 480 | 68 | 0 | 217790→217093 | 163283→163383 |
| F4 | 120 s | 50 | 2370 | 17 | 0 | 216945→211400 | 163550→134588 |
| F5 | 120 s | 45 | 325 | 0.5 | 0 | 211472→211451 | 134564→134471 |
| F6 | 120 s | 30 | 75 | 4 | 1 | 213969→214130 | 128382→128357 |
| F7 controlled background | 120 s | 1785 | 11035 | 880.5 | 0 | 373481→240192 | 186474→189618 |

F0 is a stopped-VPN but foreground Dashboard control, not a blank-process baseline: visible network diagnostics and startup settling explain why it resembles F1 main CPU. RSS/PSS reductions are descriptive only.

## 16. Continuity

F1–F5 used session ID `1787299469239`, remote PID `15033`, and one `tun0` continuously. F6 preserved the same session ID/PID with no TUN. F7 runs each preserved their own RUNNING session/PID and one TUN. F0 and final restored STOPPED state had no VpnService/TUN. After all tests: Device Idle `ACTIVE` (not forced), screen `Awake`, health `false/60`, profile VPN STOPPED, Mihomo clean/pinned.

## 17. P0 Findings

**P0 POWER/CORRECTNESS — reproduced:** entering Device Idle after the existing SCREEN_OFF event does not cause `Core.suspended(true)`. Residual F5 work was main 45 ms/min, remote 325 ms/min, 13 notification ticker emissions, zero Flutter IPC, and zero network/DNS callbacks. Connectivity/session/TUN remained intact during this short forced-idle window. No fix was made.

## 18. P1 Findings

No evidence-backed continuous unnecessary background work was found in ordinary F3–F6. Flutter traffic polling and Dashboard diagnostics stopped; stable network observation was silent; SmartAutoStop did not poll; background GC did not repeat.

## 19. P2 Findings

- Notification's 10 s coroutine continues to wake in RUNNING screen-off/Doze while its expensive evaluation is correctly filtered. Cost was not independently measurable: WATCH, not an approved fix.
- SetupAction's 1 s timer remains active on a foreground non-Dashboard page, but performs no Core IPC and measured main CPU was only 210 ms/min: foreground efficiency opportunity only.
- Dashboard memory's ungated 10 s implementation is structurally capable of retained work, but no executions were observed: WATCH.

## 20. User-Opt-In Costs

Health observation is the dominant measured optional workload: 185 node checks with five background workers completed in about 33.1 s and drove remote CPU to an upper-bound 11.035 s/min during its 120 s window. Profile auto-update is another conditional user maintenance source; its always-present 20-minute one-shot scheduler fired once in the controlled F7 and is reported separately from base VPN idle.

## 21. Required / Accepted Work

- Mihomo data plane, TUN, remote service, and Core event delivery: DATA_PLANE_REQUIRED.
- Foreground service and notification presence: ANDROID_LIFECYCLE_REQUIRED.
- Network callback/DNS convergence and screen hints: required event-driven work.
- Foreground Dashboard statistics/diagnostics and page-specific connections: UI_ONLY and correctly foreground/page gated in ordinary transitions.
- QuickAction/Tile, connectivity, app links, debounces, batching: accepted event-driven work.

## 22. Candidate 4F.1

Human audit should decide whether 4F.1 adds device-idle transition observation (for example, observing the platform idle-mode change and resampling screen/idle state) so Core receives `suspended(true)` without a second SCREEN_OFF. Any change must revalidate VPN reachability, session/TUN continuity, wake `suspended(false)`, OEM behavior, and Phase 4E lifecycle. Notification ticker and other WATCH items do not yet have evidence sufficient for a product change.

## 23. Regression

- `flutter analyze`: no errors/warnings; 70 existing info-level findings.
- Selected Phase 4C/4D/4E/4F Flutter regression: 158 tests PASS.
- Python harness/parser: 62 tests PASS.
- Android `:app:testDebugUnitTest :service:testDebugUnitTest`: PASS (`BUILD SUCCESSFUL`).
- Profile arm64 APK with `PHASE4_PERF=true`: PASS, 96.3 MB.
- Harness smoke F0–F7: PASS.
- Formal profile F0–F7: PASS.

## 24. CI Truth

GitHub Actions workflows exist, but no hosted run was executed for `ffb28e83` or the final documentation commit at evidence time. The latest listed beta workflow was for an older SHA. Therefore: local tests PASS; CI for this Phase 4F.0 HEAD NOT RUN. Do not report CI PASS.

## 25. Mihomo Pin

Before and after: `core/Clash.Meta = ac017cdd246ce8bd547653d927e7bf77d7ee73d5`, clean. The Android build's existing temporary proxy-only patch was restored immediately after each build and produced no committed submodule change.

## 26. STOP Decision

Phase 4F.0 audit, instrumentation, and baseline evidence are complete. One reproduced Device Idle correctness candidate is handed to human audit. No 4F.1 behavior change and no Phase 4G work is included. **STOP.**
