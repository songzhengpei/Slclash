# Mihomo Compatibility Phase 2A: Source Preservation Overlay

## Scope

Phase 2A preserves source-only Mihomo YAML fields for non-Script profiles. It
does not replace Mihomo `RawConfig`, introduce a SourceConfig model hierarchy,
or change Slclash runtime ownership behavior.

## Pipeline

```text
                         +-> generic source YAML map --+
Profile YAML ------------|                              |
                         +-> Mihomo RawConfig ----------+-> recursive overlay
                              -> normalized Dart map         -> makeRealProfileTask
```

The source map is the preservation base. The existing normalized map remains
authoritative and recursively overlays it. The merged result is used only as
the input to the existing runtime materialization stage.

## Merge Boundary

- Map plus Map is recursively merged.
- A normalized key wins whenever it exists, including when its value is null.
- Scalars and lists are replaced as complete values by normalized data.
- A source-only key or list is retained.
- Both inputs are deep-copied into plain Dart Map/List/scalar structures.
- No field whitelist, schema registry, ownership engine, or list item merge is
  involved.

## Script Boundary

Script profiles bypass the source overlay. JavaScript continues to receive the
Mihomo-normalized config, its return value remains authoritative, and the
existing runtime patch still executes afterward. Source preservation for
Script is deferred to Phase 2C.

## DNS and TUN

An unknown DNS sibling reaches `makeRealProfileTask` through the overlay when
DNS override is off. The existing whole-map DNS replacement still removes it
when override is on; Phase 2A intentionally does not change that behavior.

An unknown TUN sibling reaches `makeRealProfileTask` and survives because the
current TUN logic patches selected members in place. No TUN ownership engine
was added.

## Fail-safe

Source loading, YAML parsing, root validation, or overlay failure is logged as
a warning and falls back to the already-successful normalized config. Source
preservation cannot by itself prevent proxy setup.

## Remaining Limitations

- `RawConfig` itself still drops fields it does not represent.
- YAML comments, aliases as identity, formatting, and byte representation are
  not preserved.
- Script source preservation and DNS/TUN ownership rules remain out of scope.
- Lists are atomic values during overlay.
- The Phase 1 `MATCH,null,DIRECT` Rule serialization limitation is unchanged.

## Phase 2A.1 Follow-up

### Synthetic vs bundled validity separation

Synthetic preservation fixtures (`synthetic_unknown_fields.yaml`) contain
made-up future fields and are validated only by the Dart overlay tests.
`TestBundledMihomoAcceptsCompatibilityFixtures` no longer includes
`source_preservation.yaml`, so our own fake fields can never block a Mihomo
core update if the parser becomes stricter. Overlay output that must survive
`config.Parse` uses `real_source_preservation.yaml`, which only contains real
fields the bundled core represents.

### JSON bridge key contract baseline

The Go bridge is `profile YAML -> RawConfig (yaml tags) -> json.Marshal
(json tags) -> Dart map`. `CoreController.getConfig()` canonicalizes only the
known `rule -> rules` mismatch (`yaml:"rules" json:"rule"` in RawConfig).

`TestRawConfigJSONBridgeContract` pins the contract: the pinned keys
`tun.auto-detect-interface`, `experimental.quic-go-disable-gso`,
`experimental.quic-go-disable-ecn`, and `experimental.dialer-ip4p-convert`
must arrive YAML-canonical, and a whole-tree invariant fails any non-lowercase
key. The current bundled core (post upstream #2939) passes all of these; the
test exists to fail a future core update that regresses the json tags before
the mismatch can reach the overlay.

### Snapshot consistency audit (TOCTOU)

`SetupAction.getProfile()` reads the profile file twice: Go reads it for
`coreController.getConfig()` (MethodChannel round-trip), then Dart reads it
again for the source overlay. Audit verdict:

- The window between the two reads is real: both are separated by
  event-loop-yielding awaits on the main isolate.
- A profile write can interleave: the 20-minute auto-update timer
  (`lib/application.dart:368`), UI profile sync, and
  `profile?.checkAndUpdateAndCopy()` inside `_setupConfig` all write
  `<profiles>/<id>.yaml`.
- No lock serializes subscription writes against `getProfile`. The Go
  `runLock` guards `applyConfig`/`updateConfig`, not `handleGetConfig`.
- The write itself is non-atomic (`tempFile.copy` in `lib/models/profile.dart:192`),
  so a read can even observe a partially replaced file.

The window is narrow (milliseconds to tens of milliseconds) and a mixed result
would be transient, but it is reachable. Phase 2A.1 intentionally does not
change this: the fix belongs to Phase 2B, where the ideal shape is a single
profile snapshot read once and handed to both the source parser and the
normalizer instead of two independent file reads.
