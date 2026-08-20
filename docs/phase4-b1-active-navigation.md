# Phase 4B.1 — Active Session Navigation Jank / Dashboard Rebuild Isolation

Date: 2026-08-20  
Branch: `beta`  
This phase does **not** change Motion tokens, Dashboard `keep:false`, scroll-to-top, Hero fill visuals, SMART_STOP / SMART_RESUME, or Phase 1–3 Mihomo semantics. It does **not** start 4B.2 / 4C.

4B.0 / 4B.0.1 measurement architecture is unchanged except for the RUNNING workload gate and Dashboard-scoped hotspot counters required by this round.

---

## Provenance

| Field | Value |
|---|---|
| git_head / named base | `577b01f8f63d810ee38c884b0addeda072e93a21` |
| dirty (source) | `True` at test time |
| worktree_fingerprint (tested source) | `9112320388da5bfc` |
| submodule commit | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` |
| submodule dirty | `True` (pre-existing Clash.Meta working tree; **not** part of this phase) |
| device | `25042PN24C` / Android 16 (sdk 36) |
| package | `com.slclash.app.profile` 9.9.10 (profiling, `PHASE4_PERF`) |
| dumpsys refresh_hz | `120.00001` (budget 8.333 ms) |
| Dart `display.refreshRate` this round | `60.0` (budget 16.667 ms) |

AFTER captures were taken **before** this documentation commit. Do not treat the docs commit SHA as the tested tree. The tested source is fingerprint `9112320388da5bfc` on top of `577b01f8`.

IDLE BEFORE (formal 4B.0.1, VPN OFF): `docs/phase4-b0-navigation-baseline.md`  
`git_head=9518d40d`, `dirty=False`, `dart refresh_hz=120.0`, same device / Profile package / 120 Hz dumpsys.

There is **no** RUNNING FrameTiming capture on the unoptimized Dashboard tree. The first RUNNING navigation dataset is AFTER isolation (this fingerprint). Compare RUNNING AFTER to IDLE AFTER on the same APK, and use 4B.0.1 only as the idle historical baseline.

### Captures

| Label | Path | session | ok |
|---|---|---|---|
| IDLE AFTER | `.perf-captures/phase4/20260820T024807Z` | idle (force-stop) | true |
| RUNNING AFTER | `.perf-captures/phase4/20260820T025437Z` | running (no force-stop) | true |
| RUNNING reattach | `.perf-captures/phase4/20260820T025704Z` | UI kill only | true |
| idle cold-start | `.perf-captures/phase4/20260820T030004Z` | force-stop | true |

RUNNING AFTER continuity: remote pid `13465` unchanged, `sessionId=1787194093663` unchanged, `state=RUNNING`, `vpn_ready=true`, `tun0` uninterrupted.

---

## Refresh-rate / over-budget caveat

4B.0.1 Dart budget was **8.333 ms** (120 Hz). This round’s Dart `refreshRate` was **60 Hz / 16.667 ms** while dumpsys still listed 120 Hz.

`over_budget` in AFTER JSON is counted against **16.667 ms**, so it is **not comparable** to 4B.0.1 over-budget (8.333 ms). Do not claim an over-budget win from those integers.

Gate metrics that remain comparable: FrameTiming **build / raster / totalSpan percentiles** and **worst_frame_ms**.

---

## 1. RUNNING navigation benchmark

Harness: `python tools/perf/phase4.py navigation --build-mode profile --nav-session running`

- Never `am force-stop`.
- Preconditions: VpnService + tun + `:remote` + presence `RUNNING` + `sessionId>0` + `vpn_ready`.
- After the workload the same fields must match or `ok=false`.
- A: Dashboard ↔ Proxy, 2 warmup + 10 round trips.
- B: four-tab round-robin, 2 warmup + 10 cycles.
- RUNNING skips D reselect and P7 keep experiment.

IDLE workload is unchanged (`--nav-session idle`, default).

---

## 2. BEFORE / AFTER FrameTiming

`total_ms` still includes `pageEnter` 280 ms. Success is **not** shrinking 307 ms.

Values are **median across transitions** of each transition’s p50/p90/p99 (same summary as 4B.0.1).

### Dashboard → Proxy

| | IDLE 4B.0.1 | IDLE AFTER | RUNNING AFTER |
|---|---|---|---|
| total_ms median | 304.5 | 302.0 | 314.5 |
| build p50 / p90 / p99 | 2.22 / 3.73 / 3.99 | 2.15 / 3.53 / 4.12 | 2.21 / 3.92 / 4.69 |
| raster p50 / p90 / p99 | 3.74 / 4.69 / 5.03 | 3.95 / 4.93 / 6.68 | 3.89 / 4.62 / 5.12 |
| totalSpan p50 / p90 / p99 | 7.70 / 10.20 / 11.59 | 7.29 / 10.40 / 12.74 | 7.84 / 10.52 / 12.78 |
| worst_frame median / p90 | 11.82 / 15.77 | 12.91 / 17.54 | 13.13 / 14.69 |
| frame_count median | 20.5 | 20.0 | 14.0 |

### Proxy → Dashboard

| | IDLE 4B.0.1 | IDLE AFTER | RUNNING AFTER |
|---|---|---|---|
| total_ms median | 309.0 | 307.5 | 311.5 |
| build p50 / p90 / p99 | 2.07 / 3.96 / 10.82 | 2.17 / 3.73 / 8.28 | 2.12 / 3.86 / 9.65 |
| raster p50 / p90 / p99 | 3.55 / 5.51 / 7.22 | 3.55 / 4.78 / 6.86 | 3.66 / 4.80 / 6.01 |
| totalSpan p50 / p90 / p99 | 7.46 / 11.33 / 18.82 | 7.76 / 10.80 / 13.44 | 7.67 / 11.99 / 15.91 |
| worst_frame median / p90 | 19.55 / 24.33 | 13.74 / 20.45 | 16.40 / 20.94 |
| frame_count median | 13.0 | 13.5 | 13.0 |

### Tools → Dashboard

| | IDLE 4B.0.1 | IDLE AFTER | RUNNING AFTER |
|---|---|---|---|
| total_ms median | 312.5 | 312.0 | 314.0 |
| build p50 / p90 / p99 | 2.70 / 6.70 / 10.55 | 2.31 / 6.84 / 12.43 | 2.04 / 6.39 / 14.22 |
| raster p50 / p90 / p99 | 3.91 / 6.27 / 7.59 | 4.12 / 6.26 / 8.16 | 4.20 / 4.91 / 6.45 |
| totalSpan p50 / p90 / p99 | 8.53 / 14.46 / 18.92 | 8.31 / 14.80 / 21.78 | 7.76 / 13.26 / 19.00 |
| worst_frame median / p90 | 19.41 / 23.51 | 22.48 / 25.69 | 19.61 / 26.02 |
| frame_count median | 13.0 | 13.0 | 13.0 |

### Gate reading

- **Proxy → Dashboard** IDLE: build p99 10.82 → **8.28**, raster p99 not worse (7.22 → 6.86), worst-frame median 19.55 → **13.74**.
- **Proxy → Dashboard** RUNNING (first dataset): build p90 3.86, p99 9.65; raster p90/p99 **4.80 / 6.01** (better raster p99 than idle 4B.0.1); worst-frame median **16.40** vs idle 4B.0.1 19.55.
- **Dashboard → Proxy** RUNNING raster p90/p99 **4.62 / 5.12** (not worse than 4B.0.1).
- **Tools → Dashboard** build p99 is still the noisy tail (IDLE AFTER 12.43, RUNNING 14.22 vs 4B.0.1 10.55). Raster p90/p99 on RUNNING **improved** vs 4B.0.1 (4.91 / 6.45 vs 6.27 / 7.59). worst-frame median RUNNING **19.61** ≈ 4B.0.1 19.41.
- IDLE navigation did **not** systematically regress on Proxy → Dashboard. Tools → Dashboard idle build-p99 / worst-frame are mixed; treat as noise + 60 Hz budget mismatch, not a product change.

---

## 3. Dashboard rebuild counts (active transition only)

Counters fire only while `NavigationTrace` has an active transition. Production release without `PHASE4_PERF` is a no-op.

### RUNNING AFTER (n=10 per slice)

**Dashboard → Proxy** (Dashboard still in the PageView during `pageEnter`):

- root builds: none (`dashboard_view` / `hero` / `network_overview` = 0)
- `traffic_history_update` 10, `line_chart_update` 20, `line_chart_animation_start` 14
- `total_traffic_update` 10, `donut_chart_update` 10, `donut_chart_animation_start` 10
- `network_detection_update` 10, `latency_setState` 14

Live traffic **did** overlap the transition. After isolation that overlap is **chart/traffic subtrees**, not the card shell / Hero / Dashboard page root.

**Proxy → Dashboard** (keep:false remount):

- `dashboard_view` 10, `dashboard_hero` 10, `network_overview` 10 (one root build per remount, not per traffic tick)
- `traffic_history_update` 12, `line_chart_update` 4, `line_chart_animation_start` 4
- `total_traffic_update` 12, `donut_chart_*` 2
- `network_detection_update` 10, `latency_setState` 20 (mount starts latency probes)

**Tools → Dashboard**: same 10/10/10 root builds; traffic/chart events ≈ 10; no extra chart animation storm on this slice.

### IDLE AFTER remounts

Proxy/Tools → Dashboard: 10/10/10 root builds and one traffic/total/detection/latency event per remount (no live series). Isolation is a no-op when providers are quiet; it does not add idle rebuilds.

---

## 4. Identified root cause

`SurgeNetworkOverviewCard` previously `watch`ed `trafficsProvider`, `totalTrafficProvider`, `networkDetectionProvider`, `appForegroundProvider`, `currentPageLabelProvider`, and `isStartProvider` in **one** `build()`, then constructed both `LineChart`s, `DonutChart`, latency, detection, and chrome.

RUNNING hotspot counts show:

1. High-frequency traffic updates during Dashboard → Proxy **without** remounting Dashboard root after isolation.
2. LineChart / DonutChart **animation starts** overlapping `pageEnter` while Dashboard is still visible (14 line + 10 donut animation starts across 10 Dashboard → Proxy transitions).
3. Returning to Dashboard still remounts the page (`keep:false`). That remount is **one** overview shell build, not a full-card rebuild per traffic sample.

Hero first-mount `TweenAnimationBuilder` with `begin == end` was a **visual no-op** that still ran the 1500 ms ticker. That is independent of traffic; it is removed only for the no-op case.

---

## 5. What changed (technical)

1. **RUNNING navigation workload** (`--nav-session running`) with VPN continuity gates.
2. **Hotspot counters** on DashboardView / Hero / overview root, traffic/total/detection/latency, LineChart and DonutChart update/animation start.
3. **`SurgeNetworkOverviewCard` rebuild boundaries**
   - Root is a `StatelessWidget` (layout/chrome only).
   - Traffics → `_OverviewSpeedCharts` only.
   - `totalTraffic` → donut totals + badge Consumers only.
   - Detection → `_OverviewDetectionHost` only.
   - Latency timer/`setState` → `_OverviewLatencyHost` only.
   - Provider **data semantics and update cadence unchanged**. No debounce, no stale UI cache.
4. **Hero T5 no-op ticker**: skip `TweenAnimationBuilder` on first mount and when `activeFill` is unchanged. `heroFill` 1500 ms + `easeInOutCubic` still run for real active ↔ paused color changes.

No extra `RepaintBoundary` around charts (they already have one). No KeepAlive. No scroll registry. No DFS change.

---

## 6. Product Decision Queue (not shipped)

| ID | Decision | Why not this round |
|---|---|---|
| P7 | Dashboard `keep:true` | 4B.0.1 experiment had no stable FrameTiming win. Product stays `keep:false`. |
| Chart anim vs pageEnter | Disable or delay LineChart/DonutChart animation during tab transition | RUNNING counts show animation starts overlapping `pageEnter`. Changing that **changes visuals**. Record only. |
| Dart 60 vs dumpsys 120 | Force FrameTiming budget to dumpsys 120 Hz | Measurement architecture; not required to ship isolation. AFTER `over_budget` must not be compared to 4B.0.1. |

---

## 7. Unchanged product behavior

- `SurgeMotion.pageEnter` = 280 ms; all other motion durations / curves
- Dashboard `keep:false`
- Auto scroll-to-top; same-tab reselect UX
- Hero fill / sheen / pulse visuals (except skipping a no-op initial fill ticker)
- Sheet / Dialog
- SMART_STOP / SMART_RESUME exported API
- Phase 1–3 Mihomo semantics

---

## 8. Memory / CPU sanity

- IDLE AFTER Dashboard keep:false PSS: **419809 kb** (Java heap 36484, native 65032). Same order as 4B.0.1 P7 keep:false ~414139 kb; not a memory optimization round.
- RUNNING reattach: 10/10 `core_ready`, session continuity true, remote pid `13465` throughout. am-start TotalTime median **380 ms**, `first_frame` median **91.5**, `main_ready` median **272**.
- Idle cold-start AFTER: 10/10 `core_skipped`, TotalTime median **401 ms**, `first_frame` median **100**, `main_ready` median **141.5**. Idle does not spawn a new Core for this package.

PAUSED reopen/resume was **not** re-measured this round (session under test was RUNNING). Do not infer PAUSED from RUNNING reattach.

---

## 9. Regression

| Check | Result |
|---|---|
| `flutter analyze` | Existing info-level deprecations only; no new errors/warnings in this diff |
| Flutter tests | Phase 1–3 Mihomo + media-check + dashboard layout + NavigationTrace pass. Full `flutter test` still has a pre-existing `app_changelog_test` expected `v2.0.7` vs `v2.0.9` |
| Python harness tests | pass (`test_harness.py`) |
| IDLE navigation | ok |
| RUNNING navigation | ok; session/tun/remote unchanged |
| Idle cold-start | ok; `core_skipped` |
| RUNNING reattach | ok |
| PAUSED reopen | not run |

---

## Phase 4B.1.1 Verification & Cleanup

Date: 2026-08-20  
Branch: `beta`  
Scope: harness provenance + Hero fill lifecycle + LatencyHost reflow check. No 4B.2 / 4C. No Dashboard `keep:false` / `pageEnter` 280 ms / SMART_STOP / Mihomo changes.

### Refresh rate

4B.1 AFTER captures showed Flutter `display.refreshRate` **60 Hz** while dumpsys listed a **120 Hz** candidate. That mismatch was real; neither number is “the wrong one.”

Harness changes:

- `system_refresh_candidates` / `system_max_refresh_hz` are dumpsys **reported** values.
- `system_max_refresh_hz` is **not** actual presentation Hz and is **not** the FrameTiming budget source.
- Budget uses Flutter `display.refreshRate` (`frame_budget_source=flutter_display_refresh_rate`, `effective_budget_ms`).
- If Flutter Hz and system max Hz disagree, `refresh_rate_mismatch=true` and `over_budget_comparable=false`.
- Do **not** compare `over_budget` across captures when mismatch is true.
- `build` / `raster` / `totalSpan` percentiles and `worst_frame_ms` remain valid.

### Hero `_HeroActiveFill` / `HeroActiveFill`

4B.1 already skipped the first-mount no-op 1500 ms ticker.

4B.1.1 completes the lifecycle:

- First mount and unchanged `activeFill` render the current color with no fill animation.
- Real active ↔ paused still uses `SurgeMotion.heroFill` (1500 ms) and `Curves.easeInOutCubic`.
- Mid-flight color changes retarget from the current visual color on a single `AnimationController` (no overlapping tickers).
- When the transition completes, animation state exits (`_tween = null`); later same-color rebuilds stay static.
- Product visual tokens are unchanged.

### Responsive latency

Verification: crossing `requiresReflow` (384 → 225 → 384) **did remount** `_OverviewLatencyHost` when it lived as a Row vs Column child (different parent/slot).

Minimal fix: a card-scoped `GlobalKey` so the same State moves with the layout. Latency probe / timer / result semantics are unchanged. Layout chrome is still Row vs Column.

```text
state remount detected + minimal GlobalKey identity fix
```

Test-only `OverviewLatencyHostLifecycle` mount/dispose counters; production does not read them.

### Regression (4B.1.1)

| Check | Result |
|---|---|
| `flutter analyze` | No new errors/warnings in this diff. Existing project infos/deprecations only |
| Flutter tests | Hero fill widget tests, LatencyHost reflow test, dashboard layout, NavigationTrace, Phase 1–3 Mihomo, smart_auto_stop, media-check: pass |
| Python harness | `python -m unittest tools/perf/tests/test_harness.py` pass (48) |
| Device smoke | Profile APK overlay-installed on `25042PN24C`. IDLE: Dashboard visible (Hero Connect, Network Overview, GitHub/YouTube/ChatGPT). Dashboard → Proxy → Dashboard; pid `8785` unchanged; no AndroidRuntime/flutter fatal. RUNNING VPN smoke **not run** (profile package had no VpnService/tun this session) |

### Stop

4B.1.1 is done. Do **not** automatically start 4B.2, chart animation suppression, Dashboard KeepAlive, or 4C.


