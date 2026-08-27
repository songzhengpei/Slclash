# Phase 4D Final Closeout

Phase 4D is **CLOSED**. Do not create Phase 4D.3. Phase 4E (VPN Lifecycle) is also **CLOSED**; current work is Phase 4F.0. See `docs/phase4/phase4-e-final-closeout.md` and `docs/phase4/phase4-f0-background-power-baseline.md`.

Phase 4A / 4B / 4C remain CLOSED. Mihomo pin unchanged.

| Field | Value |
|---|---|
| audit baseline | `8f1b14be6f403f8b4ba19d58688cb9f0a4dc33a3` |
| pipeline (4D.2) | `853d220742c17903e756779014aaafc591f96da5` |
| pinned Mihomo | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` |
| device | `25042PN24C` serial `0604B44041A00540` |
| package | `com.slclash.app.profile` / `PHASE4_PERF=true` |

## 4D.0 findings

Dashboard `getConnections` load in 4D.0 was the old Overview card’s **18 × 160ms** poll loop (about **87/min**), not leftover delay-test traffic.

Command-style Core IPC collapsed transport null into `""`, which callers treated as confirmed success. Declared per-call timeouts were not always passed into `withTimeout`.

Those two classes of defect are independent: 4D.1 fixed the command/timeout contract; 4D.2 rebuilt diagnostics so Dashboard no longer polls connections 18× per target.

## 4D.1 command outcome contract

For command-style String Core APIs:

- Core `""` = confirmed success
- Core nonempty string = confirmed Core error
- pre-invoke not-ready / transport null / transport timeout = **OPERATION NOT CONFIRMED** (`Core did not confirm the operation`)

`setupConfig` TUN preload and `changeProxy` success handling require confirmed `""`. Transport null is not success.

If `timeout != null`, `CoreLib.invoke` passes it to `withTimeout`. Dart `Future.timeout` still does not cancel the remote Core request; a timeout remains unconfirmed.

Read/display APIs stay fail-soft. 4C selection debounce, delayTest concurrency, traffic polling, and Mihomo were not changed.

## 4D.2 diagnostics architecture

Each Dashboard target answers two independent questions:

1. **Latency** — headers of one GET, 3s, no HEAD→GET accumulation, no hedge.
2. **Route / egress** — only evidence that belongs to that target.

| Target | Latency | Country / route |
|---|---|---|
| ChatGPT | `GET https://chatgpt.com/cdn-cgi/trace` | `loc` / `ip` from the body (**HIGH** `chatgptTrace`) |
| YouTube | `GET https://www.youtube.com/generate_204` | Google `report_mapping` left-side IP → explicit-IP GeoIP (**MEDIUM**) |
| GitHub | `GET https://github.com/favicon.ico` + `Range: bytes=0-0` | Core tracker chains → node-name/emoji heuristic (**MEDIUM**). Core OFF: 🌐 |

Other 4D.2 rules that stay frozen:

- 60s periodic refresh, stale-while-revalidate, generation discard
- 200ms coalesce; manual retest bypasses coalesce
- `NetworkDiagnosticsRevision.bump` only on confirmed 4C success / profile apply / SMART_RESUME
- ≤1 `getConnections()` per target per refresh
- request events opportunistic; no second Core event architecture
- no Network Detection country copied onto a target

## GitHub live-route audit defect

Human audit of 4D.2 found one concrete correctness defect.

Then-current GitHub flow could:

1. finish the favicon HTTP request
2. `HttpClient.close(force: true)`
3. wait up to 800ms for a request event (`eventHit=0` on device)
4. only then call `getConnections()`

The favicon socket was often already gone. The matcher also treated nearby GitHub names as the probe (`field.contains('github')`, subdomain suffix), so a live `api.github.com` row with `rulePayload=github` was accepted as the favicon probe.

4D.2 device snapshot (wrong host, still useful as the defect record):

- host `api.github.com`
- `rule=RuleSet` `rulePayload=github`
- chains `🇭🇰 香港实验…>低倍率>Edge 01`

Unknown is better than that false flag. ChatGPT / YouTube strategies were not the defect and were not rewritten.

## Final fix

HTTP helper gained a headers-arrived hook while the response is still live. GitHub (and the other diagnostic GETs) now:

1. arm opportunistic request-event capture
2. start the probe GET
3. on headers: commit latency immediately
4. while the socket is still open: use an event hit **or one** `getConnections()` snapshot
5. drain / close in `finally`

Matcher uses `Uri.parse(target.probeUrl).host` only (case + optional port). For GitHub that is **`github.com`**. Rejected:

- `api.github.com`
- `raw.githubusercontent.com`
- `githubusercontent.com`
- `rulePayload=github` without an exact host
- historical connections older than arm − 2s

Decision gate: live exact `github.com` capture is reliably usable on this device → **KEEP GitHub**. Claude `cdn-cgi/trace` replacement was not performed.

## GitHub real-device repeatability

Same profile APK overlay, then `TempActivity` START. Ten Dashboard revisit cycles (proxies → dashboard) plus the initial VPN/foreground probes.

| | Count |
|---|---|
| GitHub latency commits | 21 |
| GitHub live snapshots | 21 |
| request-event hits | 0 |
| GitHub route misses | 0 |
| `api.github.com` accepted as probe | 0 |

Every snapshot host was **`github.com`**. Typical row:

- latency ~330–500ms (headers)
- `rule=RuleSet` `rulePayload=github`
- `destinationIP=20.205.243.166`
- `remoteDestination=58.247.187.115`
- chains `🇭🇰 香港实验… IEPL 专线 1>低倍率>Edge 01`
- `route_source=snapshot`
- displayed country **HK** (MEDIUM `coreChainHeuristic`)

The flag did not randomly disappear after socket close. Event capture remains unused on this device; live snapshot is the deterministic path.

Confirmed selection (waited for Core ACK, not optimistic tap):

| Step | Core ACK | Then GitHub |
|---|---|---|
| stable HK node already selected | n/a | host `github.com`, country **HK** |
| `select_named` `group=Edge 01` → `低倍率-负载均衡` | `result=ok` (8ms transport) | host `github.com`, chains `🇺🇸 美国实验… IEPL 专线 1>低倍率-负载均衡>Edge 01`, country **US** |

A JP leaf was not the `Edge 01` `all[1]` member on this profile; US is a second recognizable node-name country. 🌐 remains correct when the chain has no country token.

## ChatGPT route semantics

Unchanged from 4D.2. Headers = latency. Body `loc` / `ip` = HIGH `chatgptTrace`. This device: ~170–250ms, country **SG**. Tracker snapshot often exists now (`host=chatgpt.com`) but country does **not** come from the chain heuristic.

## YouTube route semantics

Unchanged from 4D.2. Latency remains `generate_204`. Country remains Google `report_mapping` + explicit-IP GeoIP (MEDIUM; HIGH only if the heuristic agrees). This device: ~120–210ms, mapping country **HK**, tracker `www.youtube.com` with `🇭🇰 HKG 15>Edge 02>YouTube`.

## getConnections before / after

| | 4D.0 old card | 4D.2 (audit) | Closeout (this fix) |
|---|---|---|---|
| Per target | 18 × 160ms | ≤1 after HTTP close + 800ms wait | ≤1 **while the probe socket is alive** |
| GitHub host | n/a / nearby GitHub traffic | `api.github.com` false match | exact `github.com` |
| This device | ~87/min class load | 3 per refresh | still 3 per refresh (one/target); GitHub 21/21 exact hits |

No 18× loop. No extra polling. Event hit still skips the snapshot for that target.

## IPC observations

Diagnostics still do not add a Core event architecture. `getConnections` remains a bounded read. `changeProxy` on the Edge 01 switch used the 4D.1 command contract: `result_class=success`, `proxy_select_core_ack result=ok`. Dashboard probes did not issue `setupConfig` / VPN start.

Request events: `eventHit=0` again. Accepted; live snapshot is sufficient for GitHub.

## Accepted deferrals (not this phase)

- Dart `CoreEventType.request` reliability (device still 0 hits)
- YouTube country is Google-family mapping, not the exact `generate_204` socket as GeoIP ground truth
- GitHub Core OFF remains 🌐 (no trustworthy GitHub egress endpoint in scope)
- Node-name country is MEDIUM heuristic, never ground truth
- No global `getConnections` coalescer (4D.1 deferral)
- No traffic-poll / delay-concurrency / 4C selection changes
- No Network Detection redesign
- VPN lifecycle / background policy → **Phase 4E+**
- Do not replace GitHub with Claude / Spotify / Telegram

## RUNNING continuity

Overlay-install tears the previous TUN (expected). After `TempActivity` START, diagnostics + Proxy selection + Dashboard must not restart Core/VPN.

This closeout session:

| Field | Before Dashboard/Proxy/Dashboard | After |
|---|---|---|
| remote pid | 2883 | 2883 |
| sessionId | 1787289094355 | 1787289094355 |
| tun | tun0 | tun0 |
| state | RUNNING | RUNNING |

## Tests

`test/common/network_diagnostics_test.dart` (24):

- headers → latency commit → live snapshot → HTTP release
- exact `github.com`; `api.github.com` does not satisfy GitHub fallback
- historical GitHub connection ignored
- one snapshot maximum per target; event hit skips that target’s snapshot
- latency does not wait for route
- stale generation discarded
- Core OFF GitHub unknown; no Network Detection fallback
- 4C `isCoreSelectionSuccess` gate unchanged

Also run: 4D.1 `command_outcome`, Core IPC trace, 4C `proxy_group_selection` / fixed / compute / provider readiness / SMART_STOP, `python -m unittest tools/perf/tests/test_harness.py` (55 OK).

`flutter analyze` on the changed diagnostics files: no issues. Workspace still has existing info-level deprecations elsewhere.

## CI truth

GitHub has **no configured status checks** on this private repo. Local tests ran green. **Do not claim CI PASS.**

## Pinned Mihomo

Before = after = `ac017cdd246ce8bd547653d927e7bf77d7ee73d5`.

Android Go builds still apply `proxy-only-traffic.patch` in-place. That dirt is restored and not committed.

## Carry forward

Only these belong later:

- **Phase 4E — VPN Lifecycle** (start/stop, overlay TUN teardown vs product RUNNING, background policy)
- Optional later: request-event reliability, GitHub Core-OFF country (only with a real GitHub-side source), global connection-read coalescing

Nothing in this closeout requires a 4D.3.
