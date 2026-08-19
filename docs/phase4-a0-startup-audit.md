# Phase 4A.0 startup-path audit (read-only)

Date: 2026-08-19  
Product baseline: `b7e08b6ef84546e9b3d084a411c3a59e3e4df7c8`  
Scope: `lib/main.dart`, `lib/state.dart`, `lib/application.dart`, and callees (database, preferences, migration, profiles, proxy snapshot, `setupAction.initStatus`, Core connect/init, Android/VPN/Core managers).  
This phase does **not** change product behavior. Instrumentation only.

Phase 1–3 semantics that must stay untouched: single snapshot, source preservation, RawConfig bridge, Script once, DNS/TUN field ownership, atomic snapshot/file flow, Stable Core updater state machine.

## Observed sequence

```text
main()
  WidgetsFlutterBinding.ensureInitialized
  await system.version                    # DeviceInfo Android SDK
  await globalState.init
      await DynamicColorPlugin            # palette + accent
      PackageInfo.fromPlatform
      preferences.getConfigMap
      migration.migrationIfNeeded         # usually no-op after v1
      ProviderContainer + config overrides
      await database.profilesDao.query    # opens Drift DB lazily
      AppLocalizations.load
  runApp(Application)
  first frame                             # HomePage + managers inflate
  post-frame: globalState.attach
      autoUpdateProfiles / autoCheckUpdate (not awaited)
      failed-preference + disclaimer dialogs (usually no-op)
      hydrateProxyGroupsSnapshot          # DB snapshot + full YAML SHA-256
      setupAction.initStatus
          if VPN running or autoRun:
              connectCore + initCore + updateStatus(isInit)
          else:
              skip; CoreStatus.disconnected
      initProvider = true  → main_ready
```

`first_frame` and `main_ready` are different: the shell can paint before Core/VPN work.

## 1. Blocking `await`s before `runApp`

| Await | File | Notes |
|---|---|---|
| `system.version` | `lib/common/system.dart` | `DeviceInfoPlugin().androidInfo` |
| `_initDynamicColor` | `lib/state.dart` | two plugin calls, errors swallowed |
| `PackageInfo.fromPlatform` | `lib/state.dart` | |
| `preferences.getConfigMap` | `lib/common/preferences.dart` | SharedPreferences JSON |
| `migration.migrationIfNeeded` | `lib/common/migration.dart` | version read; v0 path can restore DB + rewrite prefs |
| `database.profilesDao.query().get()` | `lib/database/database.dart` | first use opens `database.sqlite` in background isolate |
| `AppLocalizations.load` | `lib/state.dart` | |

Not awaited before `runApp`: Core connect, VPN, snapshot hydrate, `applyProfile`.

## 2. Work that must finish before the first frame

Anything in (1), plus first `Application.build` / `HomePage` inflate (theme, navigation, dashboard widgets). Managers (`AndroidManager`, `TileManager`, `CoreManager`, `VpnManager`, `AppStateManager`, `ConnectivityManager`, `StatusManager`, `ThemeManager`) mount in the same first build. Their `initState` listeners are cheap; CoreManager hydration is post-frame on profile change only.

Proxy group snapshot is **not** available on the true first frame. `hydrateProxyGroupsSnapshot` runs in `attach()`, which is scheduled with `addPostFrameCallback`. The comment “before core init for instant first paint” means before Core, not before Flutter’s first raster.

## 3. Could theoretically defer (do not change in 4A.0)

- Dynamic color (fallback accent already exists).
- `PackageInfo` if UA/version UI can wait.
- Loading **all** profiles if Home only needs current id from prefs.
- Localization preload if first frame can use platform locale widgets.
- Disclaimer/failed-preference (already after first frame).
- Snapshot fingerprint hashing of the full YAML (validate lazily or store hash).
- `connectCore`’s extra `Future.delayed(300ms)` (see P0).
- `autoUpdateProfiles` / `autoCheckUpdate` (already unawaited).

## 4. After first frame until `main_ready`

1. `globalState.attach` / `_initApp`
2. Unawaited profile auto-update and update check
3. Preference-corruption and disclaimer dialogs (usually skip)
4. `hydrateProxyGroupsSnapshot`: snapshot row + `_computeProfileFingerprint` reads **entire profile YAML** and SHA-256s it
5. `initStatus` → possible `connectCore` / `initCore` / `applyProfile(force)` / `_handleStart` (listener + UI stats timer)
6. `initProvider = true` (`main_ready`)
7. Changelog dialog and 20-minute auto-update timer start after `attach` returns (after `main_ready`)

## 5. Core/VPN already running vs not

`shouldFullSetupOnInit(isRunning, autoRun)` (`lib/providers/action.dart`):

- **VPN running or autoRun:** `connectCore` → `initCore` → `updateStatus(true, isInit: true)`. Init path `applyProfile(force: true)` with `preloadInvoke: _handleStart`. This is the heavy path: Binder/Core, single-snapshot setup, `updateGroups`, provider sync.
- **VPN idle and autoRun off:** skip full setup, `runTime=null`, `CoreStatus.disconnected`. Snapshot hydrate still runs. No Core IPC for setup.

`isRunning` comes from `service?.getRunTime()` on Android (`_updateStartTime`) before the branch.

Resume later uses `shouldReconnectCoreOnResume`: Android + stopped + groups already present does **not** reconnect (Keep).

## 6. Large Profile / large Proxy Group impact

- Before `runApp`: all profile **rows** load from SQLite (not YAML). Large row counts cost more; YAML size does not.
- After first frame: fingerprint hashes the full YAML → CPU + I/O linear in file size.
- If full setup runs: `_setupConfig` uses the Phase 2 single-snapshot path (Keep). Core parse/load scales with document size. `updateGroups` + snapshot write scales with group/leaf count. Binder already sends a path, not the whole profile (Keep).
- Home/Proxies first paint after hydrate copies snapshot groups into `groupsProvider`. Huge `all` lists cost Dart decode + widget work even with Core skipped.

## 7. Repeated DB / file / IPC

| Overlap | Where |
|---|---|
| SharedPreferences | constructor starts load; `getConfigMap` / `getVersion` await the same completer (OK) |
| Drift open | lazy on first query; profiles then snapshot is a second query, not a second open |
| Profile YAML | not read before `runApp`; read fully for fingerprint during hydrate; setup path reads snapshot/file again for Core (Phase 2 single snapshot — do not “fix” by splitting ownership) |
| `connectCore` / `ensureCoreReady` | already coalesced with in-flight futures (Keep) |
| `initCore` | may `updateGroups` or `ensureCurrentProfileReady` after hydrate already filled groups |
| `applyProfile` on init | `updateGroups` + `syncProviders` after Core setup |
| CoreManager profile listener | hydrates again on current-profile change (startup no-op if id stable) |

The 300ms delay is paired with `coreController.preload()` via `Future.wait` — preload can finish earlier; the delay still gates “connected”.

## 8. Performance candidates (do not implement now)

**P0**

- `connectCore` always waits an extra 300ms.
- Full YAML SHA-256 on every hydrate, on the attach critical path.
- Full setup on cold start when VPN is already up: `applyProfile(force)` + `updateGroups` after snapshot hydrate.

**P1**

- Blocking dynamic color + PackageInfo + all-profiles query before `runApp`.
- Snapshot hydrate after first frame so first raster has empty groups.
- `initCore` follow-up group refresh overlapping hydrate.
- Large groups in `groupsProvider` for dashboard that does not need every leaf.

**P2**

- Changelog / link / shortcuts after attach.
- `autoCheckUpdate` network after attach.
- Theme rebuild work in first `Application.build` (two brightness themes).

## 9. Keep — do not rewrite for speed

- Phase 2B single snapshot + unique snapshot file path over Binder.
- Source preservation overlay, RawConfig JSON bridge, Script-once (Phase 2CD).
- DNS vs TUN field ownership split.
- Atomic snapshot/file flow; do not reintroduce dual reads with divergent bytes.
- Stable Core updater state machine (Phase 3).
- `shouldFullSetupOnInit` skip when idle and autoRun off.
- `shouldReconnectCoreOnResume` skip on Android when stopped and groups exist.
- `connectCore` / `ensureCoreReady` / `updateGroups` in-flight reuse.
- UI stats timer cancelled on background; logs/requests only on visible pages.
- Background Go GC (60s throttle) and stop-path `closeConnections` then GC.
- Smart stop/resume native TUN path (not a full service tear-down).
- Proxy groups snapshot for display without requiring Core on idle start.

## Managers on the first tree

- `AndroidManager`: service listener + shared-state debounce; no Core start.
- `VpnManager`: watches VPN props; restart tip only if already started.
- `CoreManager`: event gates + profile-change hydrate/setup (post-frame).
- `AppStateManager`: lifecycle; cancels UI timer on pause; optional `tryStartCore` on resume.

## Instrumentation added in 4A.0

Gated `StartupTrace` (`lib/common/perf_trace.dart`). Release without `--dart-define=PHASE4_PERF=true` is a bool check only. See `tools/perf/README.md`.
