# Phase 4B.0.1 navigation baseline (formal 4B.1 BEFORE)

> Navigation/Page Mount FrameTiming only. Idle gfxinfo is not this baseline.
>
> `target_first_build_latency_ms` is elapsed time from `nav_begin` until the target page-root `build()` is **called**. It is not the CPU duration of that build.

- captured_at: `2026-08-19T09:24:39Z`
- git_head: `9518d40d9e93e194ff286fabfa862115dcca03e1`
- dirty: `False`
- submodule_dirty: `True`
- worktree_fingerprint: `707cacb3ce76e2a7`
- harness_commit: `9518d40d9e93e194ff286fabfa862115dcca03e1`
- product_baseline_sha: `b7e08b6ef84546e9b3d084a411c3a59e3e4df7c8`
- formal: `True`
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

## Semantics

- `total_ms`: nav_begin → nav_complete (tab switch includes `pageEnter` 280ms).
- `target_first_build_latency_ms`: wait until target root `build()` is invoked. Do not treat 87–100ms as Dashboard CPU.
- `build_*` / `raster_*` / `total_span_*`: Flutter FrameTiming percentiles for frames during the active transition.
- D `scroll_command_ms`: DFS + `animateTo` issued. `scroll_animation_complete_ms`: awaited `animateTo` Future. Product UX is still fire-and-forget.

## A. Dashboard ↔ Proxy

- pair: `['dashboard', 'proxies']` round_trips=`10`
- total_ms: median=`307.5` p90=`318.2` p99=`324.05` min=`298.0` max=`325.0` (n=`20` ms)
- target_first_build_latency_ms: median=`23.5` p90=`32.0` p99=`32.0` min=`18.0` max=`32.0` (n=`10` ms)
- worst_frame_ms: median=`14.78` p90=`23.8755` p99=`24.500639999999997` min=`10.043` max=`24.547` (n=`20` ms)
- over_budget frames: median=`5.5` p90=`9.100000000000001` p99=`10.0` min=`3.0` max=`10.0` (n=`20` frames)
- scroll_to_top us: median=`610.5` p90=`746.1` p99=`809.6399999999999` min=`411.0` max=`818.0` (n=`20` us)
- scroll elements: median=`1935.0` p90=`1935.0` p99=`1935.0` min=`1935.0` max=`1935.0` (n=`20` elements)

## FrameTiming slices

### Dashboard → Proxy

- n=`10`
- transition total_ms: median=`304.5` p90=`318.2` p99=`319.82` min=`298.0` max=`320.0` (n=`10` ms)
- target_first_build_latency_ms (**not** build CPU): median=`None` p90=`None` p99=`None` min=`None` max=`None` (n=`0` ms)
- frame build p50/p90/p99 (median across transitions): `2.215` / `3.7264999999999997` / `3.993`
- frame raster p50/p90/p99: `3.7445` / `4.6915` / `5.0305`
- frame totalSpan p50/p90/p99: `7.7044999999999995` / `10.1955` / `11.591000000000001`
- worst_frame_ms: median=`11.819500000000001` p90=`15.7715` p99=`20.757050000000003` min=`10.043` max=`21.311` (n=`10` ms)
- over-budget frames: median=`7.5` p90=`10.0` p99=`10.0` min=`5.0` max=`10.0` (n=`10` frames)
- frame_count: median=`20.5` p90=`21.0` p99=`21.0` min=`14.0` max=`21.0` (n=`10` frames)

### Proxy → Dashboard

- n=`10`
- transition total_ms: median=`309.0` p90=`318.7` p99=`324.37` min=`303.0` max=`325.0` (n=`10` ms)
- target_first_build_latency_ms (**not** build CPU): median=`23.5` p90=`32.0` p99=`32.0` min=`18.0` max=`32.0` (n=`10` ms)
- frame build p50/p90/p99 (median across transitions): `2.0715000000000003` / `3.957` / `10.8195`
- frame raster p50/p90/p99: `3.5469999999999997` / `5.506` / `7.2225`
- frame totalSpan p50/p90/p99: `7.458` / `11.3315` / `18.8185`
- worst_frame_ms: median=`19.553` p90=`24.3274` p99=`24.52504` min=`11.132` max=`24.547` (n=`10` ms)
- over-budget frames: median=`4.5` p90=`7.0` p99=`7.0` min=`3.0` max=`7.0` (n=`10` frames)
- frame_count: median=`13.0` p90=`14.0` p99=`14.0` min=`13.0` max=`14.0` (n=`10` frames)

### Tools → Dashboard

- n=`10`
- transition total_ms: median=`312.5` p90=`329.20000000000005` p99=`330.82` min=`306.0` max=`331.0` (n=`10` ms)
- target_first_build_latency_ms (**not** build CPU): median=`91.0` p90=`96.1` p99=`96.91` min=`85.0` max=`97.0` (n=`10` ms)
- frame build p50/p90/p99 (median across transitions): `2.6985` / `6.699999999999999` / `10.549`
- frame raster p50/p90/p99: `3.911` / `6.2715` / `7.586`
- frame totalSpan p50/p90/p99: `8.525500000000001` / `14.463999999999999` / `18.9185`
- worst_frame_ms: median=`19.408` p90=`23.508599999999998` p99=`25.14156` min=`14.821` max=`25.323` (n=`10` ms)
- over-budget frames: median=`7.0` p90=`8.1` p99=`8.91` min=`4.0` max=`9.0` (n=`10` frames)
- frame_count: median=`13.0` p90=`14.0` p99=`14.0` min=`12.0` max=`14.0` (n=`10` frames)

### Round-robin

- n=`40`
- transition total_ms: median=`309.0` p90=`324.40000000000003` p99=`336.49` min=`295.0` max=`340.0` (n=`40` ms)
- target_first_build_latency_ms (**not** build CPU): median=`91.0` p90=`96.1` p99=`96.91` min=`85.0` max=`97.0` (n=`10` ms)
- frame build p50/p90/p99 (median across transitions): `1.495` / `3.201` / `4.173`
- frame raster p50/p90/p99: `3.7925` / `6.273999999999999` / `7.743`
- frame totalSpan p50/p90/p99: `7.7405` / `11.924` / `14.630500000000001`
- worst_frame_ms: median=`15.0955` p90=`22.4043` p99=`26.344749999999998` min=`10.787` max=`26.998` (n=`40` ms)
- over-budget frames: median=`6.0` p90=`10.0` p99=`11.61` min=`3.0` max=`12.0` (n=`40` frames)
- frame_count: median=`14.0` p90=`21.0` p99=`21.0` min=`12.0` max=`21.0` (n=`40` frames)

## B. Bottom navigation round-robin

- pages: `['dashboard', 'proxies', 'profiles', 'tools']` cycles=`10`
- total_ms: median=`309.0` p90=`324.40000000000003` p99=`336.49` min=`295.0` max=`340.0` (n=`40` ms)
- worst_frame_ms: median=`15.0955` p90=`22.4043` p99=`26.344749999999998` min=`10.787` max=`26.998` (n=`40` ms)
- over_budget frames: median=`6.0` p90=`10.0` p99=`11.61` min=`3.0` max=`12.0` (n=`40` frames)

## C. First mount vs revisit

- first total_ms: median=`314.5` p90=`320.6` p99=`322.76000000000005` min=`312.0` max=`323.0` (n=`4` ms)
- revisit total_ms: median=`311.0` p90=`327.4` p99=`330.56000000000006` min=`303.0` max=`331.0` (n=`23` ms)
- first target_first_build_latency_ms: median=`27.5` p90=`32.0` p99=`32.0` min=`15.0` max=`32.0` (n=`4` ms)
- revisit target_first_build_latency_ms: median=`32.0` p90=`95.8` p99=`96.78` min=`18.0` max=`97.0` (n=`23` ms)

## D. Same-tab reselect / scroll-to-top settle

- page: `proxies` repeats=`10`
- total_ms: median=`276.0` p90=`279.3` p99=`281.73` min=`270.0` max=`282.0` (n=`10` ms)
- scroll_command_ms: median=`5.5` p90=`12.2` p99=`13.82` min=`1.0` max=`14.0` (n=`10` ms)
- scroll_animation_complete_ms: median=`254.5` p90=`261.1` p99=`261.91` min=`250.0` max=`262.0` (n=`10` ms)
- scroll_us (DFS): median=`397.5` p90=`423.5` p99=`451.85` min=`302.0` max=`455.0` (n=`10` us)
- note: scroll_command_ms = DFS+animateTo issued; scroll_animation_complete_ms = awaited animateTo Future. Product UX still fire-and-forget; only the trace waits.

## E. Page root mount / build counts (product keep:false)

- mounts: `dashboard:24,profiles:1,proxies:1,tools:1`
- builds: `dashboard:26,profiles:1,proxies:1,tools:1`
- dashboard_hero_mounted: `False`
- dashboard_sheen_repeating: `False`
- network_latency_timer: `False`

## P7 keep experiment (not a product change)

- ok: `True`
- offscreen mounts: `dashboard:25,profiles:1,proxies:1,tools:1`
- offscreen dashboard_hero_mounted: `True`
- offscreen sheen_repeating: `False`
- offscreen pulse_repeating: `False`
- offscreen latency_timer: `False`
- offscreen latency_bar: `True`
- keep:true PSS kb: `410638`
- keep:false PSS kb: `414139`
- PSS delta kb (true - false): `-3501`
- keep:true idle gfxinfo frames: `0`
- keep:false idle gfxinfo frames: `0`

Product keep:false FrameTiming is the slices above (A/B). Experimental keep:true:

### P7 keep:true Proxy → Dashboard

- n=`10`
- transition total_ms: median=`307.0` p90=`326.4` p99=`329.64000000000004` min=`296.0` max=`330.0` (n=`10` ms)
- target_first_build_latency_ms (**not** build CPU): median=`None` p90=`None` p99=`None` min=`None` max=`None` (n=`0` ms)
- frame build p50/p90/p99 (median across transitions): `2.211` / `3.558` / `4.4575`
- frame raster p50/p90/p99: `3.78` / `5.682` / `7.5245`
- frame totalSpan p50/p90/p99: `7.7775` / `12.382000000000001` / `15.341000000000001`
- worst_frame_ms: median=`15.794` p90=`20.442899999999998` p99=`22.580490000000005` min=`12.874` max=`22.818` (n=`10` ms)
- over-budget frames: median=`7.5` p90=`10.0` p99=`10.0` min=`5.0` max=`10.0` (n=`10` frames)
- frame_count: median=`20.0` p90=`21.0` p99=`21.0` min=`14.0` max=`21.0` (n=`10` frames)

### P7 keep:true Dashboard → Proxy

- n=`10`
- transition total_ms: median=`315.5` p90=`323.2` p99=`324.82` min=`298.0` max=`325.0` (n=`10` ms)
- target_first_build_latency_ms (**not** build CPU): median=`None` p90=`None` p99=`None` min=`None` max=`None` (n=`0` ms)
- frame build p50/p90/p99 (median across transitions): `2.558` / `3.966` / `4.6080000000000005`
- frame raster p50/p90/p99: `4.102` / `4.8605` / `6.3225`
- frame totalSpan p50/p90/p99: `8.0895` / `11.2225` / `14.279`
- worst_frame_ms: median=`14.533000000000001` p90=`18.048299999999998` p99=`20.30253` min=`10.853` max=`20.553` (n=`10` ms)
- over-budget frames: median=`7.0` p90=`12.0` p99=`12.0` min=`5.0` max=`12.0` (n=`10` frames)
- frame_count: median=`17.0` p90=`21.099999999999998` p99=`21.91` min=`14.0` max=`22.0` (n=`10` frames)

Hero/overview: offscreen `dashboard_hero_mounted` true with keep:true means the Hero subtree was not disposed. Product keep:false drops that subtree when leaving Dashboard.

## Measured ranking (do not start 4B.1 here)

- Do **not** use `target_first_build_latency_ms` as Dashboard CPU cost.
- Use FrameTiming `build_*` vs `raster_*` to see whether jank is UI/layout or raster/compositing.
- Dashboard remount is proven by mount counts. That does **not** by itself prove remount is the largest CPU source.
- Element DFS remains ~0.4–0.8ms and is not a 4B.1 target.
- P7 keep:true is an experiment only. Product `keep` is unchanged.

## Top transitions

- proxies→profiles visit=`unknown` keep_alive=`False` total_ms=`340` target_first_build_latency_ms=`None` build_p99_ms=`4.189` raster_p99_ms=`10.268` worst_frame_ms=`14.672` over_budget=`8` scroll_us=`1048` elements=`1935`
- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`331` target_first_build_latency_ms=`96` build_p99_ms=`10.248` raster_p99_ms=`8.204` worst_frame_ms=`14.821` over_budget=`8` scroll_us=`505` elements=`948`
- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`329` target_first_build_latency_ms=`94` build_p99_ms=`7.781` raster_p99_ms=`7.499` worst_frame_ms=`16.6` over_budget=`5` scroll_us=`395` elements=`948`
- proxies→profiles visit=`unknown` keep_alive=`False` total_ms=`328` target_first_build_latency_ms=`None` build_p99_ms=`2.862` raster_p99_ms=`7.307` worst_frame_ms=`13.209` over_budget=`3` scroll_us=`787` elements=`1935`
- proxies→dashboard visit=`revisit` keep_alive=`False` total_ms=`325` target_first_build_latency_ms=`20` build_p99_ms=`8.501` raster_p99_ms=`5.413` worst_frame_ms=`12.003` over_budget=`5` scroll_us=`483` elements=`1935`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`324` target_first_build_latency_ms=`None` build_p99_ms=`3.897` raster_p99_ms=`4.93` worst_frame_ms=`11.032` over_budget=`10` scroll_us=`781` elements=`1935`
- tools→dashboard visit=`revisit` keep_alive=`False` total_ms=`323` target_first_build_latency_ms=`85` build_p99_ms=`15.519` raster_p99_ms=`8.096` worst_frame_ms=`19.503` over_budget=`8` scroll_us=`384` elements=`948`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`322` target_first_build_latency_ms=`None` build_p99_ms=`8.346` raster_p99_ms=`7.789` worst_frame_ms=`15.54` over_budget=`6` scroll_us=`868` elements=`1935`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`320` target_first_build_latency_ms=`None` build_p99_ms=`4.061` raster_p99_ms=`5.699` worst_frame_ms=`15.156` over_budget=`8` scroll_us=`722` elements=`1935`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`320` target_first_build_latency_ms=`None` build_p99_ms=`4.316` raster_p99_ms=`4.995` worst_frame_ms=`11.007` over_budget=`8` scroll_us=`542` elements=`1935`
- proxies→dashboard visit=`revisit` keep_alive=`False` total_ms=`318` target_first_build_latency_ms=`32` build_p99_ms=`14.097` raster_p99_ms=`7.833` worst_frame_ms=`24.547` over_budget=`3` scroll_us=`774` elements=`1935`
- dashboard→proxies visit=`unknown` keep_alive=`False` total_ms=`318` target_first_build_latency_ms=`None` build_p99_ms=`3.984` raster_p99_ms=`4.603` worst_frame_ms=`10.226` over_budget=`5` scroll_us=`743` elements=`1935`

## Unreliable

- (none)
