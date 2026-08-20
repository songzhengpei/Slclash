# Phase 4D.0 — Runtime Polling / Core IPC Baseline

Measurement only. No poll-interval, timeout, mutex, delay-limiter, VPN, or Mihomo changes. Phase 4C remains CLOSED / frozen.

## 1. Provenance

| Field | Value |
|---|---|
| closeout / 4D start base | `afea7b90121a49fd3593f9985b48ed862b09acba` |
| housekeeping | `da6d43b1` (`docs: fill Phase 4C closeout regression placeholders`) |
| instrumentation | `047d4a8c34b9973c408e5f2d27e3bb27142077dc` |
| pinned Mihomo before/after | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` (unchanged) |
| local Clash.Meta worktree | leftover dirty files were present and **not** committed |
| device | `25042PN24C` serial `0604B44041A00540` |
| package | `com.slclash.app.profile` `9.9.10` profile / `PHASE4_PERF=true` |
| captures | `tools/perf/results/phase4d0/{idle,running,lifecycle,delay-interference}/` |
| raw (gitignored) | `.perf-captures/phase4/d0-idle/`, `d0-running/` |

IDLE: VPN absent. RUNNING: `tun0`, VpnService, remote pid `24601`, sessionId `1787226145295`, `continuity_ok=true` before/after.

Command: `python tools/perf/phase4.py ipc --ipc-session idle|running --build-mode profile`. Never force-stops.

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

RUNNING foreground (18/16/12/12 s windows). Per-min from window counts.

| Method | Dashboard/min | Proxy/min | Profiles/min | Tools/min | RUNNING required |
|---|---|---|---|---|---|
| `getTrafficSnapshot` | **66.7** (20/18s) | 0 | 0 | 0 | yes (timer only if started) |
| `getConnections` | **20** (6/18s) | 0 | 0 | 0 | Dashboard latency host |
| `getProxies` | 0 | **3.75** (1/16s) | 0 | 0 | Proxy enter / 30 s |
| `getIsInit` | 0 | 3.75 | 0 | 0 | Proxy path |
| `asyncTestDelay` | 360* | 52.5* | 0 | 0 | burst; *see caveats |
| other Core | 0 | 0 | **0** | **0** | |

IDLE all pages: **0** Core completes (VPN/Core not started). Page gating of traffic poll: **yes** (no snapshot off Dashboard; none when IDLE).

\* Dashboard `asyncTestDelay` 108 completes in the 18 s window is **not** the 1 s traffic poll. Overlap peak 10. Likely in-flight delay/health/start tests sharing process logcat/window. Do not treat 360/min as a Dashboard poller.

## 8. IDLE vs RUNNING

| | IDLE fg | RUNNING fg |
|---|---|---|
| traffic poll | none | ~1 Hz Dashboard, overlap **0**, p50 **7 ms** |
| Core mix | delay burst only when commanded | snapshot + connections + proxies + delay |
| peak inflight | 20 (delay-20) | 22 (delay window) |
| null/timeout class | 0 | 0 |
| VPN | absent | tun0, pid 24601 unchanged |

PAUSED (SMART_STOP) not entered naturally; not faked.

## 9. Foreground / Background

IDLE background window: **`forceGc` ×1** (pause path). No traffic poll.

RUNNING `background` window (includes HOME + resume `am start` edge, **not** a pure screen-off sample):

- `getTrafficSnapshot` ×4, `getConnections` ×22, `forceGc` ×1
- Cannot claim “poll fully stops” from this window; 4F must measure after timer cancel with a dump that does not use `am start`.

**IPC-CORRECTNESS:** traffic timer is *intended* cancelled on background (`cancelUiStatsTimer`).  
**POWER-CANDIDATE (4F):** `forceGc` on pause; any residual snapshot/connections if they continue after true pause.

## 10. Overlap / Duplicate Requests

| Method | Context | overlap_count | peak_same |
|---|---|---|---|
| `getTrafficSnapshot` | Dashboard RUNNING | **0** | 1 |
| `getConnections` | Dashboard / delay / resume | 5–7 | 3 |
| `asyncTestDelay` | delay-20 | 19 | **20** |
| `getProxies` | Proxy | 0 | 1 |

`_isUpdatingUiStats` prevents overlapping traffic ticks. Connections/latency can overlap (`peak` 3). Delay `map(async)` overlap is **by design** (4C).

Old result overwriting newer traffic state: not evidenced (single in-flight snapshot). Groups owner guard still applies (4C freeze).

## 11. IPC Latency

| Method | Context | n | p50 | p90 | p99 | max | Class |
|---|---|---|---|---|---|---|---|
| `getTrafficSnapshot` | RUNNING Dashboard | 20 | 7 | 12.2 | 15.6 | 16 | fast read |
| `getTrafficSnapshot` | during delay-20 | 5 | 7 | 9 | 9 | 9 | fast read |
| `getConnections` | Dashboard | 6 | 18.5 | 25.5 | 26.9 | 27 | fast read |
| `getConnections` | during delay-20 | 20 | 6 | 12.2 | 14.8 | 15 | fast read |
| `getProxies` | Proxy | 1 | 57 | 57 | 57 | 57 | state read |
| `asyncTestDelay` | IDLE delay-20 | 20 | 182 | 309 | 627 | 693 | delay test |
| `asyncTestDelay` | RUNNING delay window | 20 | 271 | 330 | 606 | 663 | delay test |
| `forceGc` | pause | 1 | 27–41 | — | — | 41 | mutation |

Do not compare 500 ms provider vs 7 ms snapshot.

## 12. Resume / Reattach

RUNNING resume 8 s window: `getTrafficSnapshot` ×10 (overlap 0), `getConnections` ×19 (overlap 5, peak 3). No second traffic timer proven (`peak_same` 1). Groups burst not seen in this 8 s (groups already owned). `tryStartCore` / `ensureCurrentProfileReady` not visible as extra `getProxies` here.

No VPN pid/session change. VPN lifecycle still 4E.

## 13. Delay-Test Interference

Question: does delay fan-out starve unrelated Core IPC?

RUNNING delay-20 vs Dashboard traffic baseline:

| | Dashboard baseline | During delay-20 |
|---|---|---|
| `getTrafficSnapshot` p50 | 7 ms | **7 ms** |
| `getTrafficSnapshot` overlap | 0 | 0 |
| `getConnections` p50 | 18.5 ms | **6 ms** |
| timeouts/nulls | 0 | 0 |
| delay peak_inflight | — | 20 |
| global peak | 14 (dashboard window) | **22** |

**DELAY FAN-OUT ACCEPTED** for n=20 vs traffic/connections latency. No limiter. Re-check only if 4D.1 sees queue saturation at larger n or vs `setupConfig`/`changeProxy`.

IDLE delay-20: 20 success, peak 20, p50 182 ms. `delay.finished` 19 vs 20 started = logcat/end-race, not 0-fail product (`failed=0`).

n=100 not repeated this round (RUNNING stay 20; IDLE used 20). 4C.1B still owns n=100 start-fan-out evidence.

## 14. Correctness Findings

| ID | Finding | Evidence |
|---|---|---|
| A timeout as success | **Source CRITICAL**, **not reproduced** | 0 null class; `?? ''` still in `interface.dart` |
| B stale overwrite | Not seen for traffic | single in-flight snapshot |
| C overlapping polls | Traffic no; `getConnections` yes (peak 3); delay yes (design) | §10 |
| D poller after page gone | Traffic **stops** on Proxy/Profiles/Tools (0 snapshot) | §7 |
| E background vs documented gate | Intended cancel; RUNNING HOME window **contaminated** by resume start | §9 |
| F resume duplicate pollers | Traffic peak_same=1 | §12 |
| G delay starves IPC | **No** for n=20 traffic/connections | §13 |

No auto-fix. No 4C reopen.

## 15. Performance Findings

- Traffic IPC is cheap (~7 ms) and non-overlapping at 1 Hz while Dashboard+RUNNING+fg.
- `getConnections` overlap is the main Dashboard IPC-efficiency issue (latency host), not traffic.
- Global peak 22 dominated by delay starts, not traffic.
- Profiles/Tools: no hidden Core poll in these windows.

## 16. Phase Ownership

**4D:** mutation null/`''` contract; optional `getConnections` overlap; unused `invoke` timeout parameter; IPC observability.

**4E:** VPN start/stop/TUN/session machine (not changed). Continuity held this session.

**4F:** background power, screen-off, `forceGc` policy, residual polls after pause.

## 17. Candidate 4D Fixes

Do **not** implement in D0.

1. **P0 contract (design):** distinguish transport null vs Core `''` for `changeProxy` / `unfixProxy` / `setupConfig` without breaking 4C empty-success. Evidence: source matrix; 0 live timeouts this capture.
2. **P1:** `getConnections` same-method peak 3 on Dashboard (latency matching). Measure whether coalescing one fetch per tick is enough.
3. **P1 hygiene:** `CoreLib.invoke` ignores `Duration? timeout` (delay’s 6 s is not the Dart `withTimeout`; default 3 min). Document vs wire.
4. **ACCEPTED:** 1 Hz `getTrafficSnapshot`; delay n=20 fan-out vs other IPC; Logs/Requests 300 ms UI batch; Proxy 30 s groups gate.

## 18. Deferred to 4E / 4F

- 4E: VPN session/TUN ownership; SMART_STOP state machine.
- 4F: HOME/background request policy; pause `forceGc`; screen-off.

## 19. Acceptance

| Gate | Status |
|---|---|
| Scheduler inventory | PASS |
| Poll / push / UI batch differentiated | PASS |
| IPC call-chain map | PASS |
| Return/default matrix | PASS |
| Mutating timeout-risk | PASS (source); live nulls 0 |
| Dashboard / Proxy / Profiles / Tools rates | PASS |
| IDLE + real RUNNING | PASS |
| fg/bg | PASS with HOME-window caveat |
| overlap + peak inflight | PASS (peak 22) |
| p50/p90/p99 | PASS for sampled methods |
| resume | PASS (no VPN break) |
| delay interference | PASS → **DELAY FAN-OUT ACCEPTED** (n=20) |
| 4C frozen / Mihomo pin | PASS |
| no cadence / protocol change | PASS |

4D.0 complete. Wait for human audit before 4D.1.
