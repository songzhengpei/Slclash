# Surge Mobile UI Audit

Branch: `optimize/mobile-v8a-surge-ui`

Scope: Android mobile arm64-v8a only. The first optimization pass is the visual
component migration toward the existing Surge-like design language. This audit
tracks old component surfaces, existing Surge replacements, missing reusable
components, and a safe migration order.

## Current Surge Foundation

Existing reusable Surge components:

- `lib/widgets/surge/surge_theme_extension.dart`
  - Global `SurgeTheme` extension and color/spacing/radius tokens.
- `lib/widgets/surge/surge_card.dart`
  - General rounded card surface.
- `lib/widgets/surge/surge_section.dart`
  - Grouped section container, suitable for settings/list groups.
- `lib/widgets/surge/surge_list_tile.dart`
  - Simple title/subtitle/leading/trailing list row with optional chevron.
- `lib/widgets/surge/surge_segmented_control.dart`
  - Compact segmented control.
- `lib/widgets/surge/surge_status_button.dart`
  - Running/stopped action button.
- `lib/widgets/surge/surge_bottom_nav.dart`
  - Mobile bottom navigation.
- `lib/widgets/list.dart`
  - Already contains `SurgeSwitch` and `generateListView` now wraps rows in
    `SurgeSection`.

Already migrated or partially migrated areas:

- `lib/application.dart`
  - Applies `SurgeTheme`, app bar colors, switch/radio/checkbox themes.
- `lib/pages/home.dart`
  - Uses `SurgeBottomNav` for mobile navigation.
- `lib/views/dashboard/**`
  - Dashboard mostly uses Surge cards and dashboard-specific Surge widgets.
- `lib/views/tools.dart`
  - Settings/tools list uses `SurgeSection` + `SurgeListTile`.
- `lib/views/proxies/**`
  - Proxy cards, proxy list headers, and providers are partially Surge-styled.
- `lib/views/profiles/profiles.dart`
  - Main profile surfaces are partially Surge-styled.
- `lib/views/profiles/media_check.dart`
  - Heavily custom, but already uses `SurgeCard` and `SurgeSwitch` in key areas.

## Audit Counts

Generated from non-generated Dart files under `lib/`.

| Pattern | Count | Files |
| --- | ---: | ---: |
| `ListItem` calls | 113 | 23 |
| Raw `ListView` calls | 27 | 22 |
| `CommonCard` calls | 25 | 16 |
| `InfoHeader` calls | 18 | 10 |
| `DecorationListItem` calls | 16 | 8 |
| `generateSectionV2/V3` calls | 10 | 4 |
| `SurgeSection` calls | 10 | 7 |
| `generateListView` calls | 9 | 7 |
| Raw `Switch` calls | 9 | 4 |
| Raw `ListTile` calls | 7 | 4 |
| `SelectedDecorationListItem` calls | 4 | 3 |
| Raw `Card` calls | 4 | 4 |
| Raw dropdown calls | 2 | 1 |
| `CommonSelectedListItem` calls | 1 | 1 |

## Old Component Surfaces

### 1. Generic settings/list rows

Primary old component:

- `lib/widgets/list.dart`
  - `ListItem`
  - `ListItem.open`
  - `ListItem.next`
  - `ListItem.options`
  - `ListItem.input`
  - `ListItem.checkbox`
  - `ListItem.switchItem`
  - `ListItem.radio`

Largest call sites:

- `lib/views/config/dns.dart` - 21 calls
- `lib/views/config/general.dart` - 14 calls
- `lib/views/config/network.dart` - 12 calls
- `lib/views/application_setting.dart` - 10 calls
- `lib/views/backup_and_restore.dart` - 9 calls
- `lib/views/developer.dart` - 7 calls
- `lib/views/profiles/edit.dart` - 5 calls
- `lib/views/config/advanced.dart` - 4 calls
- `lib/views/about.dart` - 4 calls
- `lib/views/profiles/add.dart` - 3 calls

Replacement status:

- Direct replacement exists for simple rows: `SurgeListTile`.
- Direct replacement exists for switch rows: current `SurgeSwitch`.
- Partial wrapper exists for grouped pages: `generateListView` already wraps
  rows in `SurgeSection`.
- Missing: a reusable row component that preserves `ListItem` delegates while
  rendering as Surge UI.

Recommended reusable component:

- `SurgeSettingTile<T>`
  - Supports title/subtitle as widgets or strings.
  - Supports delegates: open, next, options, input, checkbox, switch, radio.
  - Uses `SurgeListTile` for the visual row.
  - Keeps existing dialog/navigation behavior from `ListItem`.

Migration approach:

1. Add `SurgeSettingTile` alongside existing `ListItem`.
2. Port `ListItem._buildListTile` rendering to Surge internals without changing
   the delegate behavior.
3. Migrate call sites page by page, starting with high-volume config/settings
   pages.
4. Remove old `ListItem` only after all call sites are gone.

### 2. Decorated/selectable editor rows

Primary old components:

- `lib/widgets/list.dart`
  - `DecorationListItem`
  - `SelectedDecorationListItem`
  - `CommonSelectedListItem`

Call sites:

- `lib/features/overwrite/rule.dart`
- `lib/views/profiles/profiles.dart`
- `lib/views/profiles/overwrite/custom/groups.dart`
- `lib/views/profiles/overwrite/custom/icon.dart`
- `lib/views/profiles/overwrite/custom/proxies.dart`
- `lib/views/profiles/overwrite/custom/proxy_providers.dart`
- `lib/views/profiles/overwrite/custom/rules.dart`
- `lib/widgets/input.dart`

Replacement status:

- No complete direct replacement.
- `SurgeCard` can replace the card surface.
- `SurgeListTile` can cover simple title/subtitle rows.
- Missing: selected/error/reorder-friendly list row with grouped corner radius.

Recommended reusable component:

- `SurgeSelectableListTile`
  - Selection state, error state, editing mode, optional circular checkbox.
  - Supports grouped position radius: start, middle, end, startAndEnd.
  - Uses `SurgeCard` for row surface and `SurgeListTile`-like layout inside.

Migration approach:

1. Build `SurgeSelectableListTile`.
2. Reimplement `SelectedDecorationListItem` and `DecorationListItem` in terms of
   it first.
3. Then migrate custom overwrite pages to the new component directly.

### 3. Section/header helpers

Primary old helpers:

- `lib/widgets/list.dart`
  - `ListHeader`
  - `generateSection`
  - `generateSectionV2`
  - `generateSectionV3`
  - `generateInfoSection`
- `lib/widgets/card.dart`
  - `InfoHeader`
  - `SettingsBlock`

Replacement status:

- `SurgeSection` covers grouped section layout.
- Missing: shared section header with optional actions.
- `SurgeSection` has `title` and `footer` but no action slot.

Recommended reusable component changes:

- Extend `SurgeSection` with optional `actions`.
- Add `SurgeSectionHeader` if the header needs to be used outside a section.

Migration approach:

1. Add `actions` support to `SurgeSection`.
2. Reimplement old `ListHeader` and `InfoHeader` usage through Surge section
   primitives where possible.
3. Remove `generateSectionV2/V3` after overwrite/custom pages migrate.

### 4. Card surfaces

Primary old component:

- `lib/widgets/card.dart`
  - `CommonCard`
  - `SettingsBlock`

Notable call sites:

- `lib/widgets/list.dart`
- `lib/widgets/button.dart`
- `lib/widgets/color_scheme_box.dart`
- `lib/widgets/setting.dart`
- `lib/widgets/super_grid.dart`
- `lib/views/dashboard/widgets/quick_options.dart`
- `lib/views/dashboard/widgets/memory_info.dart`
- `lib/views/developer.dart`
- `lib/views/hotkey.dart`
- `lib/views/profiles/overwrite/**`

Replacement status:

- `SurgeCard` is a broad replacement for passive and tappable cards.
- Missing: compatibility for `CommonCard` states:
  - `isSelected`
  - `isError`
  - `selectWidget`
  - `enterAnimated`
  - `onLongPress`
  - custom `shape`

Recommended reusable component:

- Either extend `SurgeCard` with selected/error/long-press states, or add
  `SurgeActionCard` for stateful/tappable use cases.

Migration approach:

1. Keep `CommonCard` temporarily for complex editor rows.
2. Replace passive cards and quick option cards with `SurgeCard`.
3. Replace selectable cards after `SurgeSelectableListTile` exists.

### 5. Raw Material widgets still visible in UI

Raw list/layout widgets:

- `lib/views/hotkey.dart`
- `lib/views/tools.dart`
- `lib/views/theme.dart`
- `lib/views/resources.dart`
- `lib/views/config/scripts.dart`
- `lib/views/backup_and_restore.dart`
- `lib/views/access.dart`
- `lib/views/profiles/add.dart`
- `lib/views/profiles/edit.dart`
- `lib/views/profiles/media_check.dart`
- `lib/views/profiles/profiles.dart`
- `lib/views/profiles/overwrite/**`
- `lib/views/proxies/list.dart`
- `lib/views/proxies/providers.dart`
- `lib/state.dart`

Raw controls:

- Raw `Switch` appears in:
  - `lib/features/overwrite/rule.dart`
  - `lib/views/dashboard/widgets/quick_options.dart`
  - `lib/views/profiles/overwrite/custom/groups.dart`
  - `lib/views/profiles/overwrite/custom/rules.dart`
- Raw dropdowns appear in:
  - `lib/views/profiles/media_check.dart`
- Raw `Card` appears in:
  - `lib/manager/status_manager.dart`
  - `lib/views/profiles/overwrite/custom/groups.dart`
  - `lib/widgets/card.dart`
  - `lib/widgets/popup.dart`

Replacement status:

- Raw `Switch` can use `SurgeSwitch` where a custom visual is desired.
- Raw dropdowns need a new `SurgeSelectField` or `SurgeDropdown`.
- Raw `Card` can usually use `SurgeCard`.
- Raw `ListView` is often just a scroll container and does not always need
  replacement. It should use consistent Surge background/padding.

## Proposed Migration Order

1. `lib/widgets/list.dart`
   - Introduce or retrofit Surge rendering for `ListItem`.
   - This touches the highest number of old rows with the smallest page-level
     blast radius.
2. Settings/config pages
   - `lib/views/application_setting.dart`
   - `lib/views/config/config.dart`
   - `lib/views/config/advanced.dart`
   - `lib/views/config/general.dart`
   - `lib/views/config/network.dart`
   - `lib/views/config/dns.dart`
3. Support/tool pages
   - `lib/views/about.dart`
   - `lib/views/backup_and_restore.dart`
   - `lib/views/developer.dart`
   - `lib/views/resources.dart`
   - `lib/views/logs.dart`
4. Profile add/edit pages
   - `lib/views/profiles/add.dart`
   - `lib/views/profiles/edit.dart`
5. Overwrite/custom editors
   - Add `SurgeSelectableListTile` before migrating these.
   - Then migrate `lib/views/profiles/overwrite/**` and
     `lib/features/overwrite/rule.dart`.
6. Specialized heavy views
   - `lib/views/profiles/media_check.dart`
   - `lib/views/proxies/list.dart`
   - These already have custom Surge styling and should be treated separately.

## Component Gaps To Build

Required before full replacement:

- `SurgeSettingTile<T>`
  - Delegate-compatible replacement for `ListItem`.
- `SurgeSelectableListTile`
  - Replacement for `DecorationListItem`, `SelectedDecorationListItem`, and
    `CommonSelectedListItem`.
- `SurgeSectionHeader` or `SurgeSection.actions`
  - Replacement path for `ListHeader` and `InfoHeader` action rows.
- `SurgeActionCard`
  - If `SurgeCard` should remain simple, this covers selected/error/long-press
    card behavior.
- `SurgeDropdown` or `SurgeSelectField`
  - Needed for `media_check.dart` dropdowns.

Nice-to-have:

- `SurgeIconBadge`
  - Reusable rounded icon container for settings/proxy/profile rows.
- `SurgeEmptyState`
  - Consolidates empty states currently spread across views.
- `SurgeListScaffold`
  - Standard mobile list page with background, bottom nav padding, and section
    spacing.

## Lightweight/Mobile-Only Follow-Up Observations

These are not part of the first UI replacement pass, but they are relevant to
the mobile arm64-v8a simplification goal:

- `lib/common/tray.dart`, `lib/common/window.dart`, and `lib/views/hotkey.dart`
  remain visible in source even though desktop scope is removed. Some usage is
  guarded by `system.isDesktop`, but these files are candidates for deletion or
  stronger isolation after confirming imports.
- `lib/application.dart` still configures page transitions for Windows, Linux,
  and macOS. For Android-only scope this can likely be simplified.
- `lib/views/tools.dart` still includes desktop-gated hotkey and Windows
  loopback entries. These are candidates for removal in a later mobile-only
  cleanup pass.
- `pubspec.yaml` still includes broad UI/dependency surface. A separate pass
  should map unused dependencies before removal.

## First Implementation Recommendation

Start with a compatibility-first change in `lib/widgets/list.dart`:

- Keep the public `ListItem` API stable.
- Replace internal `ListTile` rendering with a Surge-style row.
- Continue using existing delegates for open/next/options/input/checkbox/switch
  so behavior stays unchanged.
- Run focused visual checks on:
  - application settings
  - config/general/network/dns
  - backup and restore
  - profile add/edit

This gives the largest visible improvement while minimizing risk.
