# Phase 4C.0 — Proxy / Group UX Audit & Baseline

Read-only audit. No 4C.1 product fixes. Product selection, delay, close/reset connections, Core API, SMART_STOP/RESUME, and Phase 1–3 Mihomo semantics were not changed.

## 1. Provenance

| Field | Value |
|---|---|
| git_head at capture | `5712b6cefae294215ccbf6c6d49f0e27d3d9eac1` (4B closeout) |
| worktree dirty at capture | yes (`dirty=true`, `submodule_dirty=true`) |
| tested fingerprint | `47bb7b901b2de40c` |
| Mihomo submodule | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` |
| Core ldflag Version | `v1.19.30` |
| device | `25042PN24C` serial `0604B44041A00540` |
| Android | 16 / SDK 36 |
| package | `com.slclash.app.profile` `9.9.10` |
| build mode | profile / `profiling` (`PHASE4_PERF=true`) |
| note | Package is DEBUGGABLE; harness used declared `--build-mode=profile`. |

Captures (gitignored):

- `.perf-captures/phase4/c0-idle/result.json`
- `.perf-captures/phase4/c0-running/result.json` (preconditions failed; no fake VPN)

Unit:

- `flutter test test/common/proxy_trace_test.dart` pass
- `python -m unittest tools/perf/tests/test_harness.py` 49 pass
- `flutter test test/mihomo test/providers/smart_auto_stop_test.dart` pass
- `flutter analyze` on touched Dart: no issues

## 2. Mihomo Group Contract

Source of truth: pinned Core `adapter/outboundgroup` + `hub/route/proxies.go`. Not third-party Smart forks. Parser `default` rejects unknown types including `smart`. `relay` is a hard error: use `dialer-proxy`.

Dart `Group` JSON fields: `type`, `all`, `now`, `hidden`, `testUrl`, `icon`, `name`. **Core `fixed` is not modeled** (extra JSON keys dropped).

| Group Type | Core semantic | SelectAble / PUT | Automatic | `fixed` in JSON | `now` | DELETE `/proxies/{name}` | UI | Local persistence | Mismatch? |
|---|---|---|---|---|---|---|---|---|---|
| Selector / `select` | Manual pick among `all` | yes `Set` | no | **no field** | current member | **400** (Selector skipped) | Cards write `selectedMap` then debounce PUT | `selectedMap` + SetupParams | Optimistic UI from `selectedMap`, not Core ack |
| URLTest / `url-test` | Auto lowest delay; `selected` pins | yes | yes until pinned | `fixed` = pin name / empty | alive pick or pin | `ForceSet("")` unfix | Treated as computed; tap toggles name/`''` | `selectedMap` + `computedSelectedMap` (now cache) | UI does not show Core `fixed`; empty PUT is unfix attempt |
| Fallback / `fallback` | First alive; pin via `selected` | yes | yes until pinned | `fixed` | alive or pin | unfix | same as URLTest | same | same |
| LoadBalance / `load-balance` | Per-request strategy | **no** (not SelectAble) | yes | none | **always `""`** | 400 | `isComputedSelected` includes LB; tap still PUT | `selectedMap` written anyway | **P0** UI selectable vs Core reject `"Must be a Selector"` |
| Relay / `relay` | Removed in this Core | n/a | n/a | n/a | n/a | n/a | Dart enum still parses `relay` | n/a | Config with `relay` fails Core parse |
| `smart` | **not in this Core** | n/a | n/a | n/a | n/a | n/a | would throw `GroupType.parse` | n/a | do not assume support |
| GLOBAL / Compatible | Runtime objects in proxy map | Selector-like GLOBAL | — | — | — | — | listed if Core returns them | selectedMap key if user picks | CompatibleProvider wraps inline proxies |

PUT error string still says `"Must be a Selector"` while the check is `SelectAble` (Selector, URLTest, Fallback).

## 3. SlClash Proxy Architecture

Forward:

Profile YAML → apply/setup (SetupParams.`selectedMap` only) → Mihomo → FFI `getProxiesGroups` → `groupsProvider` (+ `groupsOwnerProfileIdProvider`) → optional DB snapshot → `proxyGroupsSnapshotProvider` → `currentGroupsStateProvider` / `proxiesListStateProvider` → `ProxiesView` / `ProxiesListView` → `_buildItems` (eager Header+cards) → `ListView.builder` → `ListHeader` / `ProxyCard`.

Reverse:

`ProxyCard.onTap` → `updateCurrentSelectedMap` (immediate) → `changeProxyDebounce` (600ms, last args) → `coreController.changeProxy` → Core PUT → **result ignored** except Phase4 log → `closeConnections` or `resetConnections` → `checkIpNumProvider.add()` → `updateGroupsDebounce`.

Answers:

| Q | A |
|---|---|
| A. Core final truth? | For traffic, yes. Selector **highlight** prefers `selectedMap`. Computed highlight prefers Core `now`, then `computedSelectedMap` placeholder cache. |
| B. `selectedMap` | Profile persistence + SetupParams restore hint + Selector UI cache. Written **before** Core. |
| C. `computedSelectedMap` | UI-only last real `now` when Core shows DIRECT/REJECT/PASS. **Not** Core `fixed`. Not sent to SetupParams / changeProxy. |
| D. Snapshot | First paint / 30s freshness fallback. Hydrate writes `groupsProvider` as stale. Can show previous groups until fresh commit. Fingerprint mismatch normally refuses (unless `allowStaleOnFingerprintMismatch`). |
| E. Core write fail | `changeProxy` still close/reset + IP check. Selector `selectedMap` already updated. |
| F. UI selected, Core not? | **Yes** for Selector. Device race: 6 intents, 2 acks (debounce). |
| G. Stale groups? | Yes if ownerProfileId/empty/expired path lags; snapshot can fill first. |

## 4. First Entry Baseline

Product path (`ProxiesView.initState`): hydrate snapshot → if owner mismatch / empty / last refresh > 30s → `ensureCurrentProfileReady`.

Device idle (collapsed list, profile APK already running, no force-stop):

| Metric | Idle capture |
|---|---|
| Dashboard → Proxy `total_ms` median | 313.5 (includes 280ms `pageEnter`) |
| target first build | 33 ms (n=1) |
| first frame | 70 ms (n=1) |
| worst_frame median | 35.2 ms |
| build p50 / p90 | 2.3 / ~6–11 ms (see JSON) |
| eager `_buildItems` | **19 items, 0 ProxyCards** (groups collapsed) |
| empty→data flash | not isolated per P1–P8 on device |

P1–P8 (fresh/stale/none snapshot, provider ready/not, core down, profile switch) are **source-mapped**, not separately timed on-device in 4C.0. Do not delete snapshot/fallback in 4C.1 without those cases (H4).

## 5. Large List Baseline

Device profile: 19 groups, default collapsed → H2 **not** allocated as 300 cards on device.

Formula (matches `_buildItems`, unit-tested):

`eager_widgets = group_headers + sum(len(group.all) for expanded groups)`

| Size | Expanded one group | Eager widgets before `ListView.builder` |
|---|---|---|
| 20 | 1+20 | 21 |
| 100 | 1+100 | 101 |
| 300 | 1+300 | 301 |
| 500 | 1+500 | 501 |

500-node: **not run on device**. No synthetic profile written into user data.

## 6. Selection Baseline

Tap path is optimistic for Selector (`selectedMap` then 600ms debounce).

Idle race hook (same product path, Selector group `Edge`):

| Burst | seq | intents | Core acks this session |
|---|---|---|---|
| A→B→C | `低倍率,香港,日本` | 3 | } |
| A→B→A | `低倍率,香港,低倍率` | 3 | **2 acks total** |

`tap_to_visual_selected_ms`: Selector = same frame as `selectedMap` write (not separately timestamped).  
`tap_to_core_ack_ms`: ≥ debounce 600ms + FFI; two bursts → two acks.  
`tap_to_groups_consistent_ms`: `updateGroupsDebounce` after ack; not separately marked.

close/reset + `checkIpNum` still run after each coalesced `changeProxy`. Idle VPN was OFF; `connectivity_vpn` was already true on the device (other network/VPN), profile `vpn_service_running=false`, no tun.

## 7. Rapid Selection Race

**Last user intent is what Core receives** after debounce (last args win). Device: 6 intents → 2 `proxy_select_core_ack`.

Not a Core race of three in-flight PUTs. UI `selectedMap` follows every tap immediately; Core follows last of each 600ms window.

If Core PUT fails, UI can remain on last intent (E/F). **Not fail-closed.** Recorded; not patched.

## 8. Computed Group Semantics

Verified from pinned Core + Dart mapping, not a full 11-step device matrix per type.

- URLTest/Fallback: Core `fixed` exists; SlClash never parses it. Manual PUT works. DELETE unfix exists in Core; **no UI**.
- LoadBalance: Core not selectable; UI still computed-selectable (P0).
- `computedSelectedMap` is placeholder-`now` cache (H5). It can outlive a newer Core `now` that is DIRECT/REJECT — **display** fallback, not a Core write. Evicts if node leaves `all`.

## 9. Provider Refresh

Not separately captured. Code: `ensureCurrentProfileReady`, provider sheet, `updateProvider` then groups refresh. Snapshot fallback can be **benign stale-first UI**. Stale **selection truth** is a different class (selectedMap / computed cache). 4C.0 does not remove fallback.

## 10. Delay Test

**H1 confirmed** (unit + device n=20):

`proxies.map((p) async { await proxyDelayTest(...) }).toList()` starts work immediately. `batch(100)` only batches **await**.

| n | started | finished | failed | peak_inflight | after_map_started | `batch_limits_start` |
|---|---|---|---|---|---|---|
| 20 (device) | 20 | 20 | 0 | **20** | 20 | false |
| 20 (unit, batch 5) | 20 | — | — | **20** | — | false |

100/200/500 peak not run on device (would be a request storm; 4C.0 does not fix).

`proxyDelayTest` unwraps via `computeRealSelectedProxyState` (nested groups, selectedMap, computed cache). URL order: unwrapped `state.testUrl` then `realTestUrlProvider(group/app testUrl)`. Harness `delay_test` calls `delayTest(slice)` **without** group testUrl (app/default URL).

During delay (collapsed): `list_header` builds **126**, `proxy_card` **0**, `proxies_list` 9, `proxies_view` 3. Delay updates currently fan out to headers, not cards, when collapsed.

Classification: UX state storm / unbounded start concurrency → **candidate 4C.1**. Core IPC scheduler → **candidate 4D**. Human picks.

## 11. Rebuild Hotspots

Idle session (`proxy_session_end.hotspot_builds`):

1. `list_header` 126  
2. `proxies_list` 9  
3. `proxies_view` 3  
4. `proxy_card` 0 (collapsed)

Nav FrameTiming hotspots on Dashboard side still include `dashboard_hero` / `network_overview` (4B surface). Proxy page enter worst_frame up to **43.9 ms** on this run.

## 12. RUNNING Session Continuity

`--proxy-session running` on `com.slclash.app.profile`:

`vpn_service_not_running`, `tun_missing`, `vpn_ready_false`, `session_id_invalid`, `session_not_running`.

**Did not** `am force-stop`, restart Core, or START VPN to fake a session.

Idle run: Core `:remote` pid appeared after delay/select (`20914`) with **no tun** / VpnService still false. That is Core process, not a VPN session.

**Gap:** real VPN RUNNING Proxy UX needs a live profile-package (or agreed) session. Daily `com.slclash.app` was not used (no PHASE4_PERF on production UX APK).

## 13. Findings

### P0 correctness

1. LoadBalance is UI-selectable (`isComputedSelected`) and receives PUT; Core rejects.  
2. Selector (and any PUT) UI can show success via `selectedMap` while Core failed; `changeProxy` ignores result then still resets connections and triggers IP check.  
3. Core `fixed` / DELETE unfix not represented in Dart/UI.

### P1 high impact

1. Delay `batch(100)` is not a start limiter; peak_inflight = N for N≤100 at least (device N=20).  
2. `_buildItems` allocates every expanded `ProxyCard` before lazy `ListView.builder`.  
3. High `list_header` rebuild count on delay/sort/groups updates.  
4. Selection perceived latency includes 600ms debounce + close/reset + IP (H3), not just paint.  
5. `computedSelectedMap` can mask Core placeholder `now` (H5) — display-only, still a truth-layer risk.

### P2 polish

1. Dart `Relay` leftover; Core removed.  
2. No 300/500 device fixture.  
3. First-entry P1–P8 and provider-failure matrix not isolated on device.  
4. RUNNING Proxy continuity not captured this round.  
5. PUT error string vs SelectAble mismatch (Core).

### Accepted / no issue

- Snapshot + 30s freshness is an intentional stale-first path (H4).  
- Debounce last-write-wins matches last user intent for Core (device 6→2).  
- Instrumentation compiles out without `PHASE4_PERF`.  
- No SMART_STOP/RESUME, no 4B decision changes, no Core API edits.

## 14. Proposed Phase 4C.1

Evidence-only; **do not implement in 4C.0**:

1. Replace map/toList-then-batch-await with a real in-flight limiter **or** move limiter to Core/FFI (4D).  
2. Build list children lazily (do not pre-construct N `ProxyCard` widgets).  
3. Narrow delay/`sortNum` rebuilds to delay labels, not every `ListHeader`.  
4. Human: LoadBalance tap, fail-closed vs optimistic `selectedMap`, optional DELETE unfix control.

## 15. Product Decision Queue

- May users tap LoadBalance members?  
- Should Selector highlight wait for Core ack?  
- Should URLTest/Fallback expose pin vs auto (Core `fixed` + DELETE)?  
- Cap delay concurrency: UX (4C) vs IPC (4D)?  
- Keep snapshot stale-first?

## 16. Stop

4C.0 completed. Wait for human audit before 4C.1.

Do not auto-fix delay concurrency, rewrite the list, add optimistic selection “fixes”, delete snapshot, change `selectedMap` / `computedSelectedMap` semantics, change `closeConnections`, provider cadence, Core API, or FFI.
