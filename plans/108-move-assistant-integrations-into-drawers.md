# Plan 108: Move Assistant and Integrations into Dictation Modes drawers

> **Executor instructions**: Follow all steps and update the plan ledger.
>
> **Drift check (run first)**:
> `git diff --stat 22794e18..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AssistantSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/IntegrationsSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/Models/DictationStyleRoute.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift`

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: MED
- **Depends on**: `plans/107-relocate-dictation-settings-into-mode-drawer.md`
- **Category**: direction
- **Planned at**: commit `22794e18`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — both pages share one route and overlay host
- **Reviewer required**: yes — sheet, focus, and preview lifecycle review
- **Rationale**: Existing functionality is being recomposed, not redesigned.
- **Escalate when**: A second simultaneous side panel is required or an existing Assistant/Integration capability must be removed.

## Why this matters

Assistant and Integrations are mode-adjacent tools, but currently occupy
top-level sidebar pages. They should be discoverable as two drilldowns in
Dictation Modes while retaining every setting and lifecycle behavior.

## Current state

- `ModesSettingsTab.swift` owns one `SettingsSubpageNavigationState` and one
  `.settingsSidePanel`; `DictationStyleRoute.swift` only has editor/prompt.
- `AssistantSettingsTab.swift` owns capability toggle, shortcut, visual
  feedback, preview controller/task cleanup, and immediate persistence.
- `IntegrationsSettingsTab.swift` owns capability toggle, integration editor
  sheet, and nested advanced Bash sheet.
- `SettingsListDrillDownButtonRow` is the established row primitive.
- `SettingsDestination` has no Modes subroute, so search cannot request one of
  these drawers directly.
- `ModeEditorDrawer` supports footerless content. Do not nest a complete
  `SettingsFormPage` inside its Form.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Routes/search | `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` | exit 0 |
| Drawer navigation | `./scripts/run-tests.sh --suite dev --file SettingsSubpageNavigationStateTests` | exit 0 |
| Preview | `make preview-check` | exit 0 |
| Final | `make validate-agent ARGS="--lane auto"` | Full PASS |

## Suggested executor toolkit

- Use `macos-app-engineering`, `apple-design`, `testing-xctest`, and
  `delivery-workflow`.

## Scope

**In scope**:

- `UI/Models/DictationStyleRoute.swift`
- `UI/pages/settings/tabs/{ModesSettingsTab,StylesSettingsTab,AssistantSettingsTab,IntegrationsSettingsTab}.swift`
- `UI/components/settings/{ModeEditorDrawer,SettingsSection,SettingsSearchRouteManifest,SettingsSearchIndex,SettingsPreviewEvidenceCatalog}.swift`
- `UI/pages/settings/SettingsPage.swift`
- Existing Assistant preview/controller and Integration editor files only when
  needed to preserve their public composition.
- Corresponding Settings route/search/navigation tests and localizations.

**Out of scope**: Changing Assistant or Integration behavior/data models,
redesigning their controls, or allowing multiple drawers simultaneously.

## Git workflow

- Isolated branch/worktree: `codex/108-assistant-integration-drawers`.
- One writer. Commit example:
  `refactor(settings): nest assistant tools under dictation modes`.

## Steps

### Step 1: Generalize the Dictation Modes route

Rename/generalize the route if needed and add Assistant and Integrations cases.
Extend `SettingsDestination` with a Modes subroute and make `SettingsPage`
apply it when selecting a search/deep-link destination.

**Verify**: extend navigation-state tests so root -> Assistant -> root and root
-> Integrations -> root each produce one 400pt side panel and correct back/Escape behavior.

### Step 2: Extract shell-free settings content

Split each current page into a root shell plus reusable content. Render content
inside a footerless `ModeEditorDrawer`; preserve immediate-write semantics,
capability toggles, Assistant preview start/stop cleanup, Integration editor
sheet, and advanced-script sheet. Keep one `.settingsSidePanel` host.

**Verify**: focused Assistant and Integration tests/previews show every current
group and exercise disable, preview teardown, edit, advanced edit, save, cancel,
and Escape.

### Step 3: Add two native drilldown rows

Add Assistant and Integrations rows to the Dictation Modes root using
`SettingsListDrillDownButtonRow`, in one clearly titled group after the mode
list and before the Add Mode bottom action. Do not use card chrome or extra
descriptive copy that duplicates the page introduction.

**Verify**: `make preview-check` -> root and both drawer families are present.

### Step 4: Remove visible sidebar entries and preserve legacy navigation

Remove `.assistant` and `.integrations` from primary/visible sidebar arrays and
direct detail-page switches. Keep their raw values as legacy redirects to
`.modes` with the matching subroute. Retarget all indexed keys to open the
correct drawer.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests && ./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` -> sidebar excludes both, legacy/search routes open the right drawer.

### Step 5: Validate lifecycle and Full lane

**Verify**: `make lint-strict && make preview-check && make validate-agent ARGS="--lane auto"` -> all pass; required review clears all Critical and Medium findings.

## Test plan

- Route/deep-link/search tests for both drawers.
- Assistant preview task/controller cleanup on close and capability disable.
- Integration editor -> advanced editor -> return chain, including Escape.
- Preview states for disabled/enabled/populated/error conditions.

## Done criteria

- [ ] Dictation Modes contains two drilldown rows.
- [ ] Each drawer exposes all controls from its former page.
- [ ] Sidebar and direct page switches no longer expose Assistant/Integrations.
- [ ] Legacy and search destinations open the matching drawer.
- [ ] Only one side-panel host exists and lifecycle tests pass.
- [ ] Full validation and review pass.

## STOP conditions

- Extracting content changes persistence from immediate to deferred.
- A nested integration sheet cannot restore the parent drawer correctly.
- Assistant preview resources remain active after drawer dismissal.

## Maintenance notes

- Search/deep-link state must remain a first-class route; do not simulate a row click.
- Keep drawer content shell-free for future Settings composition.

