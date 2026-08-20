# Phase 4C Final Closeout — Proxy / Group UX

Date: 2026-08-20  
Branch: `beta`  
Closeout base: `7782722c6b96afe17f76bbd8cf9773868f57159b`  
This document is **verify / freeze / archive / close**. It does not change product behavior.

## 1. Final Status

**Phase 4C = CLOSED**

| Slice | Name | Status |
|---|---|---|
| Phase 4C.0 | Proxy / Group UX Audit & Baseline | **COMPLETE** |
| Phase 4C.1A | Mihomo Proxy Group Correctness | **PASS / FROZEN** |
| Phase 4C.1B | Proxy Performance Evidence | **CONDITIONAL PASS / COMPLETE** |
| Phase 4C.1C | Product performance optimization | **NOT IMPLEMENTED BY DESIGN** |

4C.1C is not an unfinished optimization task. Existing measurement and real usage do not prove that further Proxy performance-path changes would produce enough user-visible benefit. **No-fix is an explicit engineering decision.**

Phase 4C does **not** cover:

- Runtime polling / Core IPC (Phase 4D)
- VPN lifecycle (Phase 4E)
- Background / Power (Phase 4F)
- Final animation polish (Phase 4G)

## 2. Baseline

| Field | Value |
|---|---|
| closeout base | `7782722c6b96afe17f76bbd8cf9773868f57159b` (`docs: record Phase 4C.1B performance baseline`) |
| pinned Mihomo **before** | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` (`v1.19.30`) |
| pinned Mihomo **after** | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` (unchanged) |
| submodule pointer | `core/Clash.Meta` committed SHA identical; this closeout does not update Core |
| local Clash.Meta worktree | leftover dirty files were present and **not** included |

Authoritative slice docs:

- 4C.0: `docs/phase4-c0-proxy-group-baseline.md`
- 4C.1A: `docs/phase4-c1a-mihomo-group-correctness.md`
- 4C.1B: `docs/phase4-c1b-proxy-performance-evidence.md`

## 3. What Phase 4C Fixed

Product correctness work (4C.1A + follow-ups), not 4C.1C performance rewrites:

- **Mihomo group semantics** aligned with pinned Core: Selector / URLTest / Fallback / LoadBalance.
- **`fixed` / unfix**: Core `now` vs `fixed`; pin = valid member PUT; unfix = DELETE-equivalent `ForceSet("")`; never PUT `""`.
- **LoadBalance**: not manually selectable; no fake selected member; delay testing still allowed.
- **Selection failure**: Core error skips `closeConnections` / `resetConnections` / `checkIp`; optimistic rollback does not overwrite newer intent.
- **Optimistic transaction**: immediate visual `selectedMap`; 600 ms per-group debounce; in-flight success advances committed baseline.
- **Cross-group debounce**: tag is `(FunctionTag.changeProxy, groupName)`; groups do not cancel one another.
- **Dashboard / Proxy unified semantics**: Dashboard picker uses the same `applyProxyGroupMemberTap` pin/unfix/LoadBalance ignore path.
- **`fixed` in equality / snapshot**: `_groupsEqual` includes `fixed`; Core fresh truth wins stale snapshot.

4C.0 and 4C.1B added diagnostic infrastructure (ProxyTrace, Phase 4 perf harness, fixtures). Production without `PHASE4_PERF` remains no-op / low impact. These are **retained diagnostic infrastructure, not unfinished Phase 4 work.**

## 4. Performance Result

Source: 4C.1B IDLE profile capture (`docs/phase4-c1b-proxy-performance-evidence.md`). Device `25042PN24C` / Android 16. Package `com.slclash.app.profile`.

### Selection

| Metric | Result |
|---|---|
| Selection optimistic visual | **0–1 ms** (median 0, p90 1, n=19) |
| Core ACK | **median ~610 ms** (p90 615, max 619, n=14) |

About 600 ms of ACK is **intentional debounce**. UI feedback is immediate. Core convergence is intentionally delayed. **610 ms is not UI jank.** Do not optimize or remove debounce based on this number.

### Proxy FrameTiming (Dashboard ↔ Proxy)

| Metric | Value |
|---|---|
| build p50 | ~1.7 ms |
| build p90 | ~2.4 ms |
| raster p90 | ~6.5 ms |
| totalSpan p50 | ~6.6 ms |
| totalSpan p90 | ~11.1 ms |
| worst frame median | ~21.4 ms |

Current evidence does **not** require a Proxy page rewrite.

### Delay fan-out

`map(async).toList()` starts Futures immediately. `batch(100)` is await grouping, not a concurrency limiter.

| n | peak inflight | source |
|---|---|---|
| 20 | 20 | unit + device |
| 100 | 100 | IDLE device; 100 started, 100 finished, 0 failed |
| 300 | 300 | unit |
| 500 | 500 | unit |

No device ANR, freeze, Core timeout, user-visible jank, or failure-rate increase was recorded for n=100.

### ListHeader / eager items

| Observation | Value |
|---|---|
| E3 sort ListHeader builds | ~28 |
| E6 groups refresh ListHeader builds | ~28 |
| session ListHeader total | 412 |
| eager widgets vs first viewport | 500 materialized / **&lt;40** first viewport builds |
| device expanded group | **2** nodes |

Rebuild count itself is not performance impact. Widget descriptions are eager; Element/render stay viewport-lazy.

### Measurement caveats

**`groups_consistent`:** traces mean “first groups refresh observed after ACK”, not a strict assert that Core `now`/`fixed` equals the intended value. Timing evidence only. Correctness proof is 4C.1A tests + Core contract.

**P2 classifier:** snapshot scenario instrumentation uses groups presence and related conditions. The P2 marker is diagnostic evidence, not complete snapshot provenance proof.

Neither caveat is worth new instrumentation churn for closeout.

## 5. Explicit No-Fix Decisions

| Issue | Evidence | Decision | Reopen Condition |
|---|---|---|---|
| Delay fan-out (`map(async)` + `batch(100)`) | n=20/100/300/500 peak = n; device n=100 all finished, 0 failed; no ANR/timeout/jank recorded | **KNOWN RISK / DEFERRED OBSERVATION** — not a 4C blocker; no arbitrary limiter (8/16/20/32) | Phase 4D IPC audit finds queue starvation, timeout amplification, or measurable interference with other Core requests |
| ListHeader rebuild | E3/E6 ~28 builds; session 412; no matching FrameTiming/user-visible regression | **ACCEPTED TECHNICAL DEBT** — do not split providers, narrow watches, memoize, or debounce headers | Real user-visible regression attributable to header rebuild |
| Eager `_buildItems` | 500 widgets materialized vs &lt;40 viewport builds; device expand = 2 nodes | **ACCEPTED / WATCH** — do not change list architecture | (1) real 300+ node expand stutter, or (2) Android fixture significant frame regression, or (3) memory/CPU spike clearly from eager Widget allocation |
| 600 ms Core ACK | visual 0–1 ms; ACK median ~610 ms ≈ debounce | **ACCEPTED** product timing, not jank | Do not remove debounce unless a real correctness or UX regression is shown |
| Stale-first snapshot / 30s freshness / readiness | P1–P8 mix of device + tests; no blank-flash or cache-redesign evidence | **KEEP** | Proven stale/flash/owner-guard failure |
| 4C.1C Proxy rewrite | FrameTiming above; 2-node real groups | **NOT IMPLEMENTED BY DESIGN** | New evidence that the current path is user-visible-slow |

## 6. Accepted Debt

- **ListHeader fan-out** on sort / groups refresh. Rebuild count ≠ impact. **Do not carry this automatically into Phase 4D.** 4D is not responsible for Riverpod Header rebuild.
- **Eager Widget allocation** in `_buildItems` for expanded groups. Viewport `build()` remains lazy. Watch only under the reopen conditions in §5.

## 7. 4D Observation

When auditing Core IPC / request queue / backpressure, **re-check** whether large delay-test fan-out causes measurable queue starvation, timeout amplification, or interference with other runtime Core requests.

This is **not** a mandatory 4D fix. If 4D does not observe IPC saturation, other-request starvation, timeout amplification, or measurable Core/UI interference: **ACCEPT CURRENT BEHAVIOR.**

Separately still deferred (unchanged from 4C.1A): IPC `null` coalesced to `''` still looks like success.

Do **not** treat “4D must add a delay limiter” as roadmap.

## 8. RUNNING Validation

**RUNNING VALIDATION = PASS**

Real profile-package session on `25042PN24C` (`com.slclash.app.profile`). No fake TUN, no force-stop, no product-logic change. VPN was started through the existing `TempActivity` `action.START` path after the environment blocker cleared; then ordinary Proxy UX ran via `python tools/perf/phase4.py proxy --proxy-session running --delay-max 20`.

Capture: `.perf-captures/phase4/c-closeout-running/` (gitignored). `proxy.ok=true`, `continuity_ok=true`.

| | BEFORE | AFTER |
|---|---|---|
| state | RUNNING | RUNNING |
| vpn_ready | true (VpnService + `tun0`) | true |
| tun | `tun0` | `tun0` |
| remote pid | 18287 | 18287 |
| sessionId | 1787224806095 | 1787224806095 |

Acceptance: remote pid unchanged, sessionId unchanged, tun remains, vpn_ready true, state RUNNING.

Workload (normal size, not a stress run): Dashboard → Proxy, expand a normal group (2 members), Selector A→B plus named/race taps, scroll, delay_test 20 (21 started / 21 finished / 0 failed / peak_inflight 20), Proxy → Dashboard, Dashboard → Proxy.

Connection reset/close after node switch is connection lifecycle, not VPN lifecycle. VPN session did not restart.

Earlier 4C.1B RUNNING probe was environment-blocked (`vpn_service_not_running` / `tun_missing`). That historical miss is superseded by this closeout PASS. No 4D/4E carry-forward for Proxy/VPN continuity from Phase 4C.

## 9. Frozen Decisions

Do not reopen these semantics in future performance phases unless a real correctness regression is demonstrated.

### Selector

- `supportsManualSelection = true`
- `supportsFixedSelection = false`
- Core selection is authoritative
- local `selectedMap` may provide optimistic UX / persistence
- failure reconciles to committed Core truth

### URLTest / Fallback

- `supportsManualSelection = true`
- `supportsFixedSelection = true`
- Core `now` = runtime current member
- Core `fixed` = manual pin state
- pin = valid member selection
- unfix = Mihomo DELETE-equivalent / `ForceSet("")`
- never use PUT `""`
- automatic current node ≠ fixed node
- tapping automatic current node means **PIN**
- tapping fixed node means **UNFIX**

### LoadBalance

- not manually selectable
- no fake selected member
- no local `selectedMap` pretending to be runtime current
- member delay testing remains allowed

### Selection transaction

- optimistic visual feedback
- 600 ms per-group debounce
- cross-group selections do not cancel one another
- Core error skips close / reset / `checkIp`
- failure rollback does not overwrite newer intent
- in-flight successful write advances committed baseline
- newer failure rolls back to latest committed state

### Provider / snapshot

- stale-first snapshot
- 30 s freshness policy
- `ownerProfileId` guard
- `ProviderReadinessService`
- Core fresh truth wins stale snapshot
- `fixed` participates in equality
- profile-switch result guard

Phase 4C has no evidence for stale-cache redesign, provider debounce, or readiness rewrite.

## 10. Regression

Closeout changed **docs / status only**. No product behavior files. No Mihomo submodule update. Heavy IDLE Proxy benchmarks were not re-run; RUNNING continuity smoke was run once after VPN became available.

| Gate | Result |
|---|---|
| `flutter analyze` | **existing info only** — 69 info (`prefer_const_constructors`, `prefer_single_quotes`, …); **0 error, 0 warning**. Exit code 1 is the existing info baseline, not a closeout regression. |
| `test/common/proxy_group_selection_test.dart` | PASS (22) — run during closeout |
| `test/models/group_fixed_json_test.dart` | PASS (8) — run during closeout |
| `test/common/compute_test.dart` | PASS — run during closeout |
| `test/core/controller_test.dart` (`unfixProxy`) | PASS — run during closeout |
| `test/services/providers/provider_readiness_service_test.dart` | PASS — run during closeout |
| `test/providers/smart_auto_stop_test.dart` | PASS (10) |
| `test/common/proxy_trace_test.dart` | PASS — run during closeout |
| Combined Flutter targeted batch | **All tests passed** (123) |
| `python -m unittest tools/perf/tests/test_harness.py` | **50 tests pass** — run during closeout |
| RUNNING continuity | **PASS** (`continuity_ok=true`) |

## 11. Final Verdict

**Phase 4C CLOSED**

No 4C.1C product optimization is required.

Instrumentation (ProxyTrace, Phase 4 perf harness, fixtures, raw results, parsers, `ProxyPageEntryPlan`, perf commands) is **retained**.

**Next: Phase 4D — Runtime Polling / Core IPC**

Do not start 4D in this closeout. Human audit of this document comes first.
