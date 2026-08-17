# Mihomo Compatibility Phase 2B: Single Snapshot + DNS/TUN Ownership

## Scope

Phase 2B makes three guarantees: (1) source and normalized config come from
one profile snapshot, (2) profile file updates never expose a partially
written state, and (3) DNS/TUN runtime patching follows an explicit Slclash
ownership contract instead of wholesale map replacement.

## Single Snapshot

Before Phase 2B the non-Script path read the profile file twice: Go read it
for `coreController.getConfig()` (MethodChannel round-trip) and Dart read it
again for the source overlay, so the overlay could mix `normalized(A)` with
`source(B)` if the file changed between the reads (TOCTOU).

Phase 2B reads the profile file exactly once:

```text
Profile path
↓
one snapshot (bytes)
↓
├─ parseMihomoSourceConfig(utf8(snapshot))     -> source map
└─ coreController.getConfigWithData(snapshot)  -> normalized map (same bytes)
↓
mergeSourceWithNormalized(source, normalized)
↓
ownership-aware runtime patch
↓
Runtime YAML
```

### Bridge

- `getConfig(path)` is preserved unchanged for existing callers.
- `getConfigWithData(bytes)` is new: Dart base64-encodes the snapshot, Go
  decodes it and runs `config.UnmarshalRawConfig` on the same bytes.
- Go exposes a single `normalizeRawConfig(bytes)` helper shared by both
  entry points, so the path-based and data-based APIs cannot diverge.
- Dart canonicalizes `rule -> rules` in one `_normalizeConfigResult` helper
  used by both `getConfig` and `getConfigWithData`.

### Fallback

If snapshot reading, source parsing, Core normalization, or overlay fails,
the whole preservation path is abandoned: `getConfig(profileId)` normalized
config is used alone and a warning is logged. A mixed snapshot (old source +
new normalized) is never produced.

## Atomic Profile Write

`Profile.saveFile` and `Profile.saveFileWithPath` both route through
`atomicReplaceProfileFile`: a unique staging file in the target directory is
written and flushed, Core-validated, then renamed over the target (atomic on
POSIX/Android). Failure at any step leaves the existing profile untouched,
never truncates it early, and removes the staging file. The global shared
temp path is no longer used as the replacement staging location.

## TUN Ownership

Slclash-owned (Slclash wins, matching the `Tun` model):

| Field | Owner |
|---|---|
| enable | Slclash |
| device | Slclash |
| dns-hijack | Slclash |
| stack | Slclash |
| route-address | Slclash |
| auto-route | Slclash |

Kernel/Profile-owned (preserved untouched): auto-detect-interface, mtu, gso,
gso-max-size, strict-route, route-exclude-address, include-interface,
exclude-interface, include-package, exclude-package,
endpoint-independent-nat, and any future Mihomo field.

`applyOwnedTunPatch` patches the tun map in place; the map is created when
missing and never wholesale-replaced.

## DNS Ownership

Slclash-owned (Slclash wins when the DNS override triggers, matching the
`Dns` model):

enable, listen, prefer-h3, use-hosts, use-system-hosts, respect-rules, ipv6,
default-nameserver, enhanced-mode, fake-ip-range, fake-ip-filter,
nameserver-policy, nameserver, fallback, proxy-server-nameserver,
fallback-filter.

Kernel/Profile-owned (preserved): cache-algorithm, cache-max-size, fake-ip-ttl,
fake-ip-range6, direct-nameserver, direct-nameserver-follow-policy,
proxy-server-nameserver-policy, fake-ip-filter-mode, and any future field.

Semantics:

- The trigger is unchanged: `overrideDns || !sourceDnsEnabled`.
- `nameserver-policy` is replaced as an atomic Slclash map (no entry-level
  source merge), keeping the `splitByMultipleSeparators` serialization.
- `fallback-filter` is patched by owned subfields only (geoip, geoip-code,
  geosite, ipcidr, domain); unknown siblings are preserved.
- `appendSystemDns` still runs after the ownership patch and never adds a
  duplicate `system://`.
- The old whole-map `rawConfig['dns'] = dns.toJson()` replacement is gone.

### Intentionally changed behavior

DNS override previously dropped unowned DNS fields (whole-map replacement).
Phase 2B preserves them. This is the only intentionally changed regression
baseline; it is covered by updated tests in
`runtime_config_regression_test.dart` and `source_config_preservation_test.dart`.

## Script

Unchanged. Script profiles keep `coreController.getConfig(profileId)` ->
`handleEvaluate` -> runtime patch, and never enter the source snapshot
overlay. Script source preservation stays out of scope (Phase 2C).

## Fail-safe

Snapshot preservation failure falls back to normalized-only config with a
warning log; no UI prompt is added and proxy setup is never blocked by the
snapshot path.

## Test Coverage

- `test/mihomo/source_config_preservation_test.dart`: snapshot identity,
  no stale-source overlay on Core failure, normalized-only fallback.
- `test/models/profile_atomic_write_test.dart`: atomic replacement, failure
  rollback, staging cleanup, missing-target behavior.
- `test/mihomo/runtime_config_ownership_test.dart`: TUN and DNS ownership
  contracts, synthetic sibling preservation, bundled-validity materialization.
- `core/hub_config_data_test.go`: data API and path API produce identical
  normalized JSON and share the bridge key contract.
- `core/configfixture/rawconfig_json_bridge_test.go`: unchanged Phase 2A.1
  contract (auto-detect-interface, experimental.*, rule -> rules).
- Bundled validity fixtures: `tun_ownership.yaml`, `dns_ownership.yaml`
  (real fields only; synthetic fixtures stay out of blocking validity).

## Known Limitations

- Source config that fails YAML parse falls back to normalized-only; the
  source-only fields of such a profile are lost (by design).
- YAML comments, aliases, formatting, and byte representation are still not
  preserved.
- The Phase 1 `MATCH,null,DIRECT` Rule serialization limitation is unchanged.
- The snapshot is read once per materialization; concurrent profile writes
  between separate materializations still follow last-writer-wins (now
  atomically).

## Phase 2C Candidates

- Script source preservation and script delete semantics.
- Broader config ownership beyond DNS/TUN (rules, providers, listeners).
- YAML formatting preservation.
