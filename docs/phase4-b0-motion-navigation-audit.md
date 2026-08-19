# Phase 4B.0 — Existing Motion / Navigation Audit

Date: 2026-08-19  
Branch: `beta`  
Audit start SHA named by the brief: `3cca318b` (`fix: keep outbound fill yellow on smart-pause reopen`)  
Worktree HEAD when this phase landed: `ae8e6811` (TUN DNS after named start `3cca318b`; not a motion/navigation change)  
Motion token source of truth: `lib/widgets/surge/surge_motion.dart`  
This phase does **not** create a new Motion System, rename SurgeMotion, or change product visuals.

Related captures: `docs/phase4-b0-navigation-baseline.md` (formal profile APK FrameTiming). Idle `dumpsys gfxinfo` is **not** a navigation baseline.

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

Formal numbers: `docs/phase4-b0-navigation-baseline.md` (regenerated after a harness no-op-navigate fix; the first capture already showed the same hotspots).

Headline (profile / `com.slclash.app.profile` / 25042PN24C / 120Hz / budget 8.33ms; `ok: true` capture `2026-08-19T08:47:20Z`):

- A Dashboard↔Proxy (n=20): total_ms median **313.5**, p90 **324.3**; worst-frame median **13.1ms**; over-budget median **7** frames; scroll DFS median **590µs** / 1935 elements / 1 position.
- B round-robin (n=40): total_ms median **307.5**; worst-frame median **13.6ms**.
- C: first vs revisit **total_ms** are similar (~303 vs ~315) because both include 280ms `pageEnter`. The split is **first_build_ms**: first median 23.5ms; Dashboard revisit later in the session 87–100ms.
- D same-tab reselect on Proxies (n=1): **50ms** total, **517µs** DFS. UX unchanged.
- E mounts: **dashboard 24**, others **1**.

Method (not idle gfxinfo):

- Package `com.slclash.app.profile`, `--dart-define=PHASE4_PERF=true`
- Same device / config / page data / profile build / display mode as 4A.2
- Flutter `FrameTiming` via `WidgetsBinding.addTimingsCallback` **only while a transition is active**
- Frame budget = `1000 / refreshHz` (Dart display + dumpsys cross-check)
- Workloads A–E as specified (≥10 round trips / ≥10 cycles)
- ADB trigger: `am start` extras (`phase4_cmd`) on already-exported `MainActivity` (`singleTop` / `onNewIntent`). `Phase4PerfReceiver` exists with `exported=false` but OEM broadcast delivery was unreliable on the Xiaomi test device; the harness does not depend on it.

Production release without `PHASE4_PERF` does not register the timings callback (compile-time `enabled == false`).

---

## 4. Top performance hotspots (ranked)

Pre-measure architecture guesses (Dashboard remount, overlapping scroll-to-top, DFS, hero tickers) are superseded by the table below. DFS was a candidate and **lost**.

**Measured ranking (profile APK, 120Hz, budget 8.33ms, same device as 4A.2):**

| Rank | Hotspot | Class | Evidence |
|---|---|---|---|
| 1 | Dashboard `keep: false` remount | T + **P7** | E: `dashboard` 24 mounts / 26 builds vs proxies/profiles/tools **1/1**. C: Dashboard revisit `first_build_ms` 89–100ms (tools→dashboard) vs keep-alive Proxy with **no** remount `first_build`. |
| 2 | `pageEnter` 280ms floor on every tab change | **P4** | A total_ms median **313.5** (min 302). Almost all of that is the tokenized animation, not DFS. Changing it changes feel. |
| 3 | Over-budget frames *during* PageView animation | T | A: median **7** frames >8.33ms, worst-frame median **13.1ms** p99 **26.9ms**. Not caused by scroll DFS. |
| 4 | `visitChildElements` scroll-to-top | T, **not a hotspot** | A: median **590µs**, p99 **813µs**, 1935 elements, **1** ScrollPosition. ~7–10% of one 120Hz frame. **Do not rewrite in 4B.1.** |
| 5 | Hero fill/sheen tickers | P | Only relevant when Dashboard remounts mid-start. Durations are P1/P2. |

**Recommended Phase 4B.1 single target (engineering, not a product decision):**  
**Dashboard remount** (`KeepScope keep: false`). It is the only extra CPU source that is both large and not the 280ms motion token. Keep-alive vs remount is **P7** — do not flip `keep` until that product call. If P7 stays remount, the next *technical* slice is cutting work that currently runs on the destination Dashboard during `animateToPage` (still without changing auto-to-top or motion tokens). Scroll-controller registry is **not** 4B.1; the DFS is sub-millisecond. **Do not start 4B.1 in this commit.**

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
| T6 | `PageView` + Dashboard `keep:false` forces remount | Recorded; keep flag is also P. |
| T7 | Production must not keep a standing `TimingsCallback` | Callback bind/unbind around an active transition; `enabled` is compile-time false in release without `PHASE4_PERF`. |

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
5. **Test-only containment?** Yes: `exported=false`, or profile/debug source set, or a signature permission. Pattern used this phase for **navigation** (`Phase4PerfReceiver` exported=false).

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

- **Current:** Dashboard remounts every visit.
- **Technical evidence:** Workload C (first vs revisit) + E (mount counts). Hero/overview/detection reconstruct.
- **Why product:** Fresh dashboard vs memory / preserving Hero animation / scroll.
- **Option A:** Keep remount (today).
- **Option B:** `keep: true` like Proxies (may preserve stale charts/hero unless you reset).
- **Option C:** Keep alive but reset selected substate on show.
- **Engineering recommendation:** If C shows revisit ≈ first, B/C is the largest 4B win — **only after you pick the UX**.
- **Performance implication:** Largest likely CPU/jank win; B increases idle memory.

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

- Hero semantic connecting (T1) + tests
- Tiny Hero listen merge (S)
- Extract scroll visitor (S1) without changing jump/animate/to-top
- `PHASE4_PERF` / profile/debug navigation instrumentation + non-exported ADB receiver
- Harness `navigation` command, docs, tests
- **No** duration/curve/sheet/hero aesthetic/scroll-UX/Proxy 4C/navigation rewrite

## 9. Phase 4B.1

Stop here. Product needs P7 (Dashboard keep-alive) and optionally P4/P6. Engineering 4B.1 target is Dashboard remount, **not** scroll DFS. Do not start 4B.1 in this commit.

## 10. Gates (this commit)

| Gate | Result |
|---|---|
| `flutter analyze` (touched Dart) | No issues |
| Flutter tests (nav/hero/scroll + Phase 1–3 mihomo/action) | Pass |
| Full `flutter test` | 796 pass; **1 pre-existing fail** `app_changelog_test` expects v2.0.7, repo is v2.0.9. Not from this phase. |
| `python -m unittest tools.perf.tests.test_harness` | 43 OK |
| Android `:service:test` | BUILD SUCCESSFUL |
| `:app:testDebugUnitTest` | No app unit tests; compile in `--offline` also lacks unused Flutter ABI debug jars (armeabi-v7a/x86_64). Not a 4B.0 source error. |
| Navigation FrameTiming baseline | `ok: true`, see `docs/phase4-b0-navigation-baseline.md` |
| Idle cold-start | `ok: true`, 10× `core_skipped`, `main_ready` median 142.5ms. 4A idle path intact. |
| RUNNING reattach | `ok: true` after VPN start; 10× `core_ready`, 0× `core_skipped`; same `session_id`; `vpn_ready` true. |
| PAUSED reopen | SMART_STOP → UI kill → reopen: presence `state=PAUSED` `smartPaused=true` same `sessionId`/`remote` pid; marks `smart_paused_restored` + `paused_core_attached` + `core_skipped` (no RUNNING applyProfile). Hero connecting pulse is unit-tested (T1). |

Instrumentation is compile-time off in production release without `PHASE4_PERF`. `all` (4A idle/jank) does not include `navigation`.
