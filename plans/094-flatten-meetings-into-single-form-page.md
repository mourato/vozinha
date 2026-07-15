# Plan 094: Flatten Meetings into a single Form page

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
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab/ \
>   Packages/MeetingAssistantCore/Sources/UI/Models/MeetingSettingsNavigationState.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsExpandableSection.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/MeetingSettingsNavigationStateTests.swift \
>   Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings \
>   Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings
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
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — removes Meetings navigation state machine
- **Rationale**: Cross-cutting UI + tests + localization; High risk triggers Full
- **Escalate when**: Monitoring collections cannot fit expandable without
  breaking keyboard delete / sheets; or file delta exceeds ~8 Swift files and
  needs a split

## Why this matters

Meetings uses three toolbar-driven subroutes (`.monitoringTargets`,
`.export`, `.meetingPrompts`) that duplicate content already expressible as
Form sections plus existing sheets. Flattening removes Meetings from the global
back/forward chrome and matches VoiceInk’s “one scrolling settings surface +
disclosure” pattern.

## Current state

Root Workflow section drills out:

```150:161:Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift
                SettingsListDrillDownButtonRow(
                    title: "settings.meetings.monitoring_access.button".localized,
                    ...
                ) { updateNavigationState(to: .monitoringTargets) }
                ...
                SettingsListDrillDownButtonRow(
                    title: "settings.meetings.export".localized,
                    ...
                ) { updateNavigationState(to: .export) }
```

Prompts drill-down:

```222:228:Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift
            SettingsListDrillDownButtonRow(
                title: "settings.meetings.prompts".localized,
                ...
            ) {
                updateNavigationState(to: .meetingPrompts)
            }
```

- `.export` page (`exportPage`, ~297+) — scalar toggles/pickers +
  `SummaryTemplateEditorSheet`
- `.meetingPrompts` page — language pickers + prompt list + `PromptEditorSheet`
- `.monitoringTargets` — `InstalledAppsSelectionSection` + web targets +
  `AppSearchSheet` / `WebMeetingTargetEditorSheet`
- State: `MeetingSettingsNavigationState.swift` (open/goBack/goForward)
- Wired in `SettingsPage` for Meetings back/forward only

Search already lands on Meetings **root** only (no `meetingRoute` on
`SettingsDestination`) — flatten does not break search routing.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Nav tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'MeetingSettingsNavigationStateTests'` | Updated or deleted suite passes / removed |
| Related | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSearchIndexTests\|LocalizationKeyIntegrityTests\|AutoMeetingConfirmationSettingsTests'` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Validate | `make validate-agent ARGS="--lane auto --base main"` | PASS (Full expected) |

## Suggested executor toolkit

- `macos-app-engineering` for Form / expandable composition
- `localization` for key add/remove symmetry (en + pt)
- Reuse `SettingsExpandableSection` from 093 — do not create a second API

## Scope

**In scope:**

- `MeetingSettingsTab.swift` and `MeetingSettingsTab/*`
- `MeetingSettingsNavigationState.swift` — delete or gut after callers gone
- `MeetingSettingsNavigationStateTests.swift` — delete or replace with
  “Meetings has no subroutes” characterization if useful
- `SettingsPage.swift` — remove Meetings branches from
  `navigateBack` / `navigateForward` / `canNavigateBack` / `canNavigateForward`
  and drop `@State meetingNavigationState` if unused
- Localization files only for keys added/removed by this migration
- Previews on `MeetingSettingsTab`

**Out of scope:**

- Activity / System flatten (095–096)
- Toolbar retirement beyond Meetings wiring (097)
- Modes drawer
- Changing export/prompt persistence semantics
- Rewriting `InstalledAppsSelectionSection` internals

## Git workflow

- Branch: `advisor/094-flatten-meetings-settings`
- Commits: e.g. `refactor(settings): fold Meetings export and prompts into root Form`
- Do NOT push/PR unless asked

## Steps

### Step 1: Inline Export into Meetings root

Replace the Export drill-down row with `SettingsExpandableSection` (or a native
`Section` that is always visible if product prefers always-on — default is
**expandable**, defaultExpanded = false, or true when
`autoExportSummaries == true`).

Move the body of `exportPage` into the expandable children. Keep
`SummaryTemplateEditorSheet` presentation on the root tab.

Remove `.export` from `MeetingSettingsNavigationRoute` and the
`exportPage` / switch arm.

**Verify**: `make build-agent` → exit 0; open Meetings in preview — export
controls appear without leaving root

### Step 2: Inline Meeting Prompts into root

Move language picker + auto-detect + prompt list from `meetingPromptsPage` into
the Meeting Intelligence section (or an expandable “Meeting prompts” block under
it). Keep `PromptEditorSheet` as-is.

Remove `.meetingPrompts` route and page.

Preserve disable/opacity when post-processing is off (existing behavior at
lines 229–230).

**Verify**: focused Meetings-related tests + build → exit 0

### Step 3: Inline Monitoring targets

Replace monitoring drill-down with `SettingsExpandableSection` titled with
existing monitoring keys. Embed:

- info callout (if still needed — avoid duplicate copy with section header)
- `InstalledAppsSelectionSection`
- web targets section

Keep sheets (`AppSearchSheet`, `WebMeetingTargetEditorSheet`) and delete
confirmation alerts on the root tab.

Remove `.monitoringTargets` route and `monitoringTargetsPage`.

If the expandable content is too tall / breaks Form scrolling ownership, STOP
and report — do not wrap in a nested ScrollView.

**Verify**: `make build-agent` → exit 0

### Step 4: Delete navigation state and SettingsPage wiring

- Delete `MeetingSettingsNavigationState` + tests, **or** leave a deprecated
  stub only if something external still imports it (prefer delete).
- Remove `meetingNavigationState` from `SettingsPage` and all Meetings cases in
  back/forward helpers.
- Ensure `MeetingSettingsTab` no longer takes a navigation binding (simplify
  init).

**Verify**:
```bash
rg -n "MeetingSettingsNavigationState|meetingNavigationState" Packages/MeetingAssistantCore
```
→ no product references (tests may be gone)

### Step 5: Localization cleanup

Remove orphaned drill-down-only keys if unused (`*_drilldown_desc`,
`*_accessibility_hint` for navigation) **only after** `rg` shows zero
references. Keep titles reused by expandable headers.

**Verify**:
```bash
swift test --package-path Packages/MeetingAssistantCore --filter LocalizationKeyIntegrityTests
```
→ exit 0

## Test plan

- Delete or rewrite `MeetingSettingsNavigationStateTests` — no subroute
  open/back/forward cases.
- Keep `AutoMeetingConfirmationSettingsTests` / search index tests green.
- Manual: enable meeting transcription → expand monitoring, add app, edit web
  target, expand export, edit template, open prompt sheet — all without toolbar
  back.

## Done criteria

- [ ] `MeetingSettingsTab` is a single-page Form (plus sheets); no route switch
- [ ] `MeetingSettingsNavigationState` removed from product code
- [ ] `SettingsPage` has no Meetings back/forward wiring
- [ ] Localization integrity tests pass
- [ ] `make build-agent` exits 0
- [ ] `plans/README.md` → DONE

## STOP conditions

- Monitoring inside Form breaks list selection / keyboard delete — stop; consider
  side panel for monitoring only and refresh plan.
- Nested ScrollView appears necessary — stop (violates 079).
- Drift: export/prompts pages already relocated since `bb6fbf79`.

## Maintenance notes

- 097 will remove remaining toolbar chrome; Meetings should already be
  independent.
- Reviewers: confirm no second card background around monitoring lists (plan
  082 / 092 visual contract).
- Deferred: search auto-expand of Export when query matches export keys.
