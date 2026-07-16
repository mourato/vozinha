# Plan 107: Relocate Dictation settings into the mode drawer and retire the tab

> **Executor instructions**: Execute in order and update `plans/README.md`.
> Stop on the conditions below rather than inventing a new drawer pattern.
>
> **Drift check (run first)**:
> `git diff --stat 22794e18..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/ViewModels Packages/MeetingAssistantCore/Sources/Common/Resources`

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: MED
- **Depends on**: `plans/106-snapshot-mode-dictation-configuration.md`
- **Category**: direction
- **Planned at**: commit `22794e18`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — navigation removal depends on complete drawer coverage
- **Reviewer required**: yes — Full-lane UI/search review
- **Rationale**: One Settings subsystem changes, but draft semantics and legacy routes are user-visible contracts.
- **Escalate when**: Runtime behavior still reads a global moved setting or more than eight production source files beyond scope are needed.

## Why this matters

Each mode must own the two former Dictation groups, while the shortcut belongs
to app-level Settings. The old tab can disappear only after all behavior is
reachable and search/deep links remain safe.

## Current state

- `DictationSettingsTab.swift` contains Shortcut, Text Handling, and
  Transcription Model groups, all bound to immediate global view models.
- `DictationStyleEditorDetailView.swift` renders the existing saved/cancelled
  mode draft in `ModeEditorDrawer`; `ServiceTranscriptionProviderSection.swift`
  is not draft-safe because it writes through `ServiceSettingsViewModel`.
- `GeneralSettingsTab.swift:54` begins with `systemDrilldownsSection`; the
  shortcut group must be inserted immediately before it.
- `SettingsSection.swift` exposes `.dictation` and `.modes`; localization key
  `settings.section.modes` currently says Modes/Modos.
- `SettingsSearchRouteManifest.swift` sends shortcut, text, and model queries to
  the old Dictation page.
- Reuse `SettingsCheckboxRow`, native labeled `Picker`, `SettingsFormPage`, and
  `ModeEditorDrawer`. Drawer values remain deferred until Save/Create.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Navigation tests | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` | exit 0 |
| Search tests | `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` | exit 0 |
| Preview contract | `make preview-check` | exit 0 |
| Final gate | `make validate-agent ARGS="--lane auto"` | Full PASS |

## Suggested executor toolkit

- Use `macos-app-engineering`, `localization`, `testing-xctest`, and
  `delivery-workflow`.

## Scope

**In scope**:

- `UI/components/settings/{DictationStyleEditorDetailView,ServiceTranscriptionProviderSection,SettingsSection,SettingsSearchRouteManifest,SettingsSearchIndex,SettingsPreviewEvidenceCatalog}.swift`
- `UI/pages/settings/{SettingsPage}.swift`
- `UI/pages/settings/tabs/{DictationSettingsTab,GeneralSettingsTab,ModesSettingsTab}.swift`
- `UI/ViewModels/{DictationStylesSettingsViewModel,ShortcutSettingsViewModel}.swift`
- `Common/Resources/{en,pt}.lproj/Localizable.strings`
- `Tests/MeetingAssistantCoreTests/{DictationStylesSettingsViewModelTests,SettingsSectionTests,SettingsSearchIndexTests}.swift`

All relative paths above are below `Packages/MeetingAssistantCore/Sources` or
`Packages/MeetingAssistantCore` as appropriate.

**Out of scope**: Assistant/Integrations drawers (Plan 108), Dictionary
promotion (Plan 109), and runtime/persistence work (Plan 106).

## Git workflow

- Isolated branch/worktree: `codex/107-dictation-settings-drawer`.
- One writer; Conventional Commit example:
  `refactor(settings): move dictation options into mode drawer`.

## Steps

### Step 1: Make the mode editor draft own the controls

Extend `DictationStyleEditorDraft` bindings for Plan 106's two values. Extract
or replace `ServiceTranscriptionProviderSection` with a pure binding-driven
section; do not pass `ServiceSettingsViewModel` into the drawer. Normalize
provider/model choices in the draft and commit only on Save/Create.

**Verify**: extend `DictationStylesSettingsViewModelTests` for edit/cancel/save,
new-mode inheritance from default mode, and invalid model normalization;
`./scripts/run-tests.sh --suite dev --file DictationStylesSettingsViewModelTests` -> pass.

### Step 2: Add both groups in the established drawer

In `DictationStyleEditorDetailView`, use this order: Targets -> Behavior -> Text
Handling -> Transcription Model -> Context Sources -> Enhancements. Use four
`SettingsCheckboxRow` values and native labeled pickers. Preserve header,
scrolling, footer, Escape, and Command-Return behavior from `ModeEditorDrawer`.

**Verify**: add populated/default drawer previews and run `make preview-check` -> pass.

### Step 3: Move the shortcut group unchanged to Settings

Move `ShortcutSettingsViewModel`, `ShortcutSettingsSection`, capture-health
presentation, and `DSModifierShortcutEditor` composition into
`GeneralSettingsTab`. Place it after the page introduction and before the group
titled Settings. Do not duplicate copy or remove conflict/health behavior.

**Verify**: search the rendered source order with
`rg -n "ShortcutSettingsSection|systemDrilldownsSection" Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift` -> shortcut occurrence precedes drilldowns.

### Step 4: Remove the visible Dictation tab and rename Modes

Remove `.dictation` from visible/primary sections and the direct page switch,
but keep its raw enum value as a legacy redirect to `.modes`. Rename Modes to
“Dictation Modes” and “Modos de Ditado”. Delete `DictationSettingsTab.swift`
only after no production reference remains.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` -> expected primary order excludes Dictation and the legacy dictation destination resolves to Modes.

### Step 5: Retarget search and preview evidence

Route shortcut keys to `.system`, and former text/model keys to `.modes`.
Update preview inventory so no standalone Dictation page is required and the
new drawer states are represented.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests && make preview-check` -> pass.

### Step 6: Validate and review

**Verify**: `make lint-strict && make validate-agent ARGS="--lane auto"` -> Full PASS; required review has no Critical or Medium findings.

## Test plan

- Draft save/cancel/inheritance for all moved fields.
- Sidebar order, legacy `.dictation` redirect, renamed localization.
- Search routing split between app-level shortcut and mode-level fields.
- Drawer previews at default, populated, long localized copy, and reduced motion.

## Done criteria

- [ ] Every mode drawer edits both groups with deferred save/cancel semantics.
- [ ] Dictation Shortcut is the first Settings group.
- [ ] Dictation is absent from the sidebar and direct page switch.
- [ ] Modes displays as Dictation Modes in English and Portuguese.
- [ ] No production reference to `DictationSettingsTab` remains.
- [ ] Search, preview, lint, Full validation, and review pass.

## STOP conditions

- Plan 106 is incomplete or any moved control still changes a live global.
- The provider/model picker cannot be represented as a draft binding.
- Removing Dictation would make a currently indexed setting unreachable.

## Maintenance notes

- Preserve the legacy enum case for raw-value compatibility until a separate
  deprecation decision removes it.
- Reviewers should cancel a drawer edit and confirm no persisted value changes.

