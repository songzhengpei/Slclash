# Phase 4B Final Closeout — Navigation / Page Mounting

Date: 2026-08-20  
Branch: `beta`  
Audited product HEAD at closeout start: `c0bb11e6195f0e8fafef934ef1b6ee2e7a77a340`  
This document is **verify / summarize / archive / close**. It does not change product behavior.

**Phase 4B status: PASS / CLOSED**

---

## 1. Scope

Phase 4B covers:

- Navigation measurement
- Page mount / revisit behavior
- Dashboard active-session rebuilds
- Navigation FrameTiming
- scroll / reselect behavior
- navigation motion sanity

Phase 4B does **not** cover:

- Proxy / Group UX (Phase 4C)
- Runtime polling / Core IPC (Phase 4D)
- VPN Lifecycle (Phase 4E)
- Background / Power (Phase 4F)
- Final animation polish (Phase 4G)

No 4B.2. No KeepAlive. No chart animation suppression.

---

## 2. Completed work

| Slice | Commit | Document | Outcome |
|---|---|---|---|
| 4B.0 Motion / navigation audit | `ee800121` | `docs/phase4/phase4-b0-motion-navigation-audit.md` | Inventory of SurgeMotion, Home tab switch, scroll-to-top, keep:false. Dirty 4B.0 capture is historical only. |
| 4B.0.1 Measurement correction | `9518d40d` | `docs/phase4/phase4-b0-navigation-baseline.md` | Formal IDLE FrameTiming baseline. `target_first_build_latency_ms` is wait-until-`build()`, not CPU. D reselect awaits `animateTo` in the trace only. P7 `keep:true` experiment: no stable FrameTiming win. |
| 4B.1 Active-session isolation | `8f2fbcab` | `docs/phase4/phase4-b1-active-navigation.md` | RUNNING nav workload + VPN continuity. Dashboard live-state rebuild isolation. Hero first-mount no-op ticker removed. |
| 4B.1.1 Verification & cleanup | `c0bb11e6` | same 4B.1 doc, section 4B.1.1 | Refresh-rate provenance. Hero fill AnimationController lifecycle. LatencyHost reflow GlobalKey. |

Named 4B.1 product SHA: `8f2fbcabb440be6d3793e5d9e3a8ee4d0044464a`.  
4B.1 FrameTiming AFTER was taken on fingerprint `9112320388da5bfc` (on `577b01f8`) **before** the 4B.1 docs commit. Do not treat later docs SHAs as the measured tree.

---

## 3. Final product decisions

These stay as shipped. Closeout does not reopen them.

| Decision | Value |
|---|---|
| Dashboard KeepAlive | `keep:false` |
| `SurgeMotion.pageEnter` | 280 ms |
| same-tab reselect | unchanged |
| scroll-to-top | unchanged (product `animateTo` still fire-and-forget) |
| provider refresh cadence | unchanged |
| stale UI cache / debounce | none added |
| navigation interaction / bottom nav | unchanged |
| SMART_STOP / SMART_RESUME | untouched |
| Mihomo / VPN / Core semantics | untouched |

**Why `keep:false`:** P7 `keep:true` had no stable FrameTiming advantage. Extra offscreen memory / state lifetime is not worth it. Remount on return to Dashboard is accepted, not a 4B blocker.

**Why `total_ms` is not a jank score:** tab switch includes `pageEnter` 280 ms. Success is FrameTiming build / raster / totalSpan / worst-frame, not shrinking ~307 ms totals.

---

## 4. Final technical results

### 4.1 Navigation measurement architecture

Established:

- Transition tracing (`nav_begin` … `nav_complete`, FrameTiming only while a transition is active)
- FrameTiming `build` / `raster` / `totalSpan` / `worst_frame`
- `target_first_build_latency_ms` is **not** build CPU cost
- IDLE navigation workload
- RUNNING navigation workload (never `am force-stop`; VpnService + tun + `:remote` + `RUNNING` + `sessionId>0` + `vpn_ready`; fail if those change)
- `git_head` / `dirty` / `worktree_fingerprint` provenance

Refresh-rate provenance (4B.1.1):

- `system_refresh_candidates` = dumpsys reported candidates
- `system_max_refresh_hz` = max candidate; **not** actual presentation Hz; **not** FrameTiming budget source
- Budget uses Flutter `display.refreshRate` (`frame_budget_source`, `effective_budget_ms`)
- If Flutter Hz ≠ system max Hz: `refresh_rate_mismatch=true`, `over_budget_comparable=false`
- Do **not** claim an `over_budget` win across mismatch captures (4B.0.1 dart 120 Hz vs 4B.1 dart 60 Hz)
- `build` / `raster` / `totalSpan` / `worst_frame` remain comparable

### 4.2 Dashboard live-state rebuild isolation

Before 4B.1, `SurgeNetworkOverviewCard` watched in one large `build()`:

- `trafficsProvider`
- `totalTrafficProvider`
- `networkDetectionProvider`
- `appForegroundProvider`
- `currentPageLabelProvider`
- `isStartProvider`

RUNNING traffic updates rebuilt the whole overview (charts + donut + latency + detection + chrome).

After 4B.1 the card shell is layout-only. Live updates stay in:

- traffic charts
- total traffic / donut
- detection host
- latency host
- current-speed badge (`ValueListenableBuilder`)

High-frequency live-state updates no longer amplify into Dashboard / Hero / Network Overview shell. No debounce. No reduced realtime. No stale cache. Provider data semantics unchanged.

RETURNING to Dashboard still remounts (`keep:false`): one shell build per visit, not one per traffic sample.

### 4.3 Hero active fill

Closed. Do not keep optimizing Hero in 4B.

- First mount: no begin==end no-op fill ticker
- Unchanged `activeFill`: no fill animation
- Real active ↔ paused: `SurgeMotion.heroFill` 1500 ms, `Curves.easeInOutCubic`
- Single `AnimationController`; complete exits the animation path
- Rapid retarget from current visual color; no overlapping tickers

### 4.4 LatencyHost responsive lifecycle

Row ↔ Column at `requiresReflow` used to remount `_OverviewLatencyHost`.

4B.1.1 card-scoped `GlobalKey` keeps State across 384 → 225 → 384 (`mounts=1`, `disposes=0`). Latency results, refresh timer, and probe lifecycle are preserved. Probe cadence / targets unchanged.

### 4.5 Navigation motion / scroll

- DFS / scroll bookkeeping measured ~sub-millisecond; not a hotspot. No scroll registry.
- same-tab reselect / scroll-to-top stay product behavior.
- Phase 4B does not continue chasing these.

### 4.6 RUNNING safety evidence

Formal 4B.1 RUNNING AFTER (`.perf-captures/phase4/20260820T025437Z`): remote pid `13465`, `sessionId=1787194093663`, `state=RUNNING`, `vpn_ready=true`, `tun0` uninterrupted. Closeout adds **no** VPN/Core code.

---

## 5. Deferred / future optimization

### D1 — Chart animation overlaps pageEnter

RUNNING Dashboard → Proxy still showed LineChart / DonutChart animation starts during `pageEnter`.

Suppression or delay would change product visuals. No severe regression. **DEFERRED.** Do not modify in 4B.

### D2 — Tools → Dashboard build tail

Tools → Dashboard still has a noisy build p99 / worst-frame tail (IDLE AFTER 12.43 / RUNNING 14.22 vs 4B.0.1 10.55). Not proven as a systematic 4B regression. **DEFERRED** to a later polish pass.

### D3 — Static GlobalKey singleton assumption

`SurgeNetworkOverviewCard` uses a card-level static `GlobalKey`. Dashboard currently has **one** overview card, so there is no conflict.

If the tree ever mounts multiple overview cards, identity must become instance-scoped. **ARCHITECTURE NOTE / DEFERRED.** Do not change now.

### D4 — High-frequency small live badge

`currentSpeedNotifier` `ValueListenableBuilder` still follows live traffic. Rebuild scope is already small. **ACCEPTED.** Revisit only if a profiler proves a hotspot.

---

## 6. Regression result (closeout gate)

No new product / test / harness code in this closeout. No full benchmark rerun. No RUNNING BEFORE.

| Check | Result |
|---|---|
| `flutter analyze` | 66 **info** issues, all pre-existing (quotes, underscores, `onReorder` deprecation, test `prefer_const_constructors`). **No error. No warning.** Closeout added none. |
| Flutter tests | `hero_active_fill_test`, `overview_latency_host_lifecycle_test`, `dashboard_layout_test`, `navigation_trace_test`, `test/mihomo`, `smart_auto_stop_test`, `media_check_test`: **pass** (+174, ~3 skipped in Mihomo e2e as before) |
| Full `flutter test` | Pre-existing `app_changelog_test` (`v2.0.7` vs `v2.0.9`) **not** fixed in closeout |
| Python harness | `python -m unittest tools/perf/tests/test_harness.py` **48 OK** (candidates 120/60; Flutter 60 vs system 120 mismatch; 120 vs 120 aligned) |
| Device smoke | See below |
| New blockers | **none** |

### Device smoke (2026-08-20, `25042PN24C`)

Package: `com.slclash.app.profile` already overlay-installed from 4B.1.1 (`c0bb11e6`). Closeout did not rebuild.

**IDLE:** Dashboard (Hero Connect, Network Overview, GitHub / YouTube / ChatGPT) → Proxy → Dashboard → Tools → Dashboard. Process pid **8785** unchanged. Tools dump had no GitHub row (left Dashboard). Return dump had Connect + GitHub. No AndroidRuntime / flutter fatal. Hero, overview, latency rows, and tab switch behaved.

**RUNNING:** not rerun. Profile had no VpnService/tun for closeout. 4B.1 already has formal RUNNING continuity. Closeout contains no VPN/Core changes. This does **not** block closing 4B.

---

## 7. Phase 4B acceptance

**Phase 4B status: PASS / CLOSED**

| Gate | Result |
|---|---|
| Navigation functional correctness | PASS |
| Dashboard rebuild architecture | PASS |
| Active-session navigation safety | PASS |
| Navigation measurement architecture | PASS |
| Power / runtime regression introduced by 4B | NONE FOUND |
| Mihomo semantics impact | NONE |
| VPN / Core semantics impact | NONE |

Checklist:

- **A. Navigation** Dashboard ↔ Proxy / Dashboard ↔ Tools OK in smoke. same-tab / scroll / `pageEnter` tokens unchanged.
- **B. Runtime** No new resident ticker / provider polling / stale cache in 4B closeout. RUNNING safety evidenced in 4B.1.
- **C. Dashboard** Live rebuild amplification isolated. Hero lifecycle closed. LatencyHost reflow state kept. `keep:false` remains.
- **D. Measurement** FrameTiming usable. Refresh provenance correct. Mismatch does not compare `over_budget`. Percentiles + worst-frame remain future metrics.
- **E. Compatibility** Phase 1–3 Mihomo, SMART_STOP/RESUME, Core/VPN semantics unmodified in 4B closeout.
- **F. Regression** Analyze/tests/harness as above. No new blocker.

---

## 8. Next phase

**NEXT = Phase 4C — Proxy / Group UX**

Do **not** start Phase 4C in this closeout.
