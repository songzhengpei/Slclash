# Phase 4C.1A — Mihomo Proxy Group Correctness

## 1. Baseline

base: `7a875fdd89e6a3be3047934e276567cc50630205`

pinned Mihomo: `ac017cdd246ce8bd547653d927e7bf77d7ee73d5` (`v1.19.30`)

submodule SHA before/after this change: **unchanged**

## 2. Corrected Contract

| Group | manual select | fixed | unfix | now | UI |
|---|---|---|---|---|---|
| Selector | PUT member | none (`null`) | rejected | current member | selected row = selectedMap / now |
| URLTest | PUT pin | `""` auto / name pin | DELETE-equivalent `unfixProxy` | algorithm or pin | row = Core `now`; pin mark = Core `fixed` |
| Fallback | PUT pin | same | same | first alive or pin | same |
| LoadBalance | no | none (`null`) | rejected | always `""` | no fake current member; delay still works |
| Relay | no | none | no | n/a | Dart leftover only; Core rejects config |

`isComputedSelected` still means auto groups (URLTest/Fallback/LoadBalance). PUT/unfix use `supportsManualSelection` / `supportsFixedSelection`.

## 3. LoadBalance

Pinned Core is not SelectAble. ProxyCard tap does not write `selectedMap`, does not `changeProxy`/`unfixProxy`, does not close/reset/checkIp. `selectedProxyName` does not invent a current node from local maps.

## 4. URLTest

- `now`: current used member
- `fixed`: `""` automatic; name = manual pin
- pin: `changeProxy` PUT (not empty)
- unfix: `unfixProxy` → ForceSet("") + cachefile.SetSelected("", "") when type ≠ Selector and SelectAble
- tap current automatic `now` while `fixed==""` is **pin**, not unfix
- tap `fixed==name` is **unfix**, not PUT `""`

## 5. Fallback

Same as URLTest.

## 6. Core Truth

Optimistic `selectedMap` updates on tap (600ms debounce unchanged). After groups refresh, URLTest/Fallback pin chrome uses Core `Group.fixed`. `computedSelectedMap` remains UI `now` placeholder cache only; not written from/to `fixed`.

## 7. Failure Semantics

Non-empty Core result:

- no `closeConnections`
- no `resetConnections`
- no `checkIpNum`
- rollback optimistic `selectedMap` only if it still equals the failed intent
- `updateGroupsDebounce` + notifier

IPC `null` coalesced to `''` still looks like success. **Deferred to 4D.**

## 8. Persistence

Successful pin: `selectedMap[group]=node` (SetupParams restore ForceSet).

Successful unfix: keep `selectedMap[group]=""` so reapply `ForceSet("")` and do not re-pin from a missing key. Go also clears Mihomo cachefile selected.

Empty PUT is rejected (`empty proxy name not allowed`).

## 9. Regression

- `flutter analyze` on touched Dart: no issues
- `test/common/proxy_group_selection_test.dart`
- `test/models/group_fixed_json_test.dart`
- `test/common/compute_test.dart` (LoadBalance now)
- `test/core/controller_test.dart` (`unfixProxy`)
- `test/common/proxy_trace_test.dart`
- Phase 1–3 `test/mihomo` + `test/providers/smart_auto_stop_test.dart`
- `go test` `TestApplyUnfix*` in `core/`
- `python -m unittest tools/perf/tests/test_harness.py`

Device Proxy smoke: **not run** (no throwaway profile on the phone this round).

RUNNING smoke: **deferred to 4C.1B** (profile package still not VPN RUNNING; not faked).

## 10. Deferred

- IPC null vs empty success → Phase 4D
- delay concurrency → 4C.1C
- eager proxy list → 4C.1C
- header rebuild → 4C.1C
- selection trace generation / 300/500 / RUNNING perf → 4C.1B
- Relay enum leftover (explicitly not cleaned)

## 11. 4C.1A.1 Selection Transaction Cleanup

Follow-up on `0a428528` (not a revert):

- Optimistic rollback uses per-group `ProxySelectionSession` baseline captured **before** `selectedMap` write, so Core error restores A not B.
- Same-group A→B→C debounce burst keeps baseline A.
- `_groupsEqual` / `groupsListsEqual` includes `fixed`.
- Dashboard picker uses `applyProxyGroupMemberTap` (same pin/unfix/LoadBalance ignore).
- Debounce tag is `(FunctionTag.changeProxy, groupName)`; duration still 600ms.
- In-flight Core success with a newer optimistic intent advances the session baseline to the committed value instead of `complete()` (`73cc5e09` follow-up).

Device / RUNNING still deferred to 4C.1B.
