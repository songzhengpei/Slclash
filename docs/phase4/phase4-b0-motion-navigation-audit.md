# Phase 4B.0 — Existing Motion / Navigation Audit

Date: 2026-08-19  
Branch: `beta`  
Audit start SHA named by the brief: `3cca318b` (`fix: keep outbound fill yellow on smart-pause reopen`)  
4B.0 instrumentation commit: `ee800121`  
This document includes **4B.0.1 Navigation Measurement Correction**. Product Motion / UX is unchanged.  
Motion token source of truth: `lib/widgets/surge/surge_motion.dart`  
This phase does **not** create a new Motion System, rename SurgeMotion, or change product visuals.

Related captures: `docs/phase4/phase4-b0-navigation-baseline.md`. Formal 4B.1 BEFORE requires `dirty=false`. Idle `dumpsys gfxinfo` is **not** a navigation baseline. 4B.0 dirty capture (`harness_commit=ae8e6811`) is historical only.

---

## 1. Motion inventory

### 1.1 Token table (unchanged)

| Token | Value | Observed product use |
|---|---|---|
| `press` | 110ms | `SurgePressable`, `effect.dart` press scale |
| `state` | 160ms | indicators, segmented text, select pills, some dialog reverse |
| `reveal` | 180ms | fade/size reveals, delay pills, profile rows, status-light container |
| `container` | 220ms | bottom-nav selected cell, sheets that reuse container, **Home scroll-to-top** |
| `scroll` | 300ms | proxy list jump, hero proxy selector scroll — **not** Home tab scroll-to-top |
| `heroFill` | 1500ms | outbound fill + connecting timer |
| `heroSheen` | 1400ms | start/stop/pause sheen loop |
| `latencyFlow` | 1300ms | network overview latency shimmer |
| `statusLightPulse` | 112ms | connecting status-light pulse |
| `pageEnter` | 280ms | Home `PageController.animateToPage`, `CommonRoute` push |
| `pageExit` | 210ms | `CommonRoute` pop only — **Home tab switch never uses pageExit** |
| `sheetEnter` / `sheetExit` | 300 / 200ms | modal bottom sheet + side sheet |
| `enterCurve` / `exitCurve` | easeOutCubic / easeInCubic | reveal switcher, popup |
| `stateCurve` | easeOutCubic | most tokenized UI; Home tab animation |
| `pressedScale` / overlay | 0.98 / 0.07 | pressable |

Curves that are **not** in SurgeMotion but are used in product UI (see P-queue): `easeInOutCubic` (hero fill), `easeInOut` (status light), `easeOut` / `easeIn` / `easeOutBack` (`FadeBox`), `fastOutSlowIn` (open_container / dismissible), `linearToEaseOut` (page route), `easeIn` (proxy list).

### 1.2 SurgeMotion consumers (tokenized)

`SurgePressable`, `SurgeBottomNav`, `SurgeAnimatedReveal`, `SurgeSelectIndicator`, `SurgeSegmentedControl`, `SurgeDelayPill`, `soft_os_*`, `sheet.dart` / `side_sheet.dart`, `home.dart` PageView, `CommonRoute`, dashboard hero, network overview latency, profiles overwrite switchers, list/input/button chrome.

### 1.3 Parallel duration systems (bypass SurgeMotion)

| Source | Values | Where |
|---|---|---|
| `lib/common/constant.dart` | `animateDuration` 100, `midDuration` 200, `commonDuration` 300 | `FadeBox`, `fade_box` controller, `super_grid`, setupAction debounce, charts |
| `lib/widgets/tab.dart` | 412 / 470 / 200ms springs | unused-on-Android leftover tab chrome (desktop-era) |
| `CommonDesktopRoute` | hardcoded 200/200ms | desktop-only; Android unused |
| `open_container.dart` | 300ms + `fastOutSlowIn` | container transform |
| `popup.dart` | 250ms inner + tokenized outer | mixed |
| `loading.dart` | controllers, `easeInOut` | spinner |
| `donut_chart` / `line_chart` | widget duration | dashboard charts |

Hand-written `Duration(milliseconds: …)` that are **not** animation (timeouts, debounce, HTTP) are omitted from the P-queue.

### 1.4 AnimationController / Timer / provider-driven motion

| Location | Drivers | Notes |
|---|---|---|
| `SurgeDashboardHero` | `_fillController`, `_sheenController`, `_connectingTimer`, `_failureTimer`; `ref.listen` on `isStart` / `isSmartStopped` / `coreStatus` | Connecting pulse now uses semantic `connecting`. Fill/sheen/timer values are P. Two `isStart` listeners were merged this phase (S, visual-equivalent). |
| `_PillStatusLight` | 112ms repeating controller | Starts only when `connecting` is true |
| Network overview | 1300ms latency controller | Independent of hero |
| `FadeBox` | `commonDuration` | Not SurgeMotion |
| `loading.dart` | rotate + points | Continuous while visible |
| `super_grid` | shake / transform | Editor |
| `animated_cross_slide` | controller | Legacy |
| `effect.dart` | press controller | Tokenized duration |

No provider directly owns an `AnimationController`. Hero listens to providers and then drives controllers — correct pattern. Residual risk (T, not changed): `ref.listen` inside `build` re-registers each rebuild; Riverpod supports this, but hero rebuilds are frequent during fill.

### 1.5 Navigation / page / sheet / dialog motion

- **Bottom nav:** `SurgeBottomNav` selected cell uses `AnimatedContainer` 220ms `stateCurve`. No page cross-fade in the bar itself.
- **Home tabs:** `PageView.builder` + `NeverScrollableScrollPhysics` + `animateToPage(pageEnter, stateCurve)` or `jumpToPage`. Adjacent page does **not** fade/slide via `pageExit`.
- **Pushed routes:** `CommonRoute` + `CommonPageTransitionsBuilder` (slide + fade, `pageEnter`/`pageExit`, non-token curves inside the builder).
- **Sheets:** `showModalBottomSheet` `AnimationStyle(sheetEnter/sheetExit)` + barrier 0.52.
- **Dialogs:** `state.dart` `FadeScaleTransitionConfiguration` with `container` / `state`.
- **Proxy switch:** segmented control + hero proxy selector (`SurgeMotion.scroll`). Group list virtualization is **out of scope** (4C).

### 1.6 Loading / reveal / hero / sheen / pulse

- Reveal: `SurgeAnimatedReveal` (size + fade + 10px slide).
- Hero fill 1500ms + sheen 1400ms + status-light pulse 112ms.
- Failure timer: **15s** hardcoded (not a SurgeMotion token).

---

## 2. Navigation architecture map

```text
SurgeBottomNav.onTap
  same index → HomePageView.scrollPageToTop(current, animate:true)
  other index → currentPageLabelProvider.toPage(label)
                  └─ HomePageView.listen
                       1. scrollPageToTop(prev, animate:false)   // post-frame jump
                       2. _toPage(next)
                            animateToPage(280ms) or jumpToPage
                            scrollPageToTop(next, animate:true) // post-frame 220ms
```

Supporting pieces:

| Piece | Behavior |
|---|---|
| `PageView.builder` | Builds visible children; `physics: NeverScrollable` |
| `KeepScope` | `AutomaticKeepAliveClientMixin`; `keep` defaults **true** |
| Dashboard | **`keep: false`** — leaving Dashboard **disposes** it; return remounts |
| Proxies / Profiles / Tools | `keep: true` — first visit mounts, later visits should be keep-alive |
| Page widgets | `GlobalObjectKey(PageLabel.*)` used for scroll-to-top and back-pop |
| Mobile items | dashboard, proxies, profiles, tools |
| `isAnimateToPage` | default **true** (settings toggle exists; P if we ever disable) |
| Scroll-to-top | `Element.visitChildElements` DFS; vertical `ScrollableState` only |

`scrollPageToTop` is product behavior. This phase **does not** change auto-scroll-to-top. Traversal cost is measured; a registry is a 4B.1+ *technical* option only if the numbers say so.

---

## 3. BEFORE benchmark

**4B.0.1 measurement correction.** The 4B.0 capture (`2026-08-19T08:47:20Z`, dirty worktree, `harness_commit=ae8e6811`) is historical only. It must not be used as 4B.1 BEFORE.

Formal 4B.1 BEFORE: `docs/phase4/phase4-b0-navigation-baseline.md`  
Capture `2026-08-19T09:24:39Z` / profile `com.slclash.app.profile` / `25042PN24C` / 120Hz / budget 8.33ms / `ok: true` / **`dirty: false`** / `formal: true`.  
Measured `git_head=9518d40d` (this commit’s source SHA before docs were filled). `submodule_dirty=true` is Clash.Meta only and does not make the source tree dirty.

### Semantics (4B.0.1)

| Field | Meaning |
|---|---|
| `target_first_build_latency_ms` | `nav_begin` → target page-root `build()` **invoked**. Alias `first_build_ms`. **Not** build CPU duration. |
| `build_p50/p90/p99` | Flutter FrameTiming `buildDuration` of frames during the active transition |
| `raster_p50/p90/p99` | FrameTiming `rasterDuration` |
| `total_span_p50/p90/p99` | FrameTiming `totalSpan` |
| D `scroll_command_ms` | DFS + `animateTo` issued |
| D `scroll_animation_complete_ms` | awaited `animateTo` Future (trace only; product UX still fire-and-forget) |

4B.0 read `tools→dashboard first_build 87–100ms` as Dashboard CPU. That reading is **withdrawn**. Clean capture still shows tools→dashboard **latency** median **91ms** (wait until `build()` is called). The same transitions have FrameTiming build p99 median **10.5ms** and raster p99 median **7.6ms**. Latency ≠ CPU.

4B.0 D=`50ms` was two post-frames after starting a 220ms `animateTo`. Withdrawn. Clean D n=10: `scroll_command_ms` median **5.5**, `scroll_animation_complete_ms` median **254.5**, `total_ms` median **276**. DFS median **398µs**.

Headline (product `keep:false`):

- A Dashboard↔Proxy n=20: `total_ms` median **307.5** (pageEnter 280ms floor)
- Dashboard→Proxy FrameTiming: build p50/p90/p99 **2.2 / 3.7 / 4.0** ms; raster **3.7 / 4.7 / 5.0** ms; worst-frame median **11.8ms**; over-budget median **7.5**; frame_count **20.5**
- Proxy→Dashboard: build **2.1 / 4.0 / 10.8** ms; raster **3.5 / 5.5 / 7.2** ms; worst-frame median **19.6ms**; over-budget median **4.5**; frame_count **13**; `target_first_build_latency_ms` median **23.5**
- Tools→Dashboard: latency median **91ms**; build p99 **10.5ms**; raster p99 **7.6ms**; worst-frame median **19.4ms**
- E mounts: **dashboard 24**, others **1** (remount is real)
- Round-robin n=40: `total_ms` median **309**; worst-frame median **15.1ms**; over-budget median **6**

ADB trigger remains MainActivity `phase4_cmd` extras on profile/debug. Ordinary production Release does not register `Phase4PerfPlugin` or `Phase4PerfReceiver`.

### Semantics (4B.0.1)

| Field | Meaning |
|---|---|
| `target_first_build_latency_ms` | `nav_begin` → target page-root `build()` **invoked**. Alias `first_build_ms`. **Not** build CPU duration. |
| `build_p50/p90/p99` | Flutter FrameTiming `buildDuration` of frames during the active transition |
| `raster_p50/p90/p99` | FrameTiming `rasterDuration` |
| `total_span_p50/p90/p99` | FrameTiming `totalSpan` |
| D `scroll_command_ms` | DFS + `animateTo` issued |
| D `scroll_animation_complete_ms` | awaited `animateTo` Future (trace only; product UX still fire-and-forget) |

4B.0 read `tools→dashboard first_build 87–100ms` as Dashboard CPU. That reading is **withdrawn**.

4B.0 D=`50ms` was two post-frames after starting a 220ms `animateTo`, not settle. Withdrawn as complete scroll-to-top duration.

Historical 4B.0 headlines (still true where they do not depend on the withdrawn readings):

- A total_ms median ~313ms ≈ `pageEnter` 280ms floor
- scroll DFS median ~0.59ms / 1935 elements / 1 position
- E mounts: dashboard 24 vs others 1 (remount is real)

---

## 4. Top performance hotspots (ranked)

Corrected after the clean 4B.0.1 capture. DFS is **not** a hotspot. Remount is proven by mount counts. Remount is **not** proven as the largest CPU source.

| Rank | Hotspot | Class | Status |
|---|---|---|---|
| — | `pageEnter` 280ms floor | P4 | Caps `total_ms` (~307ms median). Not a bug. Unchanged. |
| — | Over-budget frames during PageView animation | T | Dashboard→Proxy: more over-budget frames (median 7.5) with **raster** p50 above **build** p50. Proxy→Dashboard remount: **build** p99 median 10.8ms on one heavy frame; raster p99 7.2ms. Split is mixed, not “Dashboard CPU = 87–100ms”. |
| — | Dashboard remount (`keep:false`) | T + P7 | E: 24 mounts vs others 1. P7 keep:true: offscreen `dashboard_hero_mounted=true`, `network_latency_bar=true`, no `target_first_build_latency` on Proxy→Dashboard (page kept). FrameTiming was **not** clearly better (over-budget 7.5 vs product 4.5; more frames). PSS delta **−3501 kb** (keep:true − keep:false) is not a meaningful memory win. Product keep stays false. |
| — | Element DFS | T, **not a hotspot** | D DFS median **398µs**. No scroll registry. |
| — | Hero/sheen tickers offscreen | P7 experiment | keep:true: sheen/pulse false (idle); latency bar kept running. |

4B.1 is **not** started in this commit. No product keep/motion/scroll-to-top change.

| Rank | Hotspot | Class | Status |
|---|---|---|---|
| — | `pageEnter` 280ms floor | P4 | Caps `total_ms`. Not a bug. |
| — | Over-budget frames during PageView animation | T | Use `build_*` vs `raster_*` in the clean baseline to split UI vs compositing. |
| — | Dashboard remount (`keep:false`) | T + P7 | Proven by E mount counts. CPU cost is the P7 experiment + FrameTiming, not `target_first_build_latency_ms`. |
| — | Element DFS | T, **not a hotspot** | ~0.4–0.8ms. No scroll registry. |
| — | Hero/sheen tickers offscreen | P7 experiment | Only if `keep:true` leaves controllers running. |

4B.1 is **not** started in this commit. No product keep/motion/scroll-to-top change.

---

## 5. T / S / P classification

### T — Technical (fixed this phase or recorded)

| ID | Item | Action |
|---|---|---|
| T1 | `_HeroModeCard` used raw `_showConnecting \|\| coreStatus==connecting`, ignoring semantic `connecting` that already excluded smart-stop. PAUSED reopen / paused Core attach could pulse the status light. | **Fixed.** `heroConnectingPulseActive` + pass `connecting`. Tests added. No fill/sheen/color/curve change. |
| T2 | Two `ref.listen(isStartProvider)` in Hero `build` | **Merged** (visual-equivalent). |
| T3 | Navigation jank was previously represented by idle gfxinfo | **Instrumentation** FrameTiming per transition; idle gfxinfo unchanged for 4A. |
| T4 | Element DFS scroll-to-top may jank (especially Proxy) | **Measured: not a hotspot** (median ~0.59ms / 1935 elements / 1 position). Registry remains a later S option only if a future page makes DFS expensive. No rewrite. |
| T5 | `TweenAnimationBuilder` with `begin == end` still animates `heroFill` | Recorded; not changed (could be S later). |
| T6 | `PageView` + Dashboard `keep:false` forces remount | Recorded; product keep is unchanged. CPU vs remount is the P7 **experiment**, not a product flip. |
| T7 | Production must not keep a standing `TimingsCallback` | Callback bind/unbind around an active transition; `enabled` is compile-time false in release without `PHASE4_PERF`. |
| T8 | `first_build_ms` was read as Dashboard CPU | **4B.0.1.** Renamed/aliased `target_first_build_latency_ms`. Reports emit FrameTiming build/raster/totalSpan. |
| T9 | D reselect completed before `animateTo` | **4B.0.1.** Trace awaits `animateTo` Future; product `animateTo` UX is still fire-and-forget. D n≥10. |
| T10 | Perf Receiver in main/production manifest | **4B.0.1.** Receiver only in profile/debug manifests (`exported=false`). Ordinary Release does not register Receiver or `Phase4PerfPlugin`; `phase4_cmd` extras are ignored. Harness still uses MainActivity extras on profile/debug. |

### S — Structural (visual-equivalent candidates; only tiny ones done)

| ID | Item | Action |
|---|---|---|
| S1 | Extract `collectVerticalScrollPositions` | **Done.** Same `visitChildElements` start (root not counted). Tests lock the visitor. |
| S2 | Skip hero color tween when begin==end | Proposed only. |
| S3 | Scroll-controller registry replacing DFS | Proposed only; same jump/animate/to-top semantics. |
| S4 | Align `CommonDesktopRoute` 200ms with tokens | Android unused; skip. |

### P — Product / aesthetic (Decision Queue only)

See §7. Includes: all token values, Home using `pageEnter` both ways and `container` instead of `scroll` for tab-to-top, Dashboard keep-alive, auto-scroll-to-top, sheet/dialog style, hero fill/sheen/pulse, FadeBox curves, `isAnimateToPage`.

---

## 6. SMART_STOP / SMART_RESUME audit (no A/B/C choice in this commit)

### What exists

| Layer | Role |
|---|---|
| `QuickAction.SMART_STOP` / `SMART_RESUME` | Enum in `android/common/.../Enums.kt` |
| `TempActivity` | `exported=true` intent-filters `${applicationId}.action.SMART_STOP` / `SMART_RESUME` |
| Native `VpnService.smartStop/smartResume` | Suspend/resume TUN, keep service; **this is the real smart-pause implementation** |
| Flutter `service.smartStop()` / `smartResume()` | In-app `SmartAutoStop` product path (MethodChannel, **not** the exported intents) |
| Tile | Uses **TOGGLE**, not SMART_STOP. `TilePlugin.handleSmartResume` is the Flutter-alive path for the SMART_RESUME *intent* |
| Phase 4 harness | Does **not** currently call SMART_STOP/RESUME (VPN uses START/STOP) |

### Answers

1. **Formal product feature?** Yes for **native smartStop/smartResume** and the Flutter plugin used by Smart Auto Stop. **Exported TempActivity intents** are not referenced by in-app UI. They are a side door into the same native/Flutter resume path.
2. **Phase 4 test hook only?** No. The native APIs are product. The exported intents are unused by the current harness. They look like automation / tile-adjacent leftovers.
3. **Long-term API value?** Native suspend/resume: yes. Exported implicit intents: convenient for ADB/automation, duplicate of plugin + TempActivity START/STOP already exported.
4. **Exported API cost?** Same class of risk as existing exported START/STOP/TOGGLE: any app can pause or resume TUN without going through Flutter UI. SMART_STOP does not confirm with the user. Maintenance: two entry points (plugin vs intent) that can diverge (intent SMART_STOP bypasses Flutter; SMART_RESUME uses Flutter if the engine is up).
5. **Test-only containment?** Yes: `exported=false`, or profile/debug source set, or a signature permission. 4B.0.1 navigation ADB is MainActivity extras on profile/debug packages only. `Phase4PerfReceiver` is a unused backup in profile/debug manifests (`exported=false`), not in ordinary Release.

### Options (do not choose here)

**A — Formal API keep**  
Keep exported SMART_STOP/RESUME. Document as supported automation. Add tests so intent and plugin cannot diverge.

**B — Profile / test only**  
Move filters to the profile/debug manifest or `exported=false` + explicit component (ADB can still call it). Production APK stops advertising the action.

**C — Delete intents**  
Remove QuickAction entries + TempActivity branches + manifest filters. Keep native `smartStop/smartResume` + Flutter plugin + Tile TOGGLE. Breaks any external sender of those actions (none in-tree except the unused surface).

Engineering note (not a decision): B matches how 4B navigation ADB is contained. C is smaller long-term if nothing external uses the actions. A is only justified if you want a public pause/resume intent next to START/STOP.

This commit used exported SMART_STOP only as a **device smoke** of the existing PAUSED reopen path. That is not a choice of A/B/C.

---

## 7. Product / Aesthetic Decision Queue

### P1. `heroFill = 1500ms` (and connecting timer = same)

- **Current:** Outbound fill and `_connectingTimer` both last 1500ms. `easeInOutCubic`, not `stateCurve`.
- **Technical evidence:** 1500ms ticker + sheen 1400ms on every Start. Nested color `TweenAnimationBuilder` also uses 1500ms. Does not by itself explain tab-switch jank except when Dashboard remounts mid-fill.
- **Why product:** Users feel “slow start chrome” vs “snappy”. Changing ms changes the brand motion.
- **Option A:** Keep 1500ms.
- **Option B:** Shorter fill (e.g. 500–800ms) — *example only, not a recommendation to ship a number*.
- **Option C:** Fill uses `container`/`reveal`; connecting timer stays independent.
- **Engineering recommendation:** Leave until you explicitly want a snappier Start. Not 4B.1.
- **Performance implication:** Shorter fill reduces ticker time on Dashboard, not Proxy list cost.

### P2. `heroSheen = 1400ms` loop during start/stop/pause

- **Current:** `repeat()` for the whole in-flight status update (debounced `commonDuration` 300ms plus Core work).
- **Technical evidence:** Extra GPU/compositing on the Hero button while connecting.
- **Why product:** Sheen intensity/duration is chrome, not correctness.
- **Option A:** Keep.
- **Option B:** Disable sheen; keep fill + pulse.
- **Option C:** One-shot sheen instead of `repeat`.
- **Engineering recommendation:** Optional polish after navigation hotspots.
- **Performance implication:** Low vs Dashboard remount / Proxy first paint.

### P3. `statusLightPulse = 112ms`

- **Current:** reverse-repeat while semantic connecting.
- **Technical evidence:** ~9 Hz opacity animation. T1 stopped paused pulse.
- **Why product:** Pulse frequency is a status language.
- **Option A:** Keep 112ms.
- **Option B:** Slower pulse (e.g. 200–300ms).
- **Option C:** No pulse; static connecting color.
- **Engineering recommendation:** Keep; correctness is done.
- **Performance implication:** Negligible vs page mount.

### P4. Home tab uses `pageEnter` (280ms) both directions; `pageExit` unused

- **Current:** `animateToPage(duration: pageEnter, curve: stateCurve)`. No fade of the outgoing page.
- **Technical evidence:** 280ms is a floor on transition total even if first paint is faster. `jumpToPage` exists when `isAnimateToPage` is false.
- **Why product:** Slide duration and whether exit is faster are feel.
- **Option A:** Keep 280ms both ways.
- **Option B:** Use `pageExit` (210ms) when index decreases.
- **Option C:** Instant `jumpToPage` (today’s setting off).
- **Engineering recommendation:** Don’t change for 4B.1 unless animation time dominates FrameTiming totals.
- **Performance implication:** Caps how fast a round trip can be.

### P5. Tab scroll-to-top uses `container` (220ms), not `scroll` (300ms)

- **Current:** Token mismatch vs proxy-list `SurgeMotion.scroll`.
- **Technical evidence:** Inconsistency only; both are easeOutCubic-ish (`stateCurve` vs `easeIn` on proxy list).
- **Why product:** How fast the page yanks back to top.
- **Option A:** Keep 220ms on tab reselect.
- **Option B:** Use `scroll` 300ms.
- **Option C:** Instant jump on tab reselect (keep animated on other screens).
- **Engineering recommendation:** Cosmetic. 4B.1 should not “fix” this for consistency.
- **Performance implication:** Tiny vs DFS + remount.

### P6. Auto scroll-to-top on tab change and same-tab reselect

- **Current:** Always. Old page jump, new page animate. Same-tab animate.
- **Technical evidence:** Extra work every switch; DFS cost measured in D and A.
- **Why product:** “Twitter-style reselect to top” vs preserve position.
- **Option A:** Keep always-to-top.
- **Option B:** Reselect-only to-top; switching tabs preserves position.
- **Option C:** Never auto to-top.
- **Engineering recommendation:** Product call. Engineering can make A cheaper (registry) without changing A.
- **Performance implication:** B/C remove work; A+registry keeps UX.

### P7. Dashboard `keep: false` vs other tabs `keep: true`

- **Current product:** Dashboard remounts every visit (`keep: false` in `navigation.dart`). **Not changed.**
- **Mount evidence:** Workload E mount counts prove remount. That does **not** prove remount is the largest CPU source.
- **4B.0.1 experiment only** (profile/perf, `keep_dashboard` override, reset with `keep=clear`): compare product `keep:false` vs experimental `keep:true`. Measures FrameTiming build/raster, worst/over-budget, PSS delta, page revisit latency, offscreen Dashboard tickers/CPU, Hero/overview stale vs preserved. Results in `docs/phase4/phase4-b0-navigation-baseline.md`.
- **Why product (later):** Fresh dashboard vs memory / preserving Hero animation / scroll.
- **Option A:** Keep remount (today).
- **Option B:** `keep: true` like Proxies (may preserve stale charts/hero unless you reset).
- **Option C:** Keep alive but reset selected substate on show.
- **This commit does not ask for a P7 decision and does not ship `keep:true`.**

### P8. `FadeBox` / `commonDuration` / non-token curves

- **Current:** 300ms easeOut/easeIn and easeOutBack on several chrome widgets.
- **Technical evidence:** Parallel motion language next to SurgeMotion 160–220ms.
- **Why product:** Unifying changes how lists/titles swap.
- **Option A:** Leave mixed.
- **Option B:** Map to `reveal`/`state` + token curves.
- **Option C:** Delete back curves only.
- **Engineering recommendation:** Not 4B.1.
- **Performance implication:** Low.

### P9. Sheet / dialog motion (300/200 vs fade-scale dialog)

- **Current:** Sheets tokenized; dialogs `FadeScaleTransitionConfiguration` + `container`/`state`.
- **Why product:** Modal language.
- **Option A:** Keep split.
- **Option B:** One motion for all modals.
- **Engineering recommendation:** Don’t touch in 4B.
- **Performance implication:** Unrelated to tab FPS.

### P10. `isAnimateToPage` default true

- **Current:** Setting exists; default on.
- **Why product:** Motion vs instant tabs.
- **Option A:** Keep default on.
- **Option B:** Default off.
- **Engineering recommendation:** Measure A with current default only this phase.
- **Performance implication:** Off removes the 280ms floor.

**Do not treat recommendations as decisions.**

---

## 8. What this phase changed (allowed scope)

4B.0:

- Hero semantic connecting (T1) + tests — **PASS, no rework**
- Tiny Hero listen merge (S)
- Extract scroll visitor (S1) without changing jump/animate/to-top
- `PHASE4_PERF` FrameTiming instrumentation

4B.0.1 (measurement correction only):

- `target_first_build_latency_ms` semantics + FrameTiming build/raster in reports
- Trace-only await of scroll `animateTo` (product UX fire-and-forget)
- D n≥10
- Clean provenance (`git_head` / `dirty` / `worktree_fingerprint`); formal BEFORE requires `dirty=false`
- P7 keep experiment in profile/perf only; product `keep:false` unchanged
- Perf Receiver / plugin gated to profile/debug packages

**Unchanged:** Motion tokens, auto scroll-to-top, Dashboard product keep, SMART_STOP exported API, Hero fill/sheen/paused visual.

## 9. Phase 4B.1

**Stop.** Do not start 4B.1 in this commit. Do not ask the product owner to answer P7 / P6 / P4 / SMART_STOP now.

Element DFS is not a 4B.1 hotspot. No scroll registry. Mount counts prove remount; they do not by themselves prove remount is the largest CPU source.

## 10. Gates (this commit)

| Gate | Result |
|---|---|
| `flutter analyze` (touched Dart) | No issues |
| Flutter tests (nav/hero/scroll + Phase 1–3 mihomo/action/media_check) | 182 pass, 3 skip |
| `python -m unittest tools.perf.tests.test_harness` | 44 OK |
| Clean Profile navigation benchmark | `ok: true`, `dirty: false`, `formal: true`. See `docs/phase4/phase4-b0-navigation-baseline.md` (`git_head=9518d40d`) |
| Idle cold-start | `ok: true`, 10× `core_skipped`, `main_ready` median 143ms |
| RUNNING reattach | `ok: true` after VPN start; 9× `core_ready` with marks, 0× `core_skipped`; same `session_id`; `vpn_ready` true |
| PAUSED reopen | SMART_STOP → UI kill → reopen: presence `state=PAUSED` `smartPaused=true` same `sessionId`/`remote` pid 19987; marks `smart_paused_restored` + `paused_core_attached` + `core_skipped` |

Instrumentation is compile-time off in production release without `PHASE4_PERF`. Ordinary production Release does not register `Phase4PerfPlugin` or `Phase4PerfReceiver`. `all` (4A idle/jank) does not include `navigation`.
