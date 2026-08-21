# Phase 4E.0 — VPN Lifecycle Baseline

## 1. Provenance

- Repository: `songzhengpei/Slclash`; branch: `beta`.
- Authoritative start: `1a591aa025e825eebfb0abb735ac62649acb1e8b`.
- Instrumentation commit: `adc73bb8849e458565e7a47f9e6005c92cf03c1f`.
- Mihomo before and after: `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`.
- Device: serial `0604B44041A00540`, model `25042PN24C`, Android 16 / SDK 36.
- APK: `com.slclash.app.profile`, version `9.9.10` (`1`), profile/profiling, debuggable.
- Captures: `.perf-captures/phase4/e0-vpn-lifecycle-adc73bb8/result.json` and `.perf-captures/phase4/e0-vpn-smart-adc73bb8/result.json` (gitignored).
- Both captures report `git_head=adc73bb8`, `dirty=false`, and `submodule_dirty=true`. The latter is the expected buildkit Mihomo patch applied while compiling; the submodule was reset to the pinned commit after capture.

## 2. Scope

This round audited and instrumented Flutter, the Android app process, the remote service process, `SessionSnapshot`, `SessionPresence`, `VpnService`/TUN, Tile/QuickAction, and SMART_STOP/RESUME. It did not change lifecycle behavior, permission policy, locks, retry timing, Mihomo, Phase 4C selection, or Phase 4D diagnostics.

## 3. State Sources

| Source | Role | Persistence / lifetime |
|---|---|---|
| Remote `State.snapshot` | Authoritative session state while `:remote` is alive | Remote process |
| `SessionSnapshot` | Binder value contract: session identity, lifecycle state, start time, smart pause, last error | Copied across processes |
| `SessionPresence` | Durable projection of non-STOPPED remote truth; validates PID/cmdline | App files; survives Flutter/UI death |
| `VpnService` plus real `tunN` | Operational VPN/TUN fact | Remote process / Android VPN lifetime |
| App `State.sessionSnapshot`, `runTime`, `runStateFlow` | Cached and derived native-app view | Android app process |
| `RunState` | Compressed control/display projection, not full session truth | Android app process |
| Flutter `startTime`, `_nativeSession`, `_sessionState`, providers | Cached/derived UI and Core-control state | Flutter engine/process |
| Binder connection | Transport availability only | Connection lifetime |

Activity recreation can retain the Flutter engine and its providers. Flutter process death loses Flutter caches but not the remote session, TUN, or valid presence file. App-process death also loses app `State`, while the separate remote process may survive. Remote-process death removes the in-process VPN/TUN; a stale presence file is rejected by the product's `readValid` PID/cmdline check. Binder connectivity is not session liveness.

## 4. Authoritative State Contract

`RemoteService` serializes transitions under its remote `runLock` and writes `State.snapshot`. This is the authoritative lifecycle state. `SessionPresence` is its recoverable projection, and TUN observation is the independent operational invariant. Flutter reconciliation obtains native runtime/presence and then `SessionSnapshot`; it must derive UI state from those facts rather than act as a second state machine.

Direct answers to the required questions:

1. The authoritative VPN session state is remote `State.snapshot`; a valid `SessionPresence` reconciles remote truth across app-process recreation, while `VpnService` + real `tunN` proves operational VPN presence.
2. Yes. `SessionSnapshot` is the final structured truth delivered to Flutter, with `SessionPresence` used to recover/bind before the latest snapshot is available.
3. Yes. External SMART_STOP left live Flutter at `isStart=true`, `isSmartStopped=false` until recreation; PAUSED toggle resume left `isSmartStopped=true` after native RUNNING. Normal START/STOP converged.
4. RUNNING reattach reconnects/initializes Core and runs current setup/apply/listener reconciliation, but device evidence shows no remote start dispatch, no TUN recreation, no new session, and no remote restart. The setup/apply calls are therefore recorded as current reconciliation, not proven unnecessary work.
5. Yes. PAUSED retains sessionId, startedAt, remote service/Core context and `smartPaused=true`, while TUN is absent. STOPPED resets identity/presence and unloads the full VPN session.
6. The mapping itself is accepted, but two consumers expose real bugs: explicit STOP while PAUSED is ignored, and TOGGLE resumes native while Flutter can retain its paused provider.
7. No duplicate native start was observed. Several high-level start intents/marks converged to exactly one `vpn_service_dispatch action=start` per start window.
8. STOP during STARTING was not safely reproduced. Current PENDING guards ignore the stop/toggle rather than queue or cancel it; classify this as a source-level watch, not a reproduced stuck state.
9. A binder disconnect is not fabricated as STOPPED. UI-side disconnect rebinds/reconciles; remote background-service disconnect moves an active snapshot to STOPPING with an error. Remote death itself also destroys the co-located VPN/TUN.
10. sessionId stayed stable through RUNNING reattach and SMART_STOP/RESUME. Navigation, node selection, and Dashboard diagnostics contain no lifecycle dispatch and retained continuity in their closed-phase evidence; they were not re-stressed in 4E.0. A true STOP followed by START created a new identity as designed.
11. Yes. Every confirmed full STOP removed `tun0`; `STOPPING -> STOPPED` followed the TUN stop-complete mark.
12. QuickAction/TempActivity START and STOP converged correctly. Tile derives from a fresh snapshot on `onStartListening`; actual system-shade clicking was not automated. PAUSED STOP/TOGGLE consumer defects are separately recorded.
13. Current mutexes/guards prevented duplicate native starts and serialized remote/TUN operations. They also make PENDING actions no-ops; no evidence justifies changing lock behavior in 4E.0.
14. Duplicated cached/derived state causes user-visible convergence issues only in the three P1 SMART/PAUSED paths below. Normal START, STOP, restart, and reattach converged.

## 5. Native State Machine

The native contract has `STOPPED`, `STARTING`, `RUNNING`, `PAUSED`, and `STOPPING`; there is no `UNKNOWN` enum value. Transport uncertainty is represented by a pending/cached state and reconciliation, not by claiming STOPPED.

| Session state | `RunState` | Identity | Presence | Expected TUN |
|---|---|---|---|---|
| STOPPED | STOP | reset | deleted | absent |
| STARTING | PENDING | new/stable | written | establishing |
| RUNNING | START | stable | written | present |
| PAUSED | STOP | stable | written, smart paused | absent |
| STOPPING | PENDING | stable until completion | written | removing |

The extracted pure `runStateForSessionState` preserves the existing mapping and maps unknown strings to STOP. Its test is a contract baseline, not a redesign.

## 6. Flutter State Interpretation

`isStartProvider` is derived from `runTimeProvider != null`. `isSmartStoppedProvider`, `suspendProvider`, and `coreStatusProvider` are UI/Core-control state. `startTime`, `_nativeSession`, and `_sessionState` are Flutter caches. Flutter writes `runTimeProvider` optimistically during local stop/start handling, but normal paths later reconcile from the native snapshot.

| Native input on init | Core connect/init | Full setup/profile | Native VPN start | Flutter result |
|---|---|---|---|---|
| RUNNING | yes / yes | yes; groups deferred to apply | app guard prevents remote restart | running; runtime restored |
| STARTING | yes / yes | yes | PENDING guard prevents duplicate dispatch | pending/unconfirmed until snapshot |
| PAUSED / smartPaused | attach + ensure ready | no | no | stopped display + smart-stopped restored |
| STOPPING | no unless auto-run | no | no | stopped/pending native projection; reconcile later |
| STOPPED | no unless auto-run | no | only if auto-run | stopped |
| unavailable / unknown | no unless auto-run | no | no confirmed start | stopped/cache unavailable |

PAUSED reopen emitted `smart_paused_restored` and `paused_core_attached`, without `setupConfig`/`applyProfile` or native start.

## 7. START Lifecycle

Entry points are Flutter `updateStatus(true)`, TempActivity START/TOGGLE, Tile TOGGLE, and init/auto-run. The Android app checks/sets PENDING, performs notification and VPN permission preparation, then dispatches `Service.startService`. Remote STOPPED creates one new sessionId and STARTING snapshot, writes presence, binds/starts `VpnService`, establishes TUN, calls `Core.startTun`, and commits RUNNING. App and Flutter then consume snapshots.

Failure/unknown points include missing VPN options, permission cancellation, setup failure, binder failure, unsuccessful service result, and a snapshot that remains unavailable/STARTING. The code retains PENDING or reconciles rather than converting an unknown result into success.

Idempotency: RUNNING start returns the existing session; PAUSED start routes to smart resume and preserves identity; STARTING/PENDING app guards do not dispatch another start. Device windows each recorded one native start dispatch and one `tun0`.

## 8. STOP Lifecycle

Flutter stop first stops its listener and clears derived UI runtime, then the Android app dispatches remote stop. Remote RUNNING becomes STOPPING, presence is updated, `VpnService.shutdown` stops TUN/unloads modules/stops itself, and remote state becomes STOPPED with presence deleted. Failed/unconfirmed shutdown does not fabricate STOPPED.

Duplicate STOP and STOP while already STOPPED are guarded. STOP/TOGGLE while app `RunState=PENDING` is ignored; there is no cancellation queue. Explicit STOP while PAUSED is also ignored because PAUSED projects to STOP and the stop guard requires START—this is a reproduced P1 consumer defect.

## 9. RUNNING Reattach

In `running_reattach`, session `1787294591996`, remote PID `15316`, and `tun0` were unchanged across UI-process kill/reopen. Native start/stop dispatch counts were both zero. Flutter reconnected Core and emitted current setup/profile/listener reconciliation marks. No second VPN start, duplicate TUN, new session, or remote restart occurred.

## 10. PAUSED / SMART_STOP / SMART_RESUME

SMART_STOP changed RUNNING to PAUSED, kept sessionId/startedAt/remote PID, set native smartPaused, called `Core.stopTun`, and removed `tun0` without unloading the remote session. PAUSED reopen attached Core without VPN setup, restored the smart-stopped provider, and retained no TUN. Explicit SMART_RESUME established/started one TUN and returned PAUSED to RUNNING without a full native start dispatch or identity change.

While Flutter was already alive, external SMART_STOP did not update its providers. PAUSED TOGGLE invoked the start path, which correctly resumed native/TUN, but Flutter remained smart-stopped. These are convergence defects, not failures of the remote state machine.

## 11. Tile / QuickAction

Tile calls `State.handleSyncState()` on start-listening and then collects `runStateFlow`: START is active, PENDING unavailable, STOP inactive. TempActivity dispatches START, STOP, TOGGLE, SMART_STOP, and SMART_RESUME into the same app/native control plane.

Live QuickAction evidence proved STOPPED START, RUNNING STOP, external SMART_STOP, explicit SMART_RESUME, PAUSED STOP, and PAUSED TOGGLE. Normal START/STOP converged. PAUSED STOP was a no-op; PAUSED TOGGLE resumed native but left Flutter smart-paused. Actual QS shade rendering/click automation was not available, so Tile display is source/pure-mapping evidence plus eventual sync, not a claim of an automated visual test.

## 12. SessionSnapshot

Fields are `sessionId`, `state`, `startedAt`, `smartPaused`, `lastErrorCode`, and `lastErrorMessage`. A new identity is created only for STOPPED -> STARTING. STARTING -> RUNNING, RUNNING -> PAUSED, and PAUSED -> RUNNING preserve it. STOPPING preserves it until STOPPED resets the snapshot. `getRunTime` is non-zero only for RUNNING; PAUSED deliberately returns no running runtime to the app display.

Invariants established: one live session identity; RUNNING requires TUN; PAUSED keeps identity without TUN; STOPPED has no valid presence/TUN; true STOP then START may create a new identity.

## 13. SessionPresence

The same-UID file `files/remote_session_presence.txt` is atomically written via temp/rename for every non-STOPPED snapshot and deleted at STOPPED. `readValid` verifies PID liveness and readable cmdline; an OEM-hidden cmdline is trusted only while the PID is alive. A stale record can remain after abrupt force-stop—the first `all` raw harness snapshot saw an old RUNNING record while the remote PID/TUN were absent—but the product validation rejects it, and the first action window had no valid session.

## 14. Binder / Remote Process

Flutter UI process, Android app process, remote service/Core process, VPN/TUN, binder, and snapshot state are six distinct facts. App `ServiceDelegate` reconnects and requests a snapshot after transport loss. Remote background delegate disconnect sets an active snapshot to STOPPING with an error instead of claiming confirmed STOPPED. `RemoteService.onDestroy` avoids tearing down a non-STOPPED VPN merely because its wrapper is being destroyed. The remote PID may remain alive after a normal STOP and must not be treated as proof of an active session.

## 15. TUN Invariants

- RUNNING observations had exactly one `tun0` and a running `VpnService`.
- PAUSED observations had no TUN while preserving remote/session identity.
- Full STOP removed TUN before STOPPED/presence deletion.
- Reattach did not create a second TUN.
- No RUNNING-without-TUN, STOPPED-with-TUN, PAUSED-with-TUN, or multiple-TUN observation flag occurred.

## 16. Race Inventory

| Race / edge | Result | Classification |
|---|---|---|
| one START producing repeated high-level intents | one native dispatch | ACCEPTED; guards effective |
| START while RUNNING | existing state returned | ACCEPTED |
| START from PAUSED | resumes same session | ACCEPTED, except stale Flutter smart flag via TOGGLE |
| duplicate STOP / STOP while STOPPED | guarded | ACCEPTED |
| STOP or TOGGLE while PENDING | ignored, not queued | KNOWN RISK / WATCH |
| START then STOP before RUNNING | not safely reproduced | KNOWN RISK / WATCH |
| STOP then START before completion | PENDING guard; not safely reproduced | KNOWN RISK / WATCH |
| permission cancel/background | source audited, not exercised | KNOWN RISK / WATCH |
| Flutter closes/reopens STARTING or STOPPING | source audited, not destabilized | KNOWN RISK / WATCH |
| SMART_STOP during another transition | guarded remotely; not exercised | KNOWN RISK / WATCH |

## 17. Real Device Timing

Harness timing includes ADB calls and 250 ms polling, so it is convergence time rather than UI-frame latency.

| Window | Convergence | Identity / PID / TUN result |
|---|---:|---|
| Flutter START 1 | 1844 ms | new session; PID 15316; `tun0` |
| Flutter STOP 1 | 936 ms | presence removed; PID may remain; TUN gone |
| Flutter START 2 | 1827 ms | new session; same remote PID; `tun0` |
| SMART_STOP | 563 ms | same session/PID; TUN gone |
| PAUSED STOP | 608 ms | remained PAUSED; no dispatch |
| PAUSED TOGGLE | 531 ms | same session/PID; TUN restored |
| explicit SMART_RESUME | 532 ms | same session/PID; TUN restored; no full start dispatch |
| QuickAction START without Flutter | 1545 ms | new session; same remote PID; `tun0` |
| QuickAction final STOP | 625 ms | TUN gone |

The independent SMART capture reproduced the same results (SMART_STOP 577 ms, PAUSED STOP 672 ms, PAUSED TOGGLE 577 ms, explicit resume 546 ms).

## 18. User-visible Observations

Normal buttons converged without duplicate native work. START takes longer than the native transition because Core/profile work, broadcasts, ADB polling, and UI confirmation are included. STOP showed a brief optimistic Flutter-stopped interval before native confirmation, but confirmation followed quickly. Reattach retained the VPN without visible lifecycle restart. The meaningful UI defects are stale SMART state after external actions and the PAUSED STOP/TOGGLE semantics.

## 19. P0 Findings

None. No duplicate session/TUN, false confirmed STOPPED, TUN leak after confirmed stop, identity loss during reattach, or lifecycle restart was observed.

## 20. P1 Findings

1. External SMART_STOP while Flutter is alive changes native RUNNING -> PAUSED and removes TUN, but Flutter can remain `isStart=true`, `isSmartStopped=false` until recreation.
2. Explicit STOP QuickAction while PAUSED is a no-op because PAUSED -> `RunState.STOP` and the stop guard accepts only START.
3. PAUSED TOGGLE resumes native to RUNNING and restores TUN, but Flutter can retain `isSmartStopped=true`, creating a native-RUNNING / Flutter-paused contradiction.

## 21. P2 Findings

None promoted. Timing includes harness overhead and all correct transitions completed within the observation windows. No cosmetic timing change is justified by this baseline.

## 22. Known Risks / Watch

- PENDING actions are ignored rather than cancelled/queued.
- STARTING/STOPPING recreation and permission-dialog races were audited in source but not intentionally destabilized.
- RUNNING reattach performs setup/profile reconciliation; evidence proves it does not restart VPN, but future work may measure whether any part is redundant.
- `RunState` cannot express transport-unknown or distinguish PAUSED from STOPPED; consumers must use `SessionSnapshot` when that distinction matters.

## 23. Accepted Behaviors

- PAUSED -> `RunState.STOP` is accepted as a compact display/control projection; only the identified consumers need contract review.
- Remote PID surviving STOP is harmless and is not session truth.
- True STOP followed by START receives a new session identity.
- Flutter local stop is optimistic derived UI; normal evidence converged to native STOPPED.
- RUNNING reattach's current Core/setup/profile reconciliation is accepted because no VPN/TUN/session restart occurred.

## 24. Deferred to Phase 4F

Background CPU, wakeups, foreground-service power, notification cost, and long-duration OEM process behavior were not measured or changed.

## 25. Regression

- `flutter analyze`: completed with the existing 69 info-level diagnostics; no new error or warning. This is not described as clean.
- Focused Flutter Phase 4C/4D/4E suite: 180 tests passed.
- Python harness: 60 tests passed.
- Android `:app:testDebugUnitTest :service:testDebugUnitTest`: `BUILD SUCCESSFUL`; 353 tasks, 8 executed / 345 up-to-date.
- Profile APK build: success, 74.7 MB. Kotlin cross-drive incremental-cache errors fell back to non-incremental compilation before success.
- Both device capture commands: result `ok=true`, `errors=[]`, `unreliable=[]`.

## 26. CI Truth

GitHub API for baseline `1a591aa0` reported zero check runs and zero commit statuses (`pending` aggregate only because no statuses exist). Local tests PASS. CI PASS is not claimed.

## 27. Mihomo Pin

Before audit, before clean capture build, and after all tests/cleanup, `core/Clash.Meta` resolved to `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`. Buildkit temporarily applies the repository's proxy-only traffic patch during compilation; both the temporary and main submodules were reset afterward. No Mihomo change is committed.

## 28. Candidate Phase 4E.1 Work

Human audit should decide whether to authorize, in evidence order:

1. P1: reconcile live Flutter providers when an external SMART_STOP changes native snapshot.
2. P1: define explicit STOP behavior for PAUSED instead of silently rejecting the user request.
3. P1: make PAUSED Tile/TOGGLE resume clear/reconcile Flutter smart-paused state.

Any implementation should stay consumer-scoped and preserve the remote state machine, PAUSED identity, current locks, permission flow, retry timing, and TUN behavior.

## 29. STOP Decision

Phase 4E.0 has established the state contract, observer-only instrumentation, deterministic tests, and real-device baseline. No lifecycle behavior fix is included. STOP here for human audit; do not begin 4E.1, 4F, or state-machine refactoring automatically.
