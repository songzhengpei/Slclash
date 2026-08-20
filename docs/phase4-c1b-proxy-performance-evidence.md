# Phase 4C.1B — Proxy Performance Evidence Completion

Measurement only. No 4C.1C product fixes. 4C.1A selection / `fixed` / unfix / LoadBalance / 600ms debounce / close-reset semantics were not changed. Mihomo submodule was not changed.

## 1. Provenance

| Field | Value |
|---|---|
| git_head at capture | `ce52834d0617c908e67cb0532a2f33cdb7707b12` (instrumentation was dirty on top) |
| dirty at capture | yes (`dirty=true`, `submodule_dirty=true`) |
| worktree_fingerprint (idle) | `91e1aa60aac41369` |
| pinned Mihomo | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` (`v1.19.30`) |
| device | `25042PN24C` serial `0604B44041A00540` |
| Android | 16 / SDK 36 |
| package | `com.slclash.app.profile` `9.9.10` |
| build mode | profile / `profiling` (`PHASE4_PERF=true`) |
| session | IDLE captured; RUNNING **blocked** (see §11) |

Refresh-rate: same device as Phase 4B / 4C.0. Proxy harness did not re-emit dumpsys vs Flutter `display.refreshRate` in this block. FrameTiming percentiles and `worst_frame_ms` remain comparable. Do not treat dumpsys 120 Hz as the FrameTiming budget.

Raw captures:

- `tools/perf/results/phase4c1b/idle/result.json`
- `tools/perf/results/phase4c1b/running/result.json`

## 2. Workloads

- IDLE: Dashboard → Proxy, delay_test 20 then 100, event-scoped E1–E7, unfold/scroll, ~10 named selects, A→B→C and A→B→A races, cross-group, pin/unfix attempt, Proxy → Dashboard → Proxy.
- RUNNING: preconditions checked only. No force-stop, no Core restart, no fake VPN.
- Structure: `tools/perf/fixtures/selector_{20,100,300,500}.yaml` plus unit/widget `_buildItems` / `ListView.builder` pattern. Fixtures were **not** imported into a user profile.

## 3. First Entry P1–P8

Device this session (`proxy_page_entry`):

| scenario | first frame | first visible | fresh | FrameTiming | Core calls |
|---|---|---|---|---|---|
| Device open | Dashboard→Proxy first_frame median **39 ms** (n=1 of 2 transitions) | `proxy_first_group_visible` at 13375 ms process elapsed | `P2_stale_snapshot` (`expired=true`, `groups_empty=false`, `ensure_ready=true`, `force_apply=false`) | build p50 1.7 ms / p90 2.4 ms / p99 9.8 ms; raster p50 4.2 / p90 6.5; totalSpan p50 6.6 / p90 11.1; worst_frame median 21.4 ms | not isolated this open |

P-matrix (deterministic + this device):

| ID | Result | Evidence |
|---|---|---|
| P1 fresh/warm | groups already present; hydrate then 30s refresh | Device had groups; `force_apply=false`. Entry plan `ensureReady` is false when not expired. |
| P2 stale snapshot | **observed** | `scenario=P2_stale_snapshot`. Stale-first then `ensureCurrentProfileReady`. No blank flash isolated. `fixed` equality from 4C.1A still applies on fresh commit. |
| P3 no snapshot | plan + empty UI | `ProxyPageEntryPlan` `P3_no_snapshot`; `ProxiesEmptyState` kinds unit-tested. |
| P4 no provider | PASS | `provider_readiness_service_test`: `noProviders` does not connect Core. |
| P5 provider ready | PASS | same suite: ready commits after core+groups. |
| P6 provider not ready | PASS (harness) | empty then appears; timeout does not commit incomplete groups. |
| P7 Core unavailable | source + marks | `_updateGroups` paths `same_profile_old` / `stale_snapshot` / `empty`. This IDLE run emitted **no** `proxy_groups_core_unavailable` (Core was up). |
| P8 profile switch | plan + owner guard | `P8_owner_mismatch` ⇒ `forceApply=true`. `_updateGroups` drops results when `currentProfileId != requested` (`proxy_groups_owner_guard`). Not executed as a live A→B switch this round. |

## 4. Large Group

Device profile expanded group `Final` (2 members). Not a 300/500 device list.

| Size | Eager widgets (`headers + expanded`) | Device |
|---|---|---|
| 20 | 21 | formula + unit |
| 100 | 101 | formula + unit |
| 300 | 301 | formula + unit |
| 500 | 501 | formula + unit + widget viewport |

Expand/collapse on device: `Final` expand → eager_items **21** (19 headers + 2 cards), collapse → 19 / 0 cards. Scroll/fling via `scroll_by`. scroll-to-selected not separately timed.

## 5. Eager Materialization

`_buildItems` still allocates expanded `ProxyCard` widgets before `ListView.builder`.

Widget test (same allocation pattern: prebuild 500 children, then `ListView.builder` `itemExtent=48` viewport 640):

- materialized = **500**
- first viewport builds **< 40** (and > 0)

Device expand of a 2-node group: `proxy_item_materialized=21`, `proxy_card` builds in E4 = **6** (includes rebuilds), not 300/500.

Conclusion: eager widget objects exist; `build()` is still viewport-limited. **Do not rewrite the list in 4C.1B.**

## 6. Event-Scoped Rebuilds

Reset → event → ~0.9s → dump. Collapsed list unless noted.

| Event | ProxiesView | ProxiesList | ListHeader | ProxyCard | eager items / cards |
|---|---|---|---|---|---|
| E1 selected node | 0 | 0 | 0 | 0 | 0 / 0 |
| E2 one delay | 0 | 0 | 0 | 0 | 0 / 0 |
| E3 sortNum | — | 2 | **28** | 0 | 19 / 0 |
| E4 expand | — | 3 | **36** | **6** | 21 / 2 |
| E5 collapse | — | 1 | 14 | 0 | 19 / 0 |
| E6 groups refresh | — | 2 | **28** | 0 | 19 / 0 |
| E7 fixed-only | 0 | 0 | 0 | 0 | 0 / 0 |

Session totals (not event-scoped): `list_header:412`, `proxies_list:27`, `proxy_card:2`.

E1/E2/E7 dumps with empty hotspots: collapsed list + settle window; E7 had no URLTest pin group (`proxy_select_fixed` may no-op / ignore). Delay updates still fan out when they hit sort/list (E3).

## 7. Selection Latency

Selector named taps + races. Visual is optimistic `selectedMap` (not debounce).

| Metric | n | median | p90 | max |
|---|---|---|---|---|
| tap_to_visual_selected_ms | 19 | **0** | 1 | 1 |
| tap_to_core_ack_ms | 14 | **610** | 615 | 619 |
| tap_to_groups_consistent | 14 consistent marks | ~ack + groups debounce | — | — |

`tap_to_core_dispatch` ≈ 600 ms debounce + dispatch mark. **Do not treat 600 ms as UI jank.** Visual is same-frame.

URLTest pin/unfix: command issued; E7 dump empty — this profile’s first expandable group was Selector `Final`, not a convenient URLTest. Semantics unchanged from 4C.1A tests.

## 8. Rapid Selection

Generation trace (IDLE session):

| | count |
|---|---|
| intent | 19 |
| superseded | 5 |
| dispatch | 14 |
| ACK | 14 |
| visual | 19 |
| groups_consistent | 14 |

`ack_gens` = `[1,3,4,5,6,7,8,9,10,11,14,17,18,19]` while latest intent was 19. **`ack_bound_to_latest_only=false`**. ACK uses the request `gen`, not global latest.

Device races: `proxy_select_race_issued` abc and aba on Selector `Edge`. Cross-group command also issued.

## 9. Delay Concurrency

`map(async).toList()` still starts work immediately. `batch(100)` is await grouping only.

| n | started (after map) | peak_inflight | source |
|---|---|---|---|
| 20 | 20 | **20** | unit + 4C.0 device; this run combined with 100 |
| 100 | 100 | **100** | this IDLE device (`after_map_started=100`) |
| 300 | 300 | **300** | unit (not run on device Core) |
| 500 | 500 | **500** | unit (not run on device Core) |

IDLE combined logcat: started 121 / finished 121 / failed 0 / peak **100** (20 + 100 + E2 one-shot). Session `delay_started=101` after the last reset window.

FrameTiming during delay was **not** a separate capture; nav Dashboard↔Proxy worst_frame median 21.4 ms. Rebuild during delay/sort: ListHeader (E3=28). No 300/500 delay on device (would be a Core request storm).

## 10. Provider Refresh

No extra product architecture. Deterministic `ProviderReadinessService` tests cover:

| ID | Result |
|---|---|
| PR1 cached / already ready | ready, one core connect |
| PR2 successful refresh | commitReady with valid snapshot |
| PR3 slow / empty then ready | retries until providers/groups appear |
| PR4 failed / timeout | timeout, no incomplete commit |
| PR5 membership / groups become valid | empty then valid |
| PR6 selected disappeared | **not a dedicated device case**; 4C.1A still owns selection maps |
| PR7 group membership | groups-valid predicate in readiness tests |
| PR8 page open during update | `updateGroups` reuse + owner guard; E6 dump ListHeader 28 |

Device IDLE did not flash empty (`groups_empty=false` at entry).

## 11. RUNNING Continuity

`python tools/perf/phase4.py proxy --proxy-session running` on `com.slclash.app.profile`:

| | |
|---|---|
| blocked | **4C.1B BLOCKED: real RUNNING evidence unavailable** |
| reasons | `vpn_service_not_running`, `tun_missing`, `vpn_ready_false`, `session_id_invalid`, `session_not_running` |
| fake? | **no** |
| force-stop? | **no** |
| Core kill? | **no** |

Profile package has a `:remote` pid at times without tun / VpnService. Daily `com.slclash.app` pid was present; `proc/net/dev` had **no `tunN`**. `connectivity_vpn=true` is another network/VPN, not this app’s session.

Do not treat connection reset after node switch as a VPN session break. That path was not exercised under a real RUNNING session this round.

## 12. Hotspot Ranking

Ranked from this evidence, not from 4C.0 guesses.

1. **Delay start fan-out** — trigger `delayTest(N)`; n=100 device peak_inflight=100; unit n=500 peak=500. Rebuild: ListHeader during sort. User-visible: delay pills/headers churn, possible jank under large N. **CANDIDATE-UX** (Dart `map(async)` start limiter). If the pain is FFI queue/timeout, **Phase 4D**.
2. **ListHeader fan-out** — E3/E6 ≈ 28 header builds per sort/refresh; session 412. Collapsed cards stay 0. User-visible: header row flicker/cost. **CANDIDATE-UX**.
3. **Eager `_buildItems` allocation** — 500 widgets vs <40 builds in the structural test; device group only 2 nodes so **Low impact on this profile**. Still the architecture for a 300/500 expand. **CANDIDATE-UX** for large groups; **ACCEPTED** for current 2-node expand.
4. **Selection Core latency ~610 ms** — almost entirely 600 ms debounce. Visual 0–1 ms. **ACCEPTED** as product timing, not frame jank.
5. **RUNNING Proxy UX** — evidence missing, not a measured hotspot.

## 13. 4C.1C Candidates

### CANDIDATE-UX

- Real in-flight limiter for `delayTest` starts (keep Mihomo delay semantics).
- Narrow sortNum / delay rebuilds so ListHeader is not a 28× fan-out.
- Lazy `ProxyCard` construction if a 300/500 expand is in-scope (measure again on a fixture profile).

### CANDIDATE-IPC

- Core delay/select request scheduling, queue, timeout (if limiter in Dart is not enough).

Do **not** implement these in 4C.1B.

## 14. Phase 4D Deferred

- IPC `null` vs empty success (still 4D).
- FFI/backpressure / delay request scheduler inside Core.
- Runtime polling cadence.

## 15. Acceptance

| Gate | Status |
|---|---|
| A generation trace ACK bound to request gen | PASS (`ack_bound_to_latest_only=false`; superseded recorded) |
| A event-scoped counters | PASS (E1–E7 dumps) |
| B P1–P8 | PASS as mix of device P2 + deterministic P3–P8; live P8 switch not run |
| C 20/100/300/500 list | formula+unit+widget; device only 2-node expand |
| D selection latency + races | PASS IDLE |
| E delay peak 20/100 device; 300/500 unit | PASS (300/500 not on device Core) |
| F provider | PASS deterministic; PR6 not device |
| G RUNNING | **BLOCKED** (environment; not faked) |
| H 4C.1A / Mihomo / SMART_STOP / 4B | untouched product semantics |

4C.1B complete. Wait for human audit before 4C.1C.
