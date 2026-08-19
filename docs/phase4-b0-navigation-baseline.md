# Phase 4B.0 navigation baseline

> Navigation/Page Mount FrameTiming only. Idle gfxinfo is not this baseline.

- captured_at: `2026-08-19T08:47:20Z`
- harness_commit: `ae8e6811b56e71f4836ca60929bdc6e816ce664c`
- product_baseline_sha: `b7e08b6ef84546e9b3d084a411c3a59e3e4df7c8`
- 4B navigation BEFORE sha: `ae8e6811b56e71f4836ca60929bdc6e816ce664c`
- device: `25042PN24C`
- android: `16` (sdk `36`)
- build: `com.slclash.app.profile` 9.9.10 (code 1)
- build_mode: `profile`
- build_role: `profiling`
- formal_eligible: `True`
- dumpsys refresh_hz: `120.00001` budget_ms=`8.333332638888946`
- dart refresh_hz: `120.0` budget_ms=`8.333`
- pages: `['dashboard', 'proxies', 'profiles', 'tools']`
- ok: `True`

## A. Dashboard ↔ Proxy

- pair: `['dashboard', 'proxies']` round_trips=`10`
- total_ms: median=`313.5` p90=`324.3` p99=`330.24` min=`302.0` max=`331.0` (n=`20` ms)
- to_proxy total_ms: median=`314.5` p90=`321.29999999999995` p99=`323.72999999999996` min=`302.0` max=`324.0` (n=`10` ms)
- to_dashboard total_ms: median=`312.5` p90=`327.4` p99=`330.64` min=`302.0` max=`331.0` (n=`10` ms)
- first_build_ms: median=`23.5` p90=`30.0` p99=`30.0` min=`18.0` max=`30.0` (n=`10` ms)
- worst_frame_ms: median=`13.131499999999999` p90=`23.8971` p99=`26.885909999999996` min=`10.185` max=`27.572` (n=`20` ms)
- over_budget frames: median=`7.0` p90=`9.0` p99=`9.0` min=`3.0` max=`9.0` (n=`20` frames)
- scroll_to_top us: median=`590.0` p90=`721.0000000000001` p99=`812.8` min=`387.0` max=`828.0` (n=`20` us)
- scroll elements: median=`1935.0` p90=`1935.0` p99=`1935.0` min=`1935.0` max=`1935.0` (n=`20` elements)

## B. Bottom navigation round-robin

- pages: `['dashboard', 'proxies', 'profiles', 'tools']` cycles=`10`
- total_ms: median=`307.5` p90=`325.8` p99=`337.0` min=`296.0` max=`337.0` (n=`40` ms)
- worst_frame_ms: median=`13.58` p90=`24.026700000000005` p99=`26.070690000000003` min=`9.765` max=`26.199` (n=`40` ms)
- over_budget frames: median=`7.0` p90=`10.0` p99=`12.0` min=`1.0` max=`12.0` (n=`40` frames)

## C. First mount vs revisit

- first total_ms: median=`303.0` p90=`305.4` p99=`305.94` min=`293.0` max=`306.0` (n=`4` ms)
- revisit total_ms: median=`314.5` p90=`334.8` p99=`337.0` min=`301.0` max=`337.0` (n=`22` ms)
- first first_build_ms: median=`23.5` p90=`25.0` p99=`25.0` min=`17.0` max=`25.0` (n=`4` ms)
- revisit first_build_ms: median=`56.0` p90=`99.0` p99=`99.78999999999999` min=`18.0` max=`100.0` (n=`22` ms)

## D. Same-tab reselect / scroll-to-top

- page: `proxies`
- total_ms: median=`50.0` p90=`50.0` p99=`50.0` min=`50.0` max=`50.0` (n=`1` ms)
- scroll_us: median=`517.0` p90=`517.0` p99=`517.0` min=`517.0` max=`517.0` (n=`1` us)
- note: Measures current scroll-to-top behavior; UX was not changed.

## E. Page root mount / build counts

- mounts: `dashboard:24,profiles:1,proxies:1,tools:1`
- builds: `dashboard:26,profiles:1,proxies:1,tools:1`

## Measured ranking (do not start 4B.1 here)

- Tab `total_ms` is dominated by `SurgeMotion.pageEnter` (280ms). That duration is a product choice (P4), not a traversal bug.
- Dashboard `keep:false` remounts on every return (workload E). Keep-alive tabs mount once. This is the largest extra CPU/jank source that is not the 280ms animation floor. Changing keep-alive is also P7.
- `visitChildElements` scroll-to-top is **not** the hotspot: ~0.4–0.8ms for ~1000–2000 elements and 1 `ScrollPosition`. Do not replace it in 4B.1 without a new regression.
- Over-budget frames (budget = 1000/refreshHz, here ~8.33ms at 120Hz) happen *during* the PageView animation. Worst frames ~12–24ms.

## Top transitions

- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`337` first_build_ms=`99` worst_frame_ms=`25.87` over_budget=`7` scroll_us=`534` elements=`948`
- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`337` first_build_ms=`100` worst_frame_ms=`26.199` over_budget=`10` scroll_us=`645` elements=`948`
- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`335` first_build_ms=`96` worst_frame_ms=`21.377` over_budget=`9` scroll_us=`559` elements=`948`
- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`333` first_build_ms=`99` worst_frame_ms=`25.437` over_budget=`5` scroll_us=`565` elements=`948`
- proxies→dashboard visit=`revisit` keep_alive=`False` total_ms=`331` first_build_ms=`26` worst_frame_ms=`15.404` over_budget=`7` scroll_us=`553` elements=`1935`
- proxies→dashboard visit=`revisit` keep_alive=`False` total_ms=`327` first_build_ms=`23` worst_frame_ms=`27.572` over_budget=`6` scroll_us=`590` elements=`1935`
- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`325` first_build_ms=`87` worst_frame_ms=`14.281` over_budget=`6` scroll_us=`443` elements=`948`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`324` first_build_ms=`None` worst_frame_ms=`10.843` over_budget=`7` scroll_us=`708` elements=`1935`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`323` first_build_ms=`None` worst_frame_ms=`16.006` over_budget=`12` scroll_us=`644` elements=`1935`
- proxies→profiles visit=`unknown` keep_alive=`False` total_ms=`323` first_build_ms=`None` worst_frame_ms=`17.71` over_budget=`6` scroll_us=`1003` elements=`1935`
- proxies→dashboard visit=`revisit` keep_alive=`False` total_ms=`322` first_build_ms=`18` worst_frame_ms=`12.328` over_budget=`8` scroll_us=`572` elements=`1935`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`322` first_build_ms=`None` worst_frame_ms=`14.555` over_budget=`11` scroll_us=`717` elements=`1935`

## Unreliable

- (none)
