# Plan 095: Flatten System settings hierarchy onto General

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat bb6fbf79..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/PermissionsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModelsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchRouteManifest.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSectionTests.swift
> ```

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/093-establish-settings-flatten-ia-and-expandable-row.md
- **Category**: migration
- **Planned at**: commit `bb6fbf79`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `yes` — independent of 094 (Meetings) if two writers were
  allowed; repo policy is one writer — serialize after or before 094
- **Reviewer required**: `yes` — deep-link and search remapping risk
- **Rationale**: System routing + search destinations + large composed children
- **Escalate when**: Folding Models/Dictionary/Audio into General is demanded in
  this plan — that is explicitly out of scope; stop and split a follow-up

## Why this matters

System currently uses five child routes (models, dictionary, sound,
permissions, protectedApps) driven by toolbar back-to-root. Permissions (~101
LOC) and protected apps (~141 LOC) are foldable. Models, Dictionary, and Audio
remain specialized destinations (plan 082 content exceptions) but must stop
depending on global toolbar history once 097 lands — this plan folds the easy
children and leaves the three heavy destinations with an **in-page back** affordance
so toolbar retirement becomes safe.

## Current state

```4:11:Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift
public enum SystemSettingsRoute: Hashable, Sendable {
    case root
    case models
    case dictionary
    case sound
    case permissions
    case protectedApps
}
```

`GeneralSettingsTab` renders drill-downs when openers are non-nil
(`systemDrilldownsSection`, ~222–269).

Legacy redirects in `SettingsSection.destination` map `.models` / `.vocabulary` /
`.audio` / `.permissions` → `systemRoute` children. Search and
`SettingsSectionTests` lock these.

## Target shape after this plan

```
System root (GeneralSettingsTab Form)
├── App behavior / appearance / storage / recording indicator (existing)
├── Permissions content inlined (no .permissions route)
├── Protected apps as SettingsExpandableSection (no .protectedApps route)
└── Drill-downs retained ONLY for:
    ├── Models
    ├── Dictionary (Vocabulary)
    └── Audio (Sound)

When Models/Dictionary/Audio is open:
└── Child page shows a leading "Settings" / back button row (or toolbar-free
    header) that sets route = .root — does NOT use SettingsPage navigateBack
```

Deep links:

- `.permissions` destination → System root (optionally expand permissions —
  optional; default scroll-to-top of permissions section)
- `.protectedApps` search → System root with expandable open if cheap; else root
- `.models` / `.vocabulary` / `.audio` → unchanged child routes

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Section tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSectionTests\|SettingsSearchIndexTests'` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Validate | `make validate-agent ARGS="--lane auto --base main"` | PASS |

## Suggested executor toolkit

- `macos-app-engineering`
- `localization` if keys change
- Reuse permission / protected-apps view bodies; do not rewrite selection lists

## Scope

**In scope:**

- `SystemSettingsTab.swift` — shrink `SystemSettingsRoute`; compose root
- `GeneralSettingsTab.swift` — inline permissions; expandable protected apps;
  keep three drill-downs; add optional `onBack` for child pages if owned here
- `PermissionsSettingsTab.swift` — extract reusable content view if needed, or
  call existing body from General
- `EnhancementsSettingsTab.swift` — protected-apps content reusable from root
- Child tabs `ModelsSettingsTab` / `VocabularySettingsTab` / `AudioSettingsTab` —
  add local back control only
- `SettingsPage.swift` — `systemRoute` handling; back helper can still map
  system→root until 097, but child pages must not *require* it
- `SettingsSection.swift` + search manifest + `SettingsSectionTests` — remap
  permissions/protectedApps destinations
- Localization if new “Back to Settings” key is required (prefer existing
  `settings.section.settings`)

**Out of scope:**

- Folding Models / Dictionary / Audio into General expandable sections
- Meetings / Activity
- Deleting toolbar chrome entirely (097)
- Modes

## Git workflow

- Branch: `advisor/095-flatten-system-settings`
- Commits: e.g. `refactor(settings): fold System permissions and protected apps into General`
- Do NOT push/PR unless asked

## Steps

### Step 1: Remap destinations and tests first (fail closed)

Update `SettingsSection.destination` so `.permissions` resolves to
`SettingsDestination(section: .system)` with `systemRoute: .root` (or keep
route but treat as root — prefer removing `.permissions` from enum).

Update `SettingsSectionTests` expectations before UI so CI fails until UI
matches.

Update search keys that targeted `systemRoute: .protectedApps` to System root.

**Verify**:
```bash
swift test --package-path Packages/MeetingAssistantCore --filter SettingsSectionTests
```
→ fails until Step 2–3 complete is OK; after Step 3 must pass

### Step 2: Inline Permissions into General root

Extract the Form sections from `PermissionsSettingsTab` into a shared view
(e.g. `PermissionsSettingsContent`) used by General. Remove `.permissions`
from `SystemSettingsRoute` and the switch arm. Remove permissions drill-down
row.

**Verify**: `make build-agent` → exit 0

### Step 3: Protected apps as expandable on root

Embed protected-apps list + `AppSearchSheet` inside `SettingsExpandableSection`
on General. Remove `.protectedApps` route and drill-down section.

**Verify**: build + open System preview → expand protected apps works

### Step 4: Local back on Models / Dictionary / Audio

On each remaining child page, add a top control that calls `route = .root`
(pass a closure from `SystemSettingsTab`). Do not invent NavigationStack.

Keep drill-down rows on root for these three only.

**Verify**: navigate Models → tap back → General root without using window
toolbar

### Step 5: SettingsPage cleanup

If `systemRoute` only needs `.root|.models|.dictionary|.sound`, update types.
`canNavigateBack` for system may remain until 097 but should be redundant with
local back.

**Verify**:
```bash
rg -n "case \\.permissions|case \\.protectedApps|systemRoute: \\.permissions|systemRoute: \\.protectedApps" Packages/MeetingAssistantCore
```
→ no stale product references

## Test plan

- Update `SettingsSectionTests` for remapped permissions/protectedApps.
- Keep `SettingsSearchIndexTests` green.
- Manual: search “permissions” opens System root; Models still opens models
  page; local back returns.

## Done criteria

- [ ] `SystemSettingsRoute` has no `.permissions` / `.protectedApps`
- [ ] Permissions + protected apps live on General Form
- [ ] Models / Dictionary / Audio retain destinations with local back
- [ ] Destination/search tests updated and passing
- [ ] `make build-agent` exits 0
- [ ] `plans/README.md` → DONE

## STOP conditions

- Folding Models/Audio appears required to fix layout — stop; that is a new plan.
- Permission status blocks lose specialized layout when forced into scalar rows —
  keep composed Section content (082 exception).
- Drift in System hierarchy since `bb6fbf79`.

## Maintenance notes

- Follow-up (optional later): promote Models/Dictionary/Audio to top-level
  sidebar items (VoiceInk style) — out of B2 scope unless product asks.
- 097 removes global system back; local back becomes the only path.
