# Phase 4E — Final VPN Lifecycle Closeout

## Provenance

- Repository: `songzhengpei/Slclash`; branch: `beta`.
- Phase 4E.0 starting baseline: `1a591aa025e825eebfb0abb735ac62649acb1e8b`.
- Phase 4E.0 instrumentation: `adc73bb8849e458565e7a47f9e6005c92cf03c1f`.
- Phase 4E.0 baseline document: `24fae63707f4fb895661c0bee5f6d0aa0a486d68`.
- Phase 4E.1 implementation: `3469b0625f9c468dde5257387c65e7521dad5082`.
- Phase 4E.1 evidence and accepted close point: `d1051d5bcd0aa34c4844c8f55a6df75ccccc92bd`.
- Device evidence: `25042PN24C`, Android 16 / SDK 36, profile package `com.slclash.app.profile`.
- Pinned Mihomo before and after: `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`.

## Authoritative state contract

The remote service's serialized `SessionSnapshot` is authoritative lifecycle truth. `SessionPresence` is its recoverable cross-process projection, and Android `VpnService` plus an observed `tunN` interface is the independent operational invariant. Binder connectivity, remote-process liveness, app `RunState`, and Flutter providers are not substitutes for the authoritative snapshot.

The accepted compressed mapping remains:

| Session state | RunState |
| --- | --- |
| `RUNNING` | `START` |
| `STARTING`, `STOPPING` | `PENDING` |
| `PAUSED`, `STOPPED` | `STOP` |

Commands that must distinguish PAUSED from STOPPED use `SessionSnapshot.state`, not `RunState` alone.

## Phase 4E.1 P1 defects and resolution

Phase 4E.0 reproduced three P1 convergence defects:

1. External SMART_STOP with live Flutter paused native/TUN but left stale running/not-paused Flutter state.
2. Explicit STOP while authoritative native state was PAUSED was a no-op.
3. PAUSED TOGGLE resumed native/TUN but could retain Flutter `isSmartStopped=true`.

Phase 4E.1 resolved all three without redesigning the remote state machine.

## Listener-only and full-stop separation

`stopCoreListenerOnly()` now invokes only Core `ActionMethod.stopListener`. Android full `CoreLib.stopListener()` retains listener stop followed by native service stop. SMART_STOP local convergence uses listener-only shutdown, so PAUSED no longer survives through an accidental native stop guard and enabling PAUSED full STOP cannot convert automatic smart pause into STOPPED.

## PAUSED command routing

Authoritative command semantics are:

- `RUNNING + TOGGLE` → full STOP.
- `PAUSED + TOGGLE` → SMART_RESUME.
- `STOPPED + TOGGLE` → full START.
- `STARTING/STOPPING + TOGGLE` → no new action.
- Explicit STOP is allowed for RUNNING and PAUSED, and is idempotent for STOPPED.

PAUSED full stop reuses the normal Flutter/native stop path and converges to `isStart=false`, `isSmartStopped=false`, `runTime=null`, native STOPPED, no presence, and no TUN.

## External and automatic SMART_STOP convergence

With a live Flutter engine, external SMART_STOP now routes through the existing Tile callback architecture into `SmartAutoStopManager.pauseNow()`. It reuses the confirmed native smart-stop workflow instead of duplicating state logic.

Real-device evidence for session `1787296980135`, remote PID `16144`:

| Action | Native result | Flutter result | Identity/TUN |
| --- | --- | --- | --- |
| External SMART_STOP | `RUNNING→PAUSED` | `false/true` | same session/PID; `tun0→absent`; no full stop |
| PAUSED TOGGLE | `PAUSED→RUNNING` | `true/false` | same session/PID; `absent→tun0`; no new start |
| Automatic SMART_STOP | `RUNNING→PAUSED` | `false/true` | same session/PID; `tun0→absent`; no full stop |
| PAUSED explicit STOP | `PAUSED→STOPPING→STOPPED` | `false/false` | presence deleted; TUN absent |

The automatic trusted-network path therefore remains PAUSED, not STOPPED.

## Session, PID, TUN, and running continuity

SMART_STOP/RESUME preserved session ID, start time, remote PID, and Core context. RUNNING Dashboard→proxy selection→Dashboard evidence separately retained session `1787297050963`, remote PID `19550`, and exactly one `tun0`. True STOP removed presence/TUN; a later START may create a new session by design.

## Accepted WATCH items

The following remain accepted/watch rather than Phase 4E defects:

- STOP/TOGGLE while PENDING is ignored rather than queued or cancelled.
- START→STOP before RUNNING and STOP→START before completion.
- Permission-dialog races.
- STARTING/STOPPING reopen behavior.
- Binder transport redesign.
- RUNNING reattach setup/profile work.
- Background CPU, notification, wake, and power behavior, deferred to Phase 4F.
- The existing Phase 4C selection ACK-order observation; frozen selection tests pass and VPN continuity is unaffected.

## Local regression truth

- Focused and frozen Flutter Phase 4C/4D/4E suite: 196 passed.
- Python perf harness: 60 passed.
- Android app and service unit tests: PASS.
- Profile arm64 APK build and overlay install: PASS.
- `flutter analyze`: 0 errors, 0 warnings, 69 existing info-level diagnostics.
- Primary Phase 4E.1 lifecycle capture: `ok=true`, `vpn.ok=true`, no unreliable windows.

No hosted CI run exists for the accepted close commit. Local tests PASS; CI PASS is not claimed.

## Mihomo pin

`core/Clash.Meta` remained at `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`. Buildkit's temporary repository-owned build patch was removed after profile APK generation; no Mihomo edit was committed.

## Close decision

Human audit accepts Phase 4E as **CLOSED** at `d1051d5bcd0aa34c4844c8f55a6df75ccccc92bd`.

This closeout records the final VPN lifecycle contract. Phase 4F may measure background and power behavior, but must preserve all closed Phase 4C/4D/4E semantics.
