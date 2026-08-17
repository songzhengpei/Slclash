# Mihomo Compatibility Phase 1 Report

## 1. Current Config Pipeline

```text
Profile YAML
  -> core.handleGetConfig(path)
  -> Mihomo config.UnmarshalRawConfig(bytes)
  -> typed config.RawConfig
  -> Go JSON result
  -> CoreController.getConfig(): Map<String, dynamic>
     (renames `rule` to `rules`)
  -> SetupAction.getProfile()
  -> optional JavaScript `main(normalizedConfig)`
  -> makeRealProfileTask()
  -> runtime-owned/user-setting patches and YAML encoding
  -> config.yaml
  -> core setup / Mihomo parse and apply
```

The first structural conversion is `config.UnmarshalRawConfig` in
`core/hub.go`. The value returned to Dart is not the original YAML map. It is
Mihomo's typed, default-populated `RawConfig`, serialized through the Go bridge.

## 2. Slclash-Owned Fields

`makeRealProfileTask` always writes the following runtime fields:

- `external-controller`, `external-ui`, `external-ui-url`, `interface-name`
- `port`, `socks-port`, `mixed-port`, `redir-port`, `tproxy-port`
- `tcp-concurrent`, `unified-delay`, `keep-alive-interval`
- `find-process-mode`, `allow-lan`, `mode`, `log-level`, `ipv6`
- selected TUN members: `enable`, `device`, `dns-hijack`, `stack`,
  `route-address`, `auto-route`
- `geodata-loader`, `geox-url`, `global-ua`
- `profile.store-selected` (forced to `false`)
- configured host entries, DNS according to the behavior below, provider
  runtime paths, `rules`, and optionally `proxy-groups`

Listener ports and the external controller are runtime owned. Mode,
allow-LAN, logging, IPv6, TUN, DNS override, UA, GeoX URLs, and configured hosts
are user-setting controlled. Proxy definitions, provider definitions, ordinary
Mihomo fields, and parsing/default semantics are Mihomo/kernel owned unless a
specific patch above applies.

## 3. Normalized Config Behavior

Mihomo `RawConfig` is the boundary between source YAML and Dart. It supplies
Mihomo defaults, converts known fields to typed structures, represents source
`rules` as JSON key `rule`, and omits YAML keys that are not represented by the
current `RawConfig` types. `CoreController.getConfig` changes `rule` back to
`rules`; it does not reconstruct the source YAML.

Consequently, preservation tests that begin at `makeRealProfileTask` prove the
Dart patch behavior only. Preservation across the complete source-to-runtime
chain is constrained by `RawConfig` before Dart runs.

## 4. DNS Findings

- If source DNS is enabled and DNS override is off, the normalized DNS map is
  retained; `appendSystemDns` may append `system://`.
- If DNS override is on, the entire DNS map is replaced with
  `PatchClashConfig.dns.toJson()`, then `nameserver-policy` is rebuilt into
  list values.
- If source DNS is disabled (or absent after normalization), the same whole-map
  replacement occurs and `system://` is appended to the configured nameservers.
- Unknown DNS siblings can be lost at `RawDNS` unmarshalling. They also disappear
  during the whole-map override path, even if they somehow reach Dart.

## 5. TUN Findings

The Dart stage patches six members in the existing `tun` map rather than
replacing it. Siblings that reach Dart are retained. Unknown siblings do not
survive the earlier typed Mihomo `RawTun` conversion, so end-to-end forward
compatibility is not guaranteed.

## 6. Provider Findings

`proxy-providers` and `rule-providers` are `map[string]map[string]any` in
Mihomo `RawConfig`. Their arbitrary sibling fields survive normalization and
the Dart stage. For HTTP providers with a URL, Slclash replaces `path` with a
profile-scoped runtime cache path. Non-HTTP provider paths are not rewritten.

## 7. Script Findings

The script input is the Mihomo-normalized Dart map, not the original YAML.
`handleEvaluate` ensures `proxy-providers` exists, serializes the map to JSON,
and calls JavaScript `main(config)`. The returned map replaces the previous map
in full. A script can therefore change scalars, maps, and lists; add fields;
delete fields; or return a structure that omits unrelated data.

After the script returns, `makeRealProfileTask` performs every runtime patch.
Runtime-owned settings therefore win over conflicting script values. Host and
other fields deleted by the script may be recreated where the runtime patch
requires a map. Host-side execution of `flutter_js` is recorded as a
non-blocking skipped audit because its native QuickJS library is not available
in the Flutter test runner; the post-script/runtime ordering is covered by a
blocking regression test.

## 8. Rules / Proxy Groups Findings

- No overwrite rule list: source rules are kept; Standard `addedRules` are
  prepended.
- A Standard added-rule target of `MATCH` is replaced with the last source
  `MATCH` target.
- A non-empty overwrite rule list replaces all source rules and added rules.
- A non-empty overwrite proxy-group list replaces `proxy-groups` as a whole.
  An empty list leaves source groups unchanged.
- Script runs before these runtime rule/group patches. Script mode supplies no
  Standard or custom overwrite lists, so the script-produced rules/groups flow
  into the runtime stage and are otherwise retained.

## 9. Known Compatibility Limitations

### Unknown top-level fields are lost

- Input: `x-slclash-test-field` in `synthetic_unknown_fields.yaml`.
- Current behavior: absent after Mihomo `RawConfig` unmarshalling/JSON output.
- Risk: a future Mihomo top-level option may silently disappear before setup.
- Test: skipped synthetic preservation audit with an explicit limitation reason.
- Phase 2: yes; evaluate a source-preserving representation without changing
  runtime ownership semantics.

### Unknown DNS and TUN siblings are lost

- Input: `future-dns-option` and `future-option` in the synthetic fixture.
- Current behavior: typed `RawDNS`/`RawTun` omit them; DNS override also rebuilds
  DNS as a whole.
- Risk: newly introduced nested Mihomo options can be silently reset.
- Test: skipped synthetic preservation audit; Dart-level tests separately prove
  the current DNS replacement and TUN patch behavior.
- Phase 2: yes, with DNS ownership handled separately from TUN.

### Script can discard unrelated fields

- Input: a script returning a map with members deleted or omitted.
- Current behavior: the returned map becomes the complete input to runtime patching.
- Risk: normalized fields not recreated by Slclash disappear.
- Test: post-script result/runtime ordering regression; native evaluation audit is
  explicitly skipped on the host runner.
- Phase 2: consider better diagnostics first; do not change the Script API casually.

### MATCH Rule model serialization includes a null content slot

- Input: a `Rule` whose action is `MATCH` and target is `DIRECT`.
- Current behavior: `Rule.rawValue` produces `MATCH,null,DIRECT`.
- Risk: custom/Standard MATCH rules produced from the Dart model may be rejected
  or interpreted differently by Mihomo.
- Test: `prepends standard added rules using current MATCH serialization` and
  `replaces rules when overwrite rules are supplied` lock the current fact.
- Phase 2: yes; fix with a focused model change and migration-free regression.

## 10. Phase 2 Candidates

1. Preserve source keys across the RawConfig boundary while keeping a separate
   normalized view for Mihomo-derived defaults.
2. Define narrow ownership-aware DNS behavior before changing DNS merge rules.
3. Preserve future TUN fields without introducing a generic deep-merge engine.
4. Add Script result diagnostics and device/integration execution coverage.
5. Correct MATCH rule serialization with focused validity tests.
6. Add an end-to-end device test that materializes runtime YAML and calls the
   bundled core validator in one process.

Phase 1 intentionally implements none of these architecture or behavior changes.
