# Plan 072: Align the mode trigger flow with the VoiceInk reference

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving to the next step. If a STOP condition is reached, stop and report it; do not improvise. This plan refines the trigger experience after the Modes drawer and fluid-group work are complete.
>
> **Drift check (run first)**: `git diff --stat 2fc835f8..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings/TriggerSelectionView.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: Plans 070 and 071
- **Category**: direction
- **Planned at**: commit `2fc835f8`, 2026-07-14

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: Medium/Full
- **Parallelizable**: no — trigger presentation edits the same draft and drawer routes.
- **Reviewer required**: yes — target exclusivity and normalization are behavior-sensitive.
- **Rationale**: This is a contained UI refinement with existing model contracts, but touches selection behavior.
- **Escalate when**: Adding keyboard shortcuts or new trigger types requires persistence/runtime matching changes.

## Why this matters

Plan 067 delivered a functional child route for apps and websites. The VoiceInk reference presents triggers as a compact section with a clear Add affordance and readable selected-target list. After Plan 070, the trigger flow should feel native inside the right-side drawer while preserving Prisma’s invariant that an app/site target belongs to only one non-default mode. This plan is limited to presentation and interaction quality for apps and websites.

## Current state

- `TriggerSelectionView.swift:89-141` renders app search and website add controls as separate sections.
- `TriggerSelectionView.swift:144-190` renders selected targets with remove buttons.
- `TriggerSelectionView.swift:192-232` filters apps by display name or bundle identifier and normalizes website input.
- `TriggerSelectionView.swift:270-301` adds/removes targets and validates conflicts before mutation.
- `DictationStyleEditorDetailView.swift:251-263` exposes the trigger child route through a drill-down row.
- `DictationStylesSettingsViewModel.swift` owns conflict lookup and draft persistence.
- `DictationStyle.swift` owns target identity/normalization and runtime target representation.

The screenshot also shows keyboard shortcuts and other trigger types, but this plan must not add them. Use the screenshot for hierarchy, affordance, and compactness only.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Model tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'` | all selected tests pass |
| Navigation tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests'` | all selected tests pass |
| Previews | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |

## Suggested executor toolkit

- Use `macos-app-engineering` and `swiftui-pro` for child-route and responsive-list layout.
- Use `benchmarking` to consult local VoiceInk reference code, treating it as inspiration rather than copy-paste code.

## Scope

**In scope**

- `TriggerSelectionView.swift`
- `DictationStyleEditorDetailView.swift` for the trigger summary row only.
- `ModesSettingsTab.swift` for route/header integration only.
- Existing target localization strings in English and Portuguese.
- Focused trigger/model tests and previews.

**Out of scope**

- New trigger types, keyboard shortcut recording, or automatic trigger engines.
- Changes to `DictationStyleTarget.matches` or persisted target shape.
- Changes to cross-mode exclusivity rules.
- Global settings components outside this trigger flow.

## Steps

### Step 1: Define the trigger summary and Add affordance

Keep one full-width Apps and Websites drill-down row in the parent editor. Its subtitle communicates no targets, one target, or a localized target count. Add a clear trailing affordance consistent with the drawer. Do not show a second full target editor inline in the parent.

**Verify**: `make preview-check` → editor preview shows the summary row at narrow and wide widths; existing mode tests pass.

### Step 2: Refine app search and selection

Keep case-insensitive search by app name and bundle ID, deterministic alphabetical ordering, icon/name/bundle ID, full-row selection, distinct selected/unavailable/conflicting states, and immediate conflict feedback. Preserve the rule that rejected additions do not mutate the parent draft. Prefer a compact full-width list over a fixed grid. Reuse `InstalledApplicationRecord`, `AppCatalogDiscovery`, and `AppIconView`.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests' && make preview-check` → both pass.

### Step 3: Refine website entry and selected-target list

Keep website normalization and duplicate prevention centralized through existing target identity rules. Stack the input and Add button at narrow widths. Render selected apps/sites in one consistent list with icon, primary label, secondary identifier/type, and removal action. Do not change accepted URL semantics without a model-level test and explicit product decision; if semantics are ambiguous, stop.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests'` → blank, duplicate, normalized, persisted, and conflict cases pass.

### Step 4: Integrate child route chrome

Use drawer header/footer conventions from Plan 070. The trigger child gets a back action and local Apply/Done only if the existing draft contract requires explicit confirmation. It must not duplicate Delete or global Save. Returning to the parent preserves temporary target selection until the parent is saved or canceled.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSubpageNavigationStateTests|DictationStylesSettingsViewModelTests'` → all selected tests pass.

### Step 5: Add accessibility and responsive previews

Add previews for empty, loading, search results, selected apps/sites, conflict error, and narrow width. Ensure the full result row is keyboard reachable and its accessible label includes identity and selected state.

**Verify**: `make preview-check && make build-agent` → both commands exit 0.

## Test plan

- Extend `AppSettingsDictationStylesTests` for identity, duplicate prevention, and cross-mode conflicts.
- Add pure filtering tests if filtering/normalization is extracted from the view.
- Add navigation tests for parent → triggers → parent with draft preservation.
- Verify no new trigger type or persistence field is introduced.

## Done criteria

- [x] Parent editor shows one concise Apps and Websites drill-down row.
- [x] Child route provides searchable, sorted, full-width app results with icons and identifiers.
- [x] Website input and selected-target rows adapt to narrow width.
- [x] Existing normalization, exclusivity, and persistence behavior is unchanged and tested.
- [x] Child route uses drawer conventions without duplicating Delete/Save.
- [x] Accessibility and responsive previews cover empty, loading, error, and populated states.
- [x] Focused tests, previews, and build pass.
- [x] `plans/README.md` status row is updated.

## STOP conditions

- Requirements expand to keyboard shortcuts or other trigger types.
- Target normalization or runtime matching must change to match the screenshot.
- The drawer cannot preserve temporary selection without changing persistence semantics.
- Conflict ownership cannot be represented clearly in the existing contract.
- Any verification fails twice after a reasonable correction.

## Maintenance notes

Keep target identity and conflict rules in the domain/view-model layer; the view only renders and collects intent. Future trigger types must define normalization, display, duplicate identity, conflict behavior, persistence, and runtime matching together before UI work begins.
