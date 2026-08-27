# Mihomo Compatibility — Phase 2CD

Script Source Preservation + Full End-to-End Compatibility Closure

## Scope

Phase 2CD merges the former Phase 2C (Script source preservation) and
Phase 2D (source → RawConfig → JSON bridge → Dart → runtime → bundled Mihomo
E2E) into one branch with two strictly separated gates:

- **Gate C** changes runtime semantics: Script profiles no longer lose
  source-only fields.
- **Gate D** only adds test infrastructure, fixtures, CI gates, and docs.

## Final compatibility pipeline

Normal profile:

```
ONE SOURCE SNAPSHOT
    ↓
source generic parse + Mihomo normalization (same bytes)
    ↓
source preservation overlay
    ↓
DNS/TUN ownership
    ↓
runtime config → Mihomo
```

Script profile:

```
ONE SOURCE SNAPSHOT
    ↓
source map            normalizedBefore
    ↓                        ↓
                        existing Script (deep copy input)
                            ↓
                        normalizedAfter
                            ↓
            structural diff(before, after)
                            ↓
source + normalizedBefore preservation base
                            ↓
              apply structural diff
                            ↓
                   DNS/TUN ownership
                            ↓
                      runtime config → Mihomo
```

Guarantees (unchanged from Phase 2B and now also for Script):

1. Script input is still the Core-normalized map (observable contract
   unchanged); the raw source and preserved maps are never handed to Script.
2. Source-only Mihomo fields survive Script transforms.
3. Script edits to visible fields keep winning.
4. Slclash DNS/TUN runtime ownership still wins last.
5. Source and normalized always come from the same snapshot.
6. Preservation failures fall back to the old normalized-only Script path.

## Gate C — Script source preservation

### Snapshot parts

`lib/services/mihomo_config/source_config.dart` now exposes

```dart
typedef MihomoSnapshotParts = ({
  MihomoConfigMap source,
  MihomoConfigMap normalized,
});

Future<MihomoSnapshotParts> loadMihomoSnapshotParts({...});
```

`resolveSnapshotRuntimeBase` (non-Script) and
`resolveScriptSnapshotRuntimeBase` (Script) both reuse this single helper, so
there is exactly one snapshot-read / source-parse / normalize path. No
`getConfigWithData`, no base64 Binder transport, no second profile read was
reintroduced; the unique snapshot file path from Phase 2B is shared.

### Structural diff

`lib/services/mihomo_config/structural_config_diff.dart` is a dependency-free
module:

- `diffStructuralChanges(before, after)` — plain Dart structures only
  (`Map<String,dynamic>` / `List` / `String` / `num` / `bool` / `null`).
- `applyStructuralChanges(base, changes)` — deep-copies the base, applies
  changes without mutating inputs.

Rules:

| Case | Result |
|---|---|
| Map ↔ Map | recurse per key; added → SET, removed → REMOVE |
| List unequal (deep) | whole-list SET (no item merge) |
| scalar unequal | SET after value |
| type changed (Map↔List↔scalar) | whole-value SET |
| `after` key exists with null | SET null (NOT REMOVE) |

No JSON Patch library, schema engine, ownership registry, reflection
framework, or AST was introduced.

### Script deletion semantics

- `delete config.dns.nameserver` (known nested field) → REMOVE
  `dns.nameserver`; source-only sibling `dns.future-field` survives.
- `delete config.dns` (whole visible object) → REMOVE `dns`; the entire
  subtree, including source-only descendants, is removed.

### Documented Script limitation

These two Scripts are observably identical to the structural diff:

```js
config.dns = { enable: true }
```

```js
delete config.dns.nameserver
delete config.dns.fallback
config.dns.enable = true
```

Both produce the same `normalizedAfter`, and the diff cannot distinguish an
imperative delete sequence from a whole-map replacement. Consequence:

- If `dns` still exists as a Map in `after`, source-only unknown siblings
  under `dns` are **preserved by default**.
- Only `delete config.dns`, or replacing `dns` with a scalar/list/null, is
  treated as a whole-subtree replacement/removal.

This is intentionally NOT solved with Proxy instrumentation or JS AST
tracing.

### Exactly-once Script evaluation

`resolveScriptSnapshotRuntimeBase`:

1. `before = deepCopy(normalized)` (the diff base).
2. `scriptInput = deepCopy(before)` — the Script sees its own copy; even an
   in-place-mutating evaluator cannot corrupt the diff base.
3. `after = await evaluateScript(scriptInput)`.
4. `diff(before, after)` → `applyStructuralChanges(mergeSourceWithNormalized(source, normalized), changes)`.

Failure classes:

- **Preservation infrastructure** (snapshot read, source parse, Core
  normalization): abandon preservation, run the existing
  `coreController.getConfig → Script → makeRealProfileTask` path. No stale
  source mixed with new normalized.
- **Script error**: propagates unchanged; never swallowed into a
  normalized-only fallback.
- **Post-Script apply failure** (merge/diff/apply): reuse the first
  `after` with a warning log; the Script is **never re-run** (it may be
  non-deterministic — `Date.now`, `random`).

### Empty Script

An empty `scriptContent` still takes the Script path with preservation:
`after == before`, the diff is empty, and source-only fields survive. This
closes the Phase 2B gap where an empty Script dropped source-only fields.

### Ownership order

`source/normalized → Script changes → makeRealProfileTask → Slclash DNS/TUN
ownership → runtime YAML`. A Script setting `config.tun.enable = false`
still loses to Slclash's runtime TUN ownership.

## Gate D — End-to-end compatibility suite

### Fixture architecture

`test/fixtures/mihomo/e2e/`:

```
standard_real_fields/  source.yaml + rawconfig.json
script_real_fields/    source.yaml + rawconfig.json
bridge_contract/       source.yaml + rawconfig.json
```

`source.yaml` is a real profile using only fields the current bundled Mihomo
supports. `rawconfig.json` is the real Go JSON bridge output:

```
config.UnmarshalRawConfig(source.yaml) → json.Marshal(RawConfig)
```

### First boundary: Go contract test

`core/configfixture/rawconfig_e2e_fixture_test.go` re-derives the bridge
output from each `source.yaml` and compares it semantically (generic decoded
maps, not bytes) against the checked-in `rawconfig.json`. A future Mihomo
bump that changes a RawConfig tag, default, field shape, or JSON bridge
output fails this test immediately.

### Dart pipeline

`test/mihomo/e2e_compatibility_test.dart`:

1. Parse `source.yaml` → generic source map.
2. Load `rawconfig.json` → simulate the exact Go bridge map.
3. Apply the established canonicalization only: `rule` → `rules`
   (the `rawconfig_json_bridge_test.go` contract is preserved and still
   blocking).
4. `mergeSourceWithNormalized`.
5. Standard case → `makeRealProfileTask` → runtime YAML written to
   `build/mihomo-runtime-fixtures/e2e_standard.yaml`.
6. Script case → `diff(before, after)` → source-preserved base → apply →
   `makeRealProfileTask` → `build/mihomo-runtime-fixtures/e2e_script.yaml`.

### Bundled Mihomo final parse

`core/configfixture/mihomo_config_fixture_test.go` now includes
`e2e_standard.yaml` and `e2e_script.yaml` in the blocking `config.Parse`
validity list — both outputs are real-field only.

### Synthetic separation (unchanged Phase 2A.1 principle)

A synthetic preservation case (`x-slclash-future-field` etc.) proves
RawConfig drops the key and source preservation restores it, but the
materialized synthetic output is **not** added to the blocking
`config.Parse` list.

### E2E covered real fields

- Top-level: `mode`, `ipv6`, `global-ua`, `profile`.
- DNS: `enable`, `nameserver`, `cache-algorithm`, `direct-nameserver`,
  `direct-nameserver-follow-policy`.
- TUN: `enable`, `stack`, `auto-route`, `auto-detect-interface`, `mtu`,
  `strict-route`.
- Experimental: `quic-go-disable-gso`, `quic-go-disable-ecn`,
  `dialer-ip4p-convert`.
- Rules, proxy-groups.

E2E verifies semantic preservation, not byte-perfect YAML: comments,
anchors, formatting, key order, and quoting are out of scope. Lists are
still atomic (no item-level merge).

### Known limitations (kept)

- Source list item unknown-field merge is not solved.
- `MATCH,null,DIRECT` did not surface naturally in the E2E fixtures; the
  known limitation is retained for a later cleanup.
- Script imperative operations are indistinguishable structurally (see the
  documented limitation above).

## CI integration

Both `slclash-android-beta.yml` and `mihomo-core-update.yml` run:

```
structural_config_diff_test.dart
script_source_preservation_test.dart
e2e_compatibility_test.dart
```

in addition to the existing regression/ownership/atomic-write/controller
tests and `go test ./configfixture`. The Go E2E contract test makes a core
update fail when the first boundary (source → RawConfig → JSON) changes.

## Explicitly not changed

Mihomo Core upgrade, DNS/TUN UI, new config schema engine, generic ownership
framework, Proxy-based JS tracing, JS AST instrumentation, YAML
comment/anchor preservation, list item merge, VPN architecture, Android
service lifecycle, provider UI redesign, performance work, database
migration, dependency upgrade, FlClash feature sync, release workflow
redesign.
