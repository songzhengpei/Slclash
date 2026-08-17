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
