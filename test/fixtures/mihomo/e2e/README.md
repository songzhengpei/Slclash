# Reviewed RawConfig bridge baselines

`rawconfig.json` pins the 1.19.30 bridge. The versioned snapshots were generated
from the official 1.19.31, 1.19.32 and 1.19.33 commits, then compared with that baseline.

- 1.19.31 adds `tun.processors-per-channel: 1` in all three fixtures.
- 1.19.32 keeps that addition and changes the omitted-stack default in
  `bridge_contract` from `gVisor` to `Mips`.
- 1.19.33 adds `tun.dns-mode: ""` in all three fixtures. This is the only
  semantic difference from 1.19.32, reviewed against official commit
  `3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8`. `RawTun` now exposes the
  YAML/JSON key and passes it to the TUN listener. The empty value retains
  upstream's previous DNS behavior; Slclash does not override this field.
- No other bridge values change in these fixtures. Explicit `stack: mixed`
  remains mixed, and the app's selected/default stack still owns runtime YAML.

Go compares the full output against every reviewed snapshot; it does not ignore
new fields or regenerate expectations in CI. Dart runs the complete preservation
pipeline for each snapshot. Future unmatched output still blocks the updater.

To add a baseline after reviewing upstream changes, check out the exact official
release in an isolated validation checkout, then run from `core/`:

```sh
go mod tidy
go run ./configfixture/cmd/generate -baseline vX.Y.Z
```

Compare every generated JSON difference, include the version in the Dart E2E
baseline list, and rerun the Go and Dart suites. The generator refuses to label
snapshots with a tag that does not match the checked-out core commit.

For 1.19.33, additional coverage checks an explicitly configured `dns-mode`
across the Go JSON bridge and verifies that `native`, `hijack` and `disabled`
survive the Dart runtime overlay and parse successfully in the bundled core.
