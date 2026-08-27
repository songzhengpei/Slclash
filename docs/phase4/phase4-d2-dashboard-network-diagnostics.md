# Phase 4D.2 — Dashboard Network Diagnostics

Final Phase 4D product round. After this: **STOP → human audit → Phase 4D Final Closeout**. Do not invent 4D.3 unless audit finds a concrete correctness regression.

Phase 4A / 4B / 4C remain CLOSED. 4D.0 COMPLETE. 4D.1 CLOSED. No 4E / 4F.

## 1. Previous architecture

Dashboard GitHub / YouTube / ChatGPT rows lived in `_OverviewLatencyHost` as a single `_LatencyResult` per target.

On every refresh the host:

1. Set every row to `_LatencyResult.pending()` (spinner wall).
2. Issued HEAD, then GET on failure, with **one shared Stopwatch** (failed HEAD time accumulated into success).
3. Blocked the combined result on Core `/connections` polling: **18 × 160ms `getConnections()` per target**, plus a second `requestsProvider` poll loop.
4. When Core was OFF, copied `networkDetectionProvider.ipInfo.countryCode` onto every target as if it were GitHub / YouTube / ChatGPT egress.
5. Used `if (_isTestingLatencies) return;` so a route change during an in-flight test was ignored.
6. ChatGPT probed `favicon.ico`, not Cloudflare trace.

4D.0 already measured the Dashboard `getConnections` load: roughly **87/min**, peak overlap 3, from that 18×160ms loop — not leftover delay traffic.

## 2. First-principles semantics

Each row answers two **independent** questions:

| Track | Question | Must not |
|---|---|---|
| A. Latency | How long does the current real path take to receive **response headers** from this service? | Wait for route / Core tracker |
| B. Route / egress | What route / egress evidence do we actually have for this service? | Fabricate country from generic “what is my IP” |

Never block A on B. Never substitute the lower Network Detection card’s global Internet country as target-specific truth.

## 3. Latency source per target

One GET, one attempt deadline (**3s**). Clock stops when headers arrive. Body drain / parse happens after. **Reported latency = that attempt’s own elapsed time.** No HEAD→GET accumulation. No hedged second probe.

| Target | Request | Notes |
|---|---|---|
| GitHub | `GET https://github.com/favicon.ico` + `Range: bytes=0-0` | Headers only |
| YouTube | `GET https://www.youtube.com/generate_204` | Expect 204. No HEAD |
| ChatGPT | `GET https://chatgpt.com/cdn-cgi/trace` | Headers = latency; body parsed afterwards |

Core ON: `HttpClient.findProxy` → `127.0.0.1:mixedPort`. Core OFF: normal Android network.

## 4. Route source per target

| Target | Core ON | Core OFF |
|---|---|---|
| GitHub | Mihomo TrackerInfo for the probe (`routeName` = chains). Country only if a leaf/node name safely parses → **MEDIUM**. Else 🌐 | **🌐 always.** No trustworthy GitHub-side source-IP endpoint in scope. |
| YouTube | Latency URL remains `generate_204`. Egress: `GET https://redirector.googlevideo.com/report_mapping?di=no`, left-side public IP only, then `lookupCountryForIp(ip)`. `routeName` from tracker if present. | Same Google mapping path. No global-IP fallback. |
| ChatGPT | Parse `cdn-cgi/trace` `loc=` / `ip=` / `colo=`. Works on mixedPort. Tracker `routeName` if captured. | Same trace over Android network. |

## 5. Country confidence / source model

Stored on `NetworkDiagnosticTargetState`. Not prominent in the card UI.

| Source | Typical confidence | Meaning |
|---|---|---|
| `chatgptTrace` | HIGH | Cloudflare report for the chatgpt.com request itself |
| `googleReportMapping` | MEDIUM | Google AS15169 family egress, not the exact `generate_204` socket |
| `coreTracker` | HIGH route | Reserved; route identity from TrackerInfo |
| `coreChainHeuristic` | MEDIUM country | Country parsed from proxy **name** / flag emoji |
| `unknown` | unknown | 🌐 |

YouTube disagreement (chain-heuristic country ≠ Google mapping country):

- Flag = Google-derived country
- `routeName` = actual Mihomo chain
- Confidence stays **MEDIUM**
- Do not silently pick one and claim HIGH unless they agree

## 6. Core ON flow

1. Increment generation / mark refreshing (keep previous visible values).
2. **Acquire** `CoreEventType.request` lease; subscribe `CoreEventListener` **before** HTTP.
3. Issue the exact target GET.
4. Commit latency as soon as headers arrive.
5. Match **newly emitted** TrackerInfo by host / dest / `rulePayload` (not historical `requestsProvider` rows).
6. If no event: **at most one** `getConnections()` snapshot per target. Never 18×.
7. Commit country independently. Discard if generation ≠ current.

`CoreEventTypeLease` is reference-counted. The Requests page owner and diagnostics share request events. Request delivery is disabled only when **no** owner remains. This is not a Core event architecture rewrite.

## 7. Core OFF flow

Same HTTP probes without mixedPort and without tracker capture.

- ChatGPT: trace `loc` if the endpoint succeeds.
- YouTube: mapping IP → GeoIP if the endpoint succeeds.
- GitHub: country unknown (🌐).
- Global Network Detection card is unchanged and may still show CN. That is a different product concept, not a contradiction.

## 8. Stale-while-revalidate

Refresh does **not** replace `🇯🇵 92ms` with a spinner.

- Periodic refresh: keep values; bar may animate; slight opacity.
- New latency replaces ms immediately; new country replaces the flag independently.
- First-ever: 🌐 and `—`.
- Route-change: values may stay briefly with `refreshing=true`. If the new probe cannot produce route evidence by the deadline, flag → 🌐. Timeout invalidates the **latency** track. Country is cleared on route-change miss, not on a mere latency timeout of the same generation.

## 9. Generation / route revision

`NetworkDiagnosticsStore.generation` increments on every refresh begin.

`NetworkDiagnosticsRevision.bump` is the process-wide route epoch. Confirmed success paths bump it:

- `_finishSelection` only after `isCoreSelectionSuccess` (empty Core string)
- profile `setupConfig` success
- SMART_RESUME local success

Dashboard also listens to VPN start/stop, `checkIpNum` (connectivity), SMART_STOP, foreground, and Dashboard-active.

Commit rule: `if (generation != current) discard`.

Deterministic test: epoch 10 starts, epoch 11 commits, late epoch 10 must not overwrite.

Failed selection does **not** bump. Optimistic Proxy tap does **not** bump. 4C 600ms debounce / selection transaction is untouched.

Coalesce window: **200ms** (`commonDuration`-class). Manual retest bypasses coalescing.

In-flight refresh is **not** ignored. A new generation supersedes; old Futures may finish physically and are discarded.

Periodic refresh remains **60s**, only while foreground **and** Dashboard active.

## 10. Trigger matrix

| Trigger | Route-change? | Coalesced? |
|---|---|---|
| VPN / listener started | yes | yes |
| VPN stopped | yes | yes |
| Selector / URLTest pin / unfix Core SUCCESS | yes | yes (via revision + checkIp) |
| Failed selection | no | — |
| Optimistic tap before ACK | no | — |
| Profile apply success | yes | yes |
| SMART_RESUME success | yes | yes |
| Connectivity / checkIp | yes | yes |
| App foreground | yes | yes |
| Dashboard becomes active | yes | yes |
| Manual retest | no (keep country unless probe fails) | **immediate** |
| 60s timer | no | n/a |

## 11. YouTube mismatch evidence (real device)

Profile APK `com.slclash.app.profile` / `PHASE4_PERF=true`, device `25042PN24C` serial `0604B44041A00540`.

VPN-start diagnostics (generation 1, `reason=vpn_start`):

| Target | latency_ms | country | source | route_source |
|---|---|---|---|---|
| GitHub | 395 | HK | `coreChainHeuristic` | **snapshot** |
| YouTube | 602 | HK | `googleReportMapping` | none (tracker miss) |
| ChatGPT | 668 | SG | `chatgptTrace` | none (tracker miss) |

GitHub snapshot (not treated as ground-truth country):

- `metadata.host=api.github.com`
- `destinationIP=20.205.243.168`
- `remoteDestination=58.247.187.115`
- `rule=RuleSet` `rulePayload=github`
- `chains=🇭🇰 香港实验… IEPL 专线 1>低倍率>Edge 01`

YouTube / ChatGPT snapshot sample (no `youtube.com` / `chatgpt.com` row still live):

- `|172.67.215.122|172.67.215.122||DIRECT`
- `|23.249.18.3|23.249.18.3||DIRECT`
- `sipnj21.xnq.r.10086.cn|…|cn|🇨🇳 直连…`

**Diagnosis:** the previous “YouTube wrong flag” is **not** a proven Mihomo chain-order bug. The `generate_204` tracker is often already gone before a single snapshot; Dart `CoreEventType.request` did not hit in this run. The flag is Google `report_mapping` egress (here HK), which is **service-family** evidence (MEDIUM), independent of the node-name heuristic. Chains were **not** reversed as a patch.

ChatGPT SG from `cdn-cgi/trace` is HIGH and does not use the GitHub HK chain.

## 12. Before / after `getConnections`

| | Before (4D.0 / old card) | After (4D.2) |
|---|---|---|
| Per diagnostics cycle | up to **18 × 3 targets** (plus `requestsProvider` 36×80ms) | **0** event hits, or **≤1 snapshot per target** on miss |
| This device refresh | ~54 potential polls | **3** `getConnections` (one per target; GitHub matched, YT/GPT unmatched) |
| Global coalescer | not added | not added (4D.1 deferral kept) |

## 13. Before / after visible timing

| | Before | After (this device, VPN start) |
|---|---|---|
| Spinner wall | all three rows pending | **no**; latency committed independently |
| Latency visible | after HEAD+GET **and** connection poll | GitHub **395ms** from refresh; YouTube **603ms**; ChatGPT **669ms** |
| Country visible | coupled to latency result | GitHub snapshot **809ms**; ChatGPT trace **813ms**; YouTube mapping **1031ms** |
| First-start multi-thousand ms | HEAD fail + GET success could inflate | First probes **395 / 602 / 668**. Earlier overlay: first YouTube **299**, second **158**. Residual hundreds of ms treated as **real path RTT**, not measurement-path noise. **No hedging.** |

## 14. RUNNING continuity

Overlay-install of a new profile APK tears down the previous TUN (expected). Diagnostics workload is measured on a **new** RUNNING session after `TempActivity` START — not by force-stopping the daily `com.slclash.app` package.

Workload (first overlay): Dashboard wait → Proxy `select_named` Core ACK (`group=Final`, `result=ok`) → Dashboard. Remote pid / sessionId / tun0 unchanged across that workload.

Second overlay (match + 800ms event wait):

| Field | Before workload | After workload |
|---|---|---|
| remote pid | 20961 | 20961 |
| sessionId | 1787287566694 | 1787287566694 |
| tun | tun0 | tun0 |
| state | RUNNING | RUNNING |

Diagnostics did not call VPN start/stop during the Dashboard probes. `setupConfig` / `startListener` in logcat belong to UI attach after overlay, not to the diagnostic HTTP loop.

## 15. Tests

`test/common/network_diagnostics_test.dart` plus existing 4C / 4D.1 suites:

- GitHub GET-only + Range; YouTube `generate_204`; no HEAD accumulation
- Latency commits before delayed route
- Refresh preserves previous visible result
- Stale generation discarded
- Core OFF does not reuse global country
- ChatGPT trace parser + missing fields
- Google mapping IP parser + malformed body
- Explicit-IP GeoIP (IP in URL, first valid wins, stale gen cancels)
- Tracker match; request-event hit; event miss + ≤1 snapshot; no 18× loop
- Revision bump vs failed `isCoreSelectionSuccess`
- 4C `proxy_group_selection` / fixed / compute / readiness / SMART_STOP still pass

`flutter analyze`: existing infos only after fixing 4D.2 warnings. `python -m unittest tools/perf/tests/test_harness.py`: 55 OK.

GitHub has no configured status checks: **do not claim CI PASS.**

## 16. Accepted limitations

1. **GitHub Core OFF** target-specific egress country is not reliably observable. Unknown (🌐) is correct. Do not fabricate 🇨🇳 from Network Detection.
2. Dart `CoreEventType.request` did not hit for these Dashboard probes on this device. Snapshot fallback is the working Core ON path for longer-lived connections (GitHub). Short `generate_204` / trace sockets may miss both event and snapshot; YouTube/ChatGPT countries then come from **their own HTTP evidence**, not from a guessed node.
3. Country from a proxy **name** is heuristic (MEDIUM), never ground truth.
4. Google `report_mapping` is YouTube/Google-family egress, not the exact `youtube.com` socket.
5. Matching `rulePayload` / host substring `github` can attach a nearby GitHub connection (here `api.github.com`) rather than the favicon socket. Recorded for audit; not a chain-order rewrite.
6. No hedged probes, no per-WiFi cache, no diagnostics settings, no Network Detection redesign, no traffic-poll or delay-concurrency change, Mihomo pin unchanged.

Pinned Mihomo before/after: `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`.
