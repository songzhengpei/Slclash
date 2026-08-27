# Phase 4A.0 baseline

> Aggregated harness metrics only. Raw capture artifacts live under `.perf-captures/` (gitignored).

- captured_at: `2026-08-19T04:08:59Z`
- harness_commit: `c1ac73d9d17e9e61da95d5bef1699fd9a34df8c1`
- product_baseline_sha: `b7e08b6ef84546e9b3d084a411c3a59e3e4df7c8`
- device: `25042PN24C`
- android: `16` (sdk `36`)
- build: `com.slclash.app` 9.9.10 (code 1)
- build_mode: `profile`
- build_role: `profiling` (debug=diagnostic_only, profile=profiling, release=production)
- formal_eligible: `True`
- note: Formal **profiling** baseline from profile APK with StartupTrace enabled.
  Not a debug/diagnostic run. VPN ready stayed `null` (no confirmed VpnService+tunN);
  stop cleared successfully. Idle jank only.

## Cold start

- TotalTime median/p90/min/max ms: `414.0` / `428.7` / `396.0` / `444.0` (n=`10`)
- first_frame median/p90 ms: `105.0` / `113.2`
- main_ready median/p90 ms: `371.5` / `394.6`
- core_ready median/p90 ms: `None` / `None`
- core outcomes: `{'core_ready': 0, 'core_skipped': 10, 'core_connect_failed': 0, 'core_init_failed': 0}`

## Memory (PSS kb)

- app: `343977`
- core/remote: `45627`
- combined: `389604`

## Jank (idle)

- frames: `0`
- janky: `0` (0.0%)
- p90 frame ms: `4950`

## VPN

- start_observable_ms: `3359`
- vpn_ready: `None`
- start_to_ready_ms: `None`
- stop_success: `True`
- stop_to_cleared_ms: `344`

## Background

- vpn_active: `False`
- vpn_inactive: `False`

## Unreliable

- jank: idle_only_no_ui_automation
- vpn: vpn_consent_cannot_be_granted_over_adb
- vpn: network_probe_is_not_tunnel_attribution
- vpn: vpn_ready_unconfirmed_partial_signals_only
- background: cpu_from_dumpsys_cpuinfo_is_coarse
- background: no_battery_mah
- background: ui_timer_not_directly_observable
- background: background_vpn_state_unconfirmed
