# Phase 4E.1 — PAUSED Control-Plane Convergence

## 1. Original P1 defects

Phase 4E.0 found three control-plane convergence defects:

1. External `SMART_STOP` with a live Flutter engine paused the native session and removed TUN, but Flutter could remain `isStart=true` and `isSmartStopped=false`.
2. Explicit `STOP` was rejected while the authoritative native session was `PAUSED`.
3. `TOGGLE` from `PAUSED` resumed the native session and TUN, but Flutter could retain `isSmartStopped=true`.

This round fixes only those defects. It does not redesign the lifecycle state machine or address transition cancellation.

## 2. Root-cause analysis

`RunState` intentionally compresses both `PAUSED` and `STOPPED` to `STOP`. Android command routing incorrectly treated that display projection as complete command truth. External smart pause also bypassed Flutter when its engine was alive, while smart resume already used a Flutter callback. Finally, Flutter full-stop handling rejected a paused session because `isStart` was false.

The remote `SessionSnapshot` is now refreshed before `TOGGLE` and external `STOP` decisions. Routing distinguishes `RUNNING`, `PAUSED`, `STOPPED`, and transition states without changing `RunState` mapping.

## 3. Hidden listener/full-stop coupling

Before 4E.1, `SetupAction.handleSmartStopLocal()` called `CoreController.stopListener()`. On Android that reached `CoreLib.stopListener()`, which stopped the Core listener and invoked native `service.stop()`. A smart-paused session survived only because `State.handleStopService()` rejected compressed `RunState.STOP`.

Allowing PAUSED through that old guard alone would therefore have converted ordinary SMART_STOP into a real STOP.

## 4. Listener-only contract

`CoreInterface`, `CoreHandlerInterface`, and `CoreController` now expose `stopCoreListenerOnly()`.

- Base implementation invokes only `ActionMethod.stopListener`.
- Android full `CoreLib.stopListener()` still performs listener stop followed by native service stop.
- `SetupAction.handleSmartStopLocal()` uses listener-only stop.
- No runtime cast or Android-specific type check was added to `CoreController`.

Deterministic tests prove listener-only delegation never calls the full-stop operation and full `stopListener` preserves listener-then-service ordering.

## 5. SessionState command-decision contract

The accepted compressed projection is unchanged:

| Session state | RunState |
| --- | --- |
| `RUNNING` | `START` |
| `STARTING`, `STOPPING` | `PENDING` |
| `PAUSED`, `STOPPED` | `STOP` |

Lifecycle commands use authoritative `SessionSnapshot.state`:

| State | TOGGLE | Explicit STOP |
| --- | --- | --- |
| `RUNNING` | full STOP | full STOP |
| `PAUSED` | SMART_RESUME | full STOP |
| `STOPPED` | full START | no-op |
| `STARTING`, `STOPPING` | no-op | no-op |

## 6. External SMART_STOP routing

When Flutter is alive, Android `State.handleSmartStopAction()` now dispatches `TilePlugin.handleSmartStop()` and returns. The Dart tile channel calls `TileListener.onSmartStop()`, and `TileManager` calls the public `SmartAutoStopManager.pauseNow()` entry point.

`pauseNow()` reuses the same confirmed `_smartStop()` workflow as trusted-network automation. Native success is required before native/Flutter smart-pause flags and listener-only local shutdown converge.

## 7. PAUSED TOGGLE routing

Android refreshes the remote snapshot and maps `PAUSED + TOGGLE` to `handleSmartResumeAction()`, not generic start. With Flutter alive, the existing tile callback reaches `SmartAutoStopManager.resumeNow()`.

This retains the manual-resume override contract, restores the Core listener and TUN, and clears `isSmartStoppedProvider` after confirmed native resume.

## 8. PAUSED explicit STOP behavior

The pure `canFullStopSession()` helper permits full stop only for `RUNNING` and `PAUSED`. Both external stop routing and the native full-stop implementation use that contract. Flutter tile stop now proceeds when either `isStart` or `isSmartStopped` is true and reuses `SetupAction.updateStatus(false)`.

`STARTING`, `STOPPING`, and `STOPPED` remain non-cancellable/idempotent in this round.

## 9. Provider convergence

A true full stop clears the smart-auto-stop manual override and `isSmartStoppedProvider` before normal full-stop cleanup. The observed terminal Flutter state is:

- `isStart=false`
- `isSmartStopped=false`
- `runTime=null`

Smart pause remains distinct: `isStart=false`, `isSmartStopped=true`, runtime cleared, listener stopped, and the remote session remains present as `PAUSED`.

## 10. Automatic SMART_STOP regression

The profile harness gained an instrumentation-only command to enable a matching trusted-network rule. No external SMART_STOP command was sent for this window.

`automatic_smart_stop` passed:

- `RUNNING → PAUSED`
- session `1787296980135 → 1787296980135`
- remote PID `16144 → 16144`
- `tun0 → absent`
- Flutter `isStart=false`, `isSmartStopped=true`
- full start dispatches `0`; full stop dispatches `0`

This proves listener-only/full-stop separation did not turn automatic smart pause into STOPPED.

## 11. SessionId, PID, TUN, and transition evidence

Device: `25042PN24C`, Android 16, profile package `com.slclash.app.profile`, version `9.9.10`.

Primary capture: `.perf-captures/phase4/e1-paused-convergence-final/result.json` (`ok=true`, `vpn.ok=true`, no unreliable windows).

| Window | Native transition | Session | Remote PID | TUN | Flutter start/paused | Full dispatch |
| --- | --- | --- | --- | --- | --- | --- |
| External SMART_STOP | `RUNNING→PAUSED` | `1787296980135` unchanged | `16144` unchanged | `tun0→absent` | `false/true` | start 0, stop 0 |
| PAUSED TOGGLE | `PAUSED→RUNNING` | unchanged | unchanged | `absent→tun0` | `true/false` | start 0, stop 0 |
| Explicit SMART_RESUME | `PAUSED→RUNNING` | unchanged | unchanged | `absent→tun0` | `true/false` | start 0, stop 0 |
| Automatic SMART_STOP | `RUNNING→PAUSED` | unchanged | unchanged | `tun0→absent` | `false/true` | start 0, stop 0 |
| PAUSED explicit STOP | `PAUSED→STOPPING→STOPPED` | presence deleted | process retained | absent | `false/false` | start 0, stop 1 |

The explicit-stop trace includes `vpn_session_presence operation=delete state=STOPPED`, `smart_paused=false`, and no TUN.

Running Dashboard→proxy selection→Dashboard evidence is in `.perf-captures/phase4/e1-running-proxy-continuity/result.json`: `continuity_ok=true`, session `1787297050963` unchanged, remote PID `19550` unchanged, and `tun0` present before/after. The larger proxy workload reported `ok=false` only because its existing 4C selection ACK ordering criterion was not met (`ack_bound_to_latest_only=false`); lifecycle continuity itself passed and no 4E change was made for that unrelated observation.

## 12. Deterministic tests

Focused plus frozen 4C/4D Flutter suite: **196 passed**.

Coverage includes:

- all TOGGLE and full-stop state decisions;
- unchanged PAUSED→RunState.STOP mapping;
- listener-only versus full native stop;
- Android-to-Dart smart-stop callback dispatch;
- confirmed smart-stop and smart-resume convergence;
- full-stop provider clearing;
- smart-resume native start-time identity;
- network diagnostics, command outcome, Core IPC trace;
- proxy selection, fixed/compute helpers, provider readiness, and SMART_STOP.

## 13. Analyze

`flutter analyze` completed with **0 errors and 0 warnings**. It reports 69 pre-existing info-level lints. This round introduced no new analyzer finding.

## 14. Android, Python, build, and CI truth

- Android `:app:testDebugUnitTest`: PASS.
- Android `:service:testDebugUnitTest`: PASS.
- Python perf harness: 60 tests PASS.
- Profile arm64 APK build: PASS (`app-profile.apk`, 96.3 MB).
- Profile overlay install: PASS.
- Hosted CI was not run before these commits; no hosted-CI result is claimed. Local Android/Flutter/Python results and raw device captures are the evidence for this round.

## 15. Mihomo pin

Before and after: `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`.

The profile build temporarily applied the repository-owned proxy-traffic build patch inside the submodule. Those build-time working-tree changes were removed after the APK was produced; the submodule is clean and its commit did not move.

## 16. Remaining WATCH items

Unchanged and not fixed in 4E.1:

- STOP/TOGGLE while PENDING;
- START→STOP before RUNNING;
- STOP→START before stop completion;
- permission-dialog races;
- STARTING/STOPPING reopen behavior;
- binder transport redesign;
- RUNNING reattach setup/profile work;
- background power behavior.

The proxy workload's existing ACK-order observation is also outside the lifecycle scope. Frozen 4C deterministic tests passed.

## 17. Proposed Phase 4E closeout decision

The three evidence-backed P1 defects converge under deterministic and real-device evidence. Automatic SMART_STOP remains PAUSED, session identity survives pause/resume, and PAUSED explicit STOP is now a real terminal stop.

Recommendation: **Phase 4E Final Closeout**, subject to human audit. Do not create 4E.2 or begin 4F from this result.
