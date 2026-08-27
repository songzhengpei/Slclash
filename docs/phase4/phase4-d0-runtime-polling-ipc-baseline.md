# Phase 4D.0 — Runtime Polling / Core IPC Baseline

Measurement only. No poll-interval, timeout, mutex, delay-limiter, VPN, or Mihomo changes. Phase 4C remains CLOSED / frozen.

**4D.0.1 (this document revision):** IPC evidence integrity cleanup only. No product behavior optimization. **STOP. Do not start 4D.1 until human audit.**

## 1. Provenance

| Field | Value |
|---|---|
| 4D.0.1 base | `9673ef7e71d33a52ed1c737e4e149ec7cf1bc38d` |
| closeout / 4D start base | `afea7b90121a49fd3593f9985b48ed862b09acba` |
| 4D.0 instrumentation | `047d4a8c34b9973c408e5f2d27e3bb27142077dc` |
| pinned Mihomo before/after | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` (unchanged) |
| local Clash.Meta worktree | leftover dirty files were present and **not** committed |
| device | `25042PN24C` serial `0604B44041A00540` |
| package | `com.slclash.app.profile` `9.9.10` profile / `PHASE4_PERF=true` |
| IDLE run_id | `r1787282281` |
| RUNNING run_id | `r1787282631` |
| RUNNING remote / session | pid `16898`, sessionId `1787282592591`, `tun0`, `continuity_ok=true` |
| captures | `tools/perf/results/phase4d0/{idle,running,lifecycle,delay-interference}/` |
| raw (gitignored) | `.perf-captures/phase4/d0-idle/`, `d0-running/` |

Command: `python tools/perf/phase4.py ipc --ipc-session idle|running --build-mode profile`. Never force-stops.

### 4D.0.1 measurement rules

- `beginWindow()` resets only window aggregates (counts, durations, overlap/peak counters). Live `_globalInflight` / `_methodInflight` / in-flight classification stay. `resetForTest()` is the only full live-state clear.
- Each harness `ipc` run has `run_id`; each window has `window_id`. Marks `ipc_window_begin/end`, `core_ipc_created/dispatch/complete` carry both.
- Page rates = DISPATCH in that window. Transport latency = same `id` dispatch→complete in the same window. Completes without a window dispatch are `complete_without_window_dispatch`, not a new page request.
- Delay `started/finished` is scoped to the delay `window_id`/`run_id`, not whole logcat.
- Background: START → HOME → 10 s auto-end. Resume is a separate window started by `am start` MainActivity. Background does not include the resume edge.
- `core_not_ready` records `preinvoke_wait_ms` and `latency_kind=preinvoke`. It is not transport latency and is not a dispatch.
- GitHub has **no status checks** on this repo. Local tests are recorded below. That is **not** “CI PASS”.

## 2. Runtime Scheduler Inventory

| Operation | Class | Trigger | Nominal cadence | Page gate | Lifecycle gate | Core method | Return type | Consumer |
|---|---|---|---|---|---|---|---|---|
| UI stats tick | **B + C** | `SetupAction` `Timer.periodic` | 1 s tick | Dashboard: traffic snapshot. Other pages: runtime clock only (no Core) | `isStart`, not smart-stopped, **foreground**; cancelled on background | `getTrafficSnapshot` | JSON string / `TrafficSnapshot`; `?? ''` → empty Traffic | speed notifier, chart (2 s), total (5 s), `runTime` (5 s, Dart clock) |
| `updateTraffic()` | unused | defined on `CommonAction`, **no lib callers** | — | — | — | would be `getTrafficSnapshot` | same | dead API vs live `_updateUiStats` |
| Connections list | **B + C** | `ConnectionsView` `Timer.periodic` | 1 s | Connections, or Tools on mobile | foreground, `isStart`, not suspend | `getConnections` | JSON `?? ''` | connections UI |
| Dashboard latency | **B + C** | `_OverviewLatencyHost` | 60 s + immediate | Dashboard | foreground | `getConnections` (match probes) + **HTTP** (not Core delay) | connections list | Network overview RTT |
| Memory card | **B** | recursive `Timer(10s)` while mounted | 10 s | Dashboard card | widget mounted; Core if `isCompleted` | `getMemory` | string `?? ''` → 0 | MemoryInfo |
| Groups refresh | **B + D** | enter Proxy if empty/expired 30 s; sort change debounce | 30 s freshness / debounce | Proxy enter | profile owner | `getProxies` | empty `ProxiesData` on null | `groupsProvider` |
| Provider refresh | **D** | user / `ProviderReadinessService` | on demand | Proxy/providers | ownerProfileId | providers + groups | empty list on `''` | readiness |
| Delay test | **D** | user / Phase4 `delay_test` | burst `map(async)` | any page with groups | Core up | `asyncTestDelay` | timeout/`null` → delay **-1** JSON | delay pills |
| Health observation | **C** | one-shot `Timer` interval minutes | config (default 10 min) | none (scheduler) | engine ready, lifecycle | `mediaCheck` | `?? ''` | health |
| Logs | **E + F** | Core **push** `onLogs`; UI `throttler` 300 ms | push | Logs page enables `startLog` | foreground + Logs page | `startLog` / `stopLog` | fire-and-forget | LogsView |
| Requests | **E + F** | Core **push** `onRequests`; UI 300 ms throttle | push | Requests page | foreground + Requests | event stream | — | RequestsView |
| `checkIp` | **D + C** | selection / resume / suspend | debounce | — | resume / start | `getCountryCode` | `''` → null IpInfo | IP chip |
| Session snapshot | **service IPC** | startup / `getRunTime` path | not Core `invoke` | — | Android | `Service.getSessionSnapshot` | `{}` | presence / 4A |
| `forceGc` | **C** | App paused, 60 s throttle | on pause | — | `paused` | `forceGc` | `?? false` | memory |
| Auto profile update | **A** | `application.dart` 20 min Timer | 20 min | — | app living | not Core poll | HTTP | profiles |
| SMART_STOP | **C** | network listeners | event | — | — | `smartStop` / `smartResume` **service** | bool | 4E/4F |
| Hero fill / fail timers | UI | Dashboard hero | one-shot | Dashboard | — | **no Core** | — | animation |
| Selection | **D** | tap, 600 ms per-group debounce | frozen 4C | Proxy/Dashboard picker | — | `changeProxy` / `unfixProxy` | `?? ''` treated success | 4C frozen |

## 3. Poll vs Push vs UI Batching

| Kind | Examples | Note |
|---|---|---|
| POLL_REQUIRED | `getTrafficSnapshot` 1 s on Dashboard while RUNNING+fg | Speed is not on the Core event stream |
| POLL_REQUIRED | `getConnections` 1 s on Connections page | Snapshot of live table |
| PUSH_ONLY | delay results (`CoreEventType.delay`), provider `loaded`, crash | |
| PUSH_AVAILABLE_BUT_POLL_USED | Connections page polls while Requests page uses **push** | Different UIs; not automatic replace |
| DUPLICATE_SOURCE_CANDIDATE | Dashboard latency `getConnections` vs Connections 1 s poll | Only if both pages mounted; mobile Tools+Connections gate |
| UI batching ≠ Core poll | Logs / Requests `throttler` **300 ms** | Do not remove because `Timer` exists |

`updateTraffic` is **not** a second live poller. Chart 2 s / total 5 s are **UI throttles** on one snapshot per 1 s tick.

## 4. Core IPC Architecture

```
Scheduler / Action
  → CoreController
  → CoreHandlerInterface._invoke
       wait completer ≤10s → null + log  [core_not_ready]
  → CoreLib.invoke
       Action id = method#utils.id
       Service.invokeAction (MethodChannel)
       Android ServicePlugin → RemoteService → Core.invokeAction (JNI/Go)
       Future.timeout default 3 min, onTimeout: null
       timeout Duration argument on invoke() is **not applied** in CoreLib
  → parasResult / ?? fallbacks
  → caller
```

Push: Go/native → `Service` `event` channel → `CoreEventManager` → listeners.

Instrumentation (`PHASE4_PERF` / debug / profile): `CoreIpcTrace` around `CoreLib.invoke`. Production release without define: no-op. Ring 64, durations cap 128/method.

Result classes: `success`, `core_error`, `transport_null_or_timeout`, `parse_error`, `exception`, `core_not_ready`. Timeout vs other nulls are **not** distinguished.

## 5. Method / Return Contract Matrix

See §6. Mutating methods of interest: `changeProxy`, `unfixProxy`, `setupConfig`, `updateConfig`, `startListener`/`stopListener`, provider update/sideload, `closeConnections`/`resetConnections`/`closeConnection`, `updateGeoData`.

## 6. Null / Timeout / Default Ambiguity

| Method | Raw invoke | null fallback | Empty meaning | Timeout distinguishable? | Risk |
|---|---|---|---|---|---|
| `changeProxy` | `String?` | `?? ''` | Core success is also `''` | **No** | **CRITICAL** — caller treats empty as success (close/reset skipped only on non-empty error). 4C known debt |
| `unfixProxy` | `String?` | `?? ''` | same | **No** | **CRITICAL** same |
| `setupConfig` | `String?` | `?? ''` | empty ⇒ TUN preload | **No** | **CRITICAL** — timeout can look like setup success |
| `updateConfig` | `String?` | `?? ''` | empty success | **No** | **HIGH** |
| `validateConfig` | `String?` | `?? ''` | empty success | **No** | **HIGH** |
| `startListener` / `stopListener` | `bool?` | `?? false` | false = fail | Partial (false vs timeout-false) | **HIGH** |
| `initClash` / `getIsInit` / `forceGc` / `crash` | `bool?` | `?? false` | false | Partial | **MEDIUM** |
| `getConfig` | dynamic | `Result.success({})` | empty map | **No** at interface | **HIGH** at fallback; **CoreController throws** on empty — display/setup protected |
| `getProxies` | map? | empty `ProxiesData` | no groups | **No** | **HIGH** (stale preserve exists in `_updateGroups`) |
| `getConnections` | `String?` | `''` → decode fail/empty list | empty table | **No** | **MEDIUM** display |
| `getTraffic*` | `String?` | `''` → zero Traffic | idle zeros | **No** | **LOW** display |
| `getMemory` | `String?` | `''` → 0 | — | **No** | **LOW** |
| `getExternalProviders` | `String?` | `''` → `[]` | none | **No** | **MEDIUM** |
| `asyncTestDelay` | `String?` | delay **-1** JSON | failed test | **No** | **MEDIUM** display |
| `mediaCheck` | `String?` | `''` | fail | **No** | **MEDIUM** |
| `closeConnection*` | `bool?` | `?? false` | fail | Partial | **MEDIUM** |
| `startLog` / `stopLog` / `resetTraffic` | fire-and-forget | ignored | — | **No** | **LOW** |

Device captures this round: **0** `transport_null_or_timeout`, **0** `core_error`. Ambiguity is **source-level**, not an observed incident.

Legitimate Core success **can** equal `''` for mutations. Transport null becomes the same. Callers **do** interpret `''` as success for change/unfix/setup.

## 7. Request Rate by Page

Rates from **DISPATCH in the named window**, not elapsed-ms logcat slices. RUNNING `run_id=r1787282631`.

| Method | Dashboard/min | Proxy/min | Profiles/min | Tools/min | RUNNING required |
|---|---|---|---|---|---|
| `getTrafficSnapshot` | **70.0** (21/18s) | 0 | 0 | 0 | yes (timer only if started + Dashboard) |
| `getConnections` | **86.67** (26/18s) | **30.0** (8/16s) | 0 | 0 | yes; see callers below |
| `getProxies` | 0 | 0 | 0 | 0 | Proxy enter / 30 s; not hit this window |
| `asyncTestDelay` | **0** | 0 | 0 | 0 | only the commanded delay window |
| other Core | 0 | 0 | **0** | **0** | |

Dashboard window provenance (`r1787282631-w1`): `inflight_at_start=2`, `dispatched=47`, `completed=49`, `matched=47`, `unfinished_at_end=0`, `complete_without_window_dispatch=2`.

**4D.0 Dashboard 108 `asyncTestDelay`:** after window isolation this **disappeared**. It was **old measurement contamination** (elapsed-ms slicing + shared Flutter process), not a Dashboard poller. Do not treat 360/min as product cadence.

**Who actually calls `getConnections` on Dashboard:** `CoreController.getConnections`. Product callers:

- `network_overview_card.dart` `_pollCoreConnections` — up to **18** Core polls at 160 ms while matching a latency probe
- `network_overview_card.dart` `_probeSingleTarget` — one snapshot of connection IDs before the probe
- `connections.dart` 1 s list timer when that view is allowed to refresh
- `requests.dart` (Requests page; not this Dashboard window)

The 87/min Dashboard rate and `getConnections` overlap 12 / peak_same **3** are this latency-probe burst, not leftover delay tests.

IDLE all pages: **0** Core dispatches (VPN/Core not started). Page gating of traffic poll: **yes**.

## 8. IDLE vs RUNNING

| | IDLE fg (`r1787282281`) | RUNNING fg (`r1787282631`) |
|---|---|---|
| traffic poll | none | ~1.17 Hz Dashboard, overlap **0**, p50 **12 ms** |
| Core mix | delay burst only when commanded | snapshot + connections + delay |
| peak inflight | 20 (delay-20) | 21 (delay window) |
| null/timeout class | 0 | 0 |
| VPN | absent | tun0, pid 16898 unchanged |

PAUSED (SMART_STOP) not entered naturally; not faked.

## 9. Foreground / Background

IDLE background (`r1787282281-w6`, HOME then 10 s, **no** `am start` in this window): **`forceGc` ×1**. No traffic poll.

RUNNING background (`r1787282631-w6`): `inflight_at_start=1`, **`getConnections` ×13**, **`forceGc` ×1**. No `getTrafficSnapshot` dispatch. Traffic timer cancel is visible. Connections/latency Core calls **continued** after HOME in this 10 s sample (peak_same 1, no overlap). This is observation only; **4D.0.1 did not add a background power policy.**

RUNNING resume (`r1787282631-w7`, separate window, `am start` then 8 s): `getTrafficSnapshot` ×13 (overlap 0), `getConnections` ×36 (overlap 13, peak 3). Resume edge is **not** inside the background window.

## 10. Overlap / Duplicate Requests

| Method | Context | overlap_count | peak_same | inflight_at_start |
|---|---|---|---|---|
| `getTrafficSnapshot` | Dashboard RUNNING | **0** | 1 | 2 (window) |
| `getConnections` | Dashboard RUNNING | 12 | **3** | same window |
| `asyncTestDelay` | delay-20 same window | 19 | **20** | 4 (delay window) |
| `getProxies` | Proxy this capture | — | — | 0 |

`_isUpdatingUiStats` prevents overlapping traffic ticks. Connections/latency can overlap (`peak` 3). Delay `map(async)` overlap is **by design** (4C).

## 11. IPC Latency

Matched dispatch→complete only. `core_not_ready` / preinvoke wait **not** in these tables (0 observed).

| Method | Context | n | p50 | p90 | p99 | max | Class |
|---|---|---|---|---|---|---|---|
| `getTrafficSnapshot` | RUNNING Dashboard | 21 | 12 | 15 | 16 | 16 | fast read |
| `getTrafficSnapshot` | during delay-20 | 9 | 13 | 17.6 | 19.8 | 20 | fast read |
| `getConnections` | Dashboard | 26 | 17 | 24 | 27 | 27 | fast read |
| `getConnections` | during delay-20 | 32 | 13 | 24.9 | 27.4 | 28 | fast read |
| `asyncTestDelay` | IDLE delay-20 | 20 | 199 | 321 | 677 | 754 | delay test |
| `asyncTestDelay` | RUNNING delay window | 20 | 275 | 367 | 1478 | 1718 | delay test |
| `forceGc` | IDLE / RUNNING pause | 1 | 32 / 27 | — | — | 32 | mutation |

Do not compare 500 ms provider vs 12 ms snapshot. Do not report preinvoke 10 s waits as 0 ms Core transport latency.

## 12. Resume / Reattach

RUNNING resume 8 s: traffic overlap 0, `peak_same` 1. No second traffic timer proven. Groups burst not seen (`getProxies` 0). No VPN pid/session change. VPN lifecycle still 4E.

## 13. Delay-Test Interference

Delay events scoped to `window_id` `…-w5`. RUNNING: `delay.started=20`, `finished=20`, `failed=0`, `after_map_started=20`. IPC: `asyncTestDelay` dispatched 20, matched 20. Caller: `CoreController.getDelay`. Workload is the Phase4 `delay_test` command → `delayTest` → `getDelay`, not Dashboard.

| | Dashboard baseline | During delay-20 |
|---|---|---|
| `getTrafficSnapshot` p50 | 12 ms | **13 ms** |
| `getTrafficSnapshot` overlap | 0 | 0 |
| `getConnections` p50 | 17 ms | **13 ms** |
| timeouts/nulls | 0 | 0 |
| delay peak_inflight | — | 20 |
| global peak | 4 (dashboard window) | **21** |

**ACCEPTED FOR NORMAL n=20 OBSERVATION.** n=20 RUNNING workload did not starve traffic/connections. This is **not** “all large fan-out permanently accepted.” n=100 start fan-out evidence remains **4C.1B**. No RUNNING n=100 stress in D0.1.

IDLE delay-20: 20 started / 20 finished in the same window (the old 19/20 logcat-wide count was contamination).

## 14. Correctness Findings

| ID | Finding | Evidence |
|---|---|---|
| A timeout as success | **Source CRITICAL**, **not reproduced** | 0 null class; `?? ''` still in `interface.dart` |
| B stale overwrite | Not seen for traffic | single in-flight snapshot |
| C overlapping polls | Traffic no; `getConnections` yes (peak 3); delay yes (design) | §10 |
| D poller after page gone | Traffic **stops** on Proxy/Profiles/Tools (0 snapshot) | §7 |
| E background vs documented gate | Traffic stops after HOME; `getConnections` still dispatched in RUNNING background 10 s | §9 |
| F resume duplicate pollers | Traffic peak_same=1 | §12 |
| G delay starves IPC | **No** for n=20 traffic/connections | §13 |
| H Dashboard 108 delay | **Contamination**; gone after `window_id` pairing | §7 |

No auto-fix. No 4C reopen.

## 15. Performance Findings

- Traffic IPC is cheap (~12 ms) and non-overlapping at ~1 Hz while Dashboard+RUNNING+fg.
- `getConnections` overlap is the main Dashboard IPC-efficiency issue (latency probe burst in `network_overview_card.dart`), not traffic.
- Global peak 21 dominated by delay starts, not traffic.
- Profiles/Tools: no hidden Core poll in these windows.

## 16. Phase Ownership

**4D:** mutation null/`''` contract; optional `getConnections` overlap; unused `invoke` timeout parameter; IPC observability.

**4E:** VPN start/stop/TUN/session machine (not changed). Continuity held this session.

**4F:** background power, screen-off, `forceGc` policy, residual `getConnections` after HOME.

## 17. Candidate 4D Fixes

Do **not** implement in D0 / D0.1.

1. **P0 contract (design):** distinguish transport null vs Core `''` for `changeProxy` / `unfixProxy` / `setupConfig` without breaking 4C empty-success. Evidence: source matrix; 0 live timeouts this capture.
2. **P1:** `getConnections` same-method peak 3 on Dashboard (overview latency matching). Measure whether coalescing one fetch per tick is enough.
3. **P1 hygiene:** `CoreLib.invoke` ignores `Duration? timeout` (delay’s 6 s is not the Dart `withTimeout`; default 3 min). Document vs wire.
4. **ACCEPTED FOR NORMAL n=20 OBSERVATION:** 1 Hz `getTrafficSnapshot`; delay n=20 vs other IPC; Logs/Requests 300 ms UI batch; Proxy 30 s groups gate.

## 18. Deferred to 4E / 4F

- 4E: VPN session/TUN ownership; SMART_STOP state machine.
- 4F: HOME/background request policy; pause `forceGc`; screen-off; residual connections polls.

## 19. Acceptance

| Gate | Status |
|---|---|
| Scheduler inventory | PASS |
| Poll / push / UI batch differentiated | PASS |
| IPC call-chain map | PASS |
| Return/default matrix | PASS |
| Mutating timeout-risk | PASS (source); live nulls 0 |
| Dashboard / Proxy / Profiles / Tools rates | PASS (dispatch-scoped) |
| IDLE + real RUNNING | PASS |
| fg/bg | PASS (split windows) |
| overlap + peak inflight | PASS (peak 21) |
| p50/p90/p99 | PASS for matched pairs |
| resume | PASS (no VPN break; separate window) |
| delay interference | **ACCEPTED FOR NORMAL n=20 OBSERVATION** |
| 4C frozen / Mihomo pin | PASS |
| no cadence / protocol change | PASS |
| GitHub CI | **not claimed** (no status checks) |

## 20. Local regression (4D.0.1)

| Check | Result |
|---|---|
| `flutter test test/common/core_ipc_trace_test.dart` | PASS (6 tests) |
| `python -m unittest tools.perf.tests.test_harness` | PASS (55 tests) |
| `proxy_group_selection_test` / `fixed_test` / `compute_test` | PASS |
| `provider_readiness_service_test` | PASS |
| `smart_auto_stop_test` | PASS |
| `flutter analyze` | 69 **info** findings (existing deprecations / style). No new error/warning from this change set. |
| GitHub Actions status checks | **none configured** — do not write CI PASS |

4D.0.1 complete. **STOP.** Human audit before 4D.1.
