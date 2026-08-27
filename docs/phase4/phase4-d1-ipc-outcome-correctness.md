# Phase 4D.1 — IPC Outcome Correctness & Timeout Contract

Measurement and control-plane correctness only. Phase 4C remains CLOSED / frozen. No getConnections coalescing, traffic cadence, delay limiter, background power, VPN state machine, or Mihomo submodule changes.

## 1. Provenance

| Field | Value |
|---|---|
| baseline | `13a0cc6dd1349dbd3e745d1b54f65174fed3c9f7` |
| pinned Mihomo | `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` (unchanged) |
| local Clash.Meta worktree | reset to pin after 4D.0.1; Android build still applies `proxy-only-traffic.patch` in-place |
| device (RUNNING smoke) | `25042PN24C` serial `0604B44041A00540` |

## 2. Before (ambiguity)

Command-style `String` Core APIs used `_invoke<String>(...) ?? ''`.

That collapsed three different facts into one value:

| Actual | Collapsed to | Caller meaning |
|---|---|---|
| Core confirmed success | `""` | success |
| Core confirmed error | nonempty | failure |
| transport null / pre-invoke not-ready | `""` | **false success** |

`CoreController.shouldPreloadVpnAfterSetup` is `message.isEmpty`. Transport null therefore allowed TUN preload.

`isCoreSelectionSuccess` is `result.isEmpty`. Transport null therefore ran close/reset/checkIp.

`validateConfig` treated “Core did not answer” as valid config.

`CoreLib.invoke` accepted `Duration? timeout` but `withTimeout` used the 3-minute default only.

Dart `Future.timeout` does **not** cancel the remote Core request. A timeout is unconfirmed, not “Core definitely rejected it.”

## 3. Contract

For command-style String Core APIs:

- Core `""` = **confirmed success** (Mihomo semantic).
- Core nonempty string = **confirmed Core error** (unchanged Mihomo string).
- pre-invoke not-ready / transport null / transport timeout = **OPERATION NOT CONFIRMED**.

Unconfirmed is `CoreCommandOutcome.unconfirmed`: `Core did not confirm the operation`.

It is a SlClash transport/control-plane failure. It is not Mihomo success and not a claimed Mihomo reject.

Helper: `CoreHandlerInterface._invokeCommandString` → `CoreCommandOutcome.fromInvoke`.

## 4. Methods migrated

| Method | Change |
|---|---|
| `validateConfig` | null → unconfirmed (cannot pass validation) |
| `updateConfig` | null → unconfirmed |
| `setupConfig` | null → unconfirmed; preload only on `""` |
| `changeProxy` | null → unconfirmed → existing 4C failure path |
| `unfixProxy` | same |
| `updateGeoData` | null → unconfirmed |
| `sideLoadExternalProvider` | null → unconfirmed |
| `updateExternalProvider` | null → unconfirmed |
| `deleteFile` | null → unconfirmed |

## 5. Intentionally not migrated (fail-soft / fail-closed)

| Method | Behavior kept |
|---|---|
| `getTraffic*` / `getMemory` / `getConnections` | `?? ''` display |
| `getExternalProviders` / `getExternalProvider` reads | `?? ''` |
| `getProxies` / `materializeProfileSnapshot` | empty `ProxiesData` |
| `asyncTestDelay` | null → delay `-1` JSON |
| `mediaCheck` | `?? ''` (not in command list this round) |
| `getConfig` | empty map; CoreController still throws |
| `startListener` / `stopListener` / `closeConnections` / `resetConnections` / `closeConnection` | `?? false` fail-closed bools |
| `init` / `isInit` / `forceGc` / `crash` | `?? false` |

## 6. Timeout propagation

If `timeout != null`, `CoreLib.invoke` passes it to `withTimeout`. If `timeout == null`, default remains 3 minutes.

Existing declared values unchanged:

- `asyncTestDelay` 6s
- `mediaCheck` request timeout (12s health / 15s default)
- `materializeProfileSnapshot` 30s

No new mutation timeouts were invented.

**Remote caveat:** Dart timeout does not cancel the in-flight Core mutation. Timeout ⇒ unconfirmed.

## 7. CoreLib control-plane audit

| Path | Before | This round |
|---|---|---|
| `preload` `service?.init()` null | `?? ''` false success | unconfirmed |
| `preload` `syncState` null | `?? ''` false success | unconfirmed |
| `shutdown` `service == null` | `?? true` false success | **false** (fail-closed) |
| `startListener` `service?.start()` | already `?? false` | unchanged |
| `stopListener` | always `true` after best-effort stop | **recorded**; idempotent stop, no VPN SM rewrite |

## 8. Instrumentation hygiene

`core_ipc_created` / `dispatch` / `complete` freeze `request_run_id` and `request_window_id` at dispatch. A complete after a later window still belongs to the dispatch window.

## 9. getConnections (deferred)

4D.0.1 observation stands. No coalescer/mutex/latency rewrite. Page/background cancellation is 4F.

## 10. RUNNING smoke

Profile APK overlay (`PHASE4_PERF=true`). Command: `python tools/perf/phase4.py proxy --build-mode profile --proxy-session running --delay-max 20`.

No induced transport timeout.

| Field | Before | After |
|---|---|---|
| remote pid | 29007 | 29007 |
| sessionId | 1787285117390 | 1787285117390 |
| tun | tun0 | tun0 |
| state | RUNNING | RUNNING |
| `continuity_ok` | — | **true** |

Also observed: Dashboard → Proxy → Dashboard; delay-test requested 20 (`failed=0`); selection intents 19 / Core ACKs 14 (superseded 5, 4C race semantics); pin/unfix included in the 4C evidence sequence. `ok=true`.

## 11. Regression

| Check | Result |
|---|---|
| `command_outcome_test` + `controller_test` + `core_ipc_trace_test` | PASS |
| 4C `proxy_group_selection_test` (incl. in-flight txn + unconfirmed rollback) | PASS |
| `fixed_test` / `compute_test` | PASS |
| `provider_readiness_service_test` | PASS |
| `smart_auto_stop_test` | PASS |
| Combined dart tests this round | **140** PASS |
| `python -m unittest tools.perf.tests.test_harness` | PASS **55** |
| `flutter analyze` | 69 **info** (existing). No new error/warning from this change set. |
| GitHub status checks | **none** — not CI PASS |
| Mihomo pin | `ac017cdd` unchanged |

## 12. Acceptance

4D.1 complete after commit. **STOP.** Do not enter 4E. Human audit first.
