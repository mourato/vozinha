# Plan 080: Migrate primary settings journeys to shared native Form sections

> **Executor instructions**: Execute only after Plan 079 is DONE. Read every
> in-scope file before editing. Work in one isolated worktree and preserve all
> bindings, navigation, draft, validation, sheets, localization, and capability
> disabled states. Do not convert data collections into scalar Form rows.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat a9a86350..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/DictationSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AssistantSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/IntegrationsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/ShortcutSettingsSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceTranscriptionProviderSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceMeetingTranscriptionSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/AssistantIntegrationsSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SpeakerIdentificationSettingsSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab/MeetingSettingsWebTargets.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests \
>   plans/README.md
> ```

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/079-establish-single-form-settings-surface.md`
- **Category**: tech-debt
- **Planned at**: commit `a9a86350`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — the primary routes share shortcut, model-routing, and capability components.
- **Reviewer required**: `yes` — broad SwiftUI change; thermo review must clear Critical/Medium findings and visual review must cover all nested routes.
- **Rationale**: More than eight UI/test files and several shared components; normal implementer only.
- **Escalate when**: Persistence, model runtime, shortcut capture, meeting detection, export semantics, or integration execution must change.

## Why this matters

The four primary journeys mix native Forms with `SettingsListGroup` and
`DSGroup`, producing different widths, white/material backgrounds, separators,
and accessibility semantics in one viewport. This plan converts scalar
configuration rows to the Plan 079 single-Form/Section contract while retaining
collection editors where their interaction is not Form-like.

## Current state and required classification

| Journey | Convert to native Sections | Retain as composed collection/editor |
|---|---|---|
| Dictation | shortcut controls, Text handling toggles, transcription routing | shortcut capture health block inside its Section |
| Meetings root | shortcut, Workflow, transcription, intelligence, speaker ID, typography | none of these may remain a white card |
| Meeting subroutes | Export and Prompts scalar controls | monitored apps/sites lists, prompt collection, template editor sheet |
| Assistant | shortcut and visual feedback scalar controls | composed screen-border preview where necessary |
| Integrations | capability/configuration toggles and editor fields | integration collection and script editor results |

Evidence:

- `DictationSettingsTab.swift:29-80` mixes shortcut `DSGroup`, Text handling
  `SettingsListGroup`, and a `SettingsFormGroup`.
- `MeetingSettingsTab.swift:110-246` interleaves all three group primitives.
- `MeetingSettingsTab.swift:317-464` puts entire subpages in a single `VStack`
  row inside standalone Forms and manually inserts dividers.
- `AssistantSettingsTab.swift:88-172` makes visual feedback one composite Form row.
- `ServiceTranscriptionProviderSection.swift:17-68` hides labels and hardcodes
  100 pt label columns rather than letting Form align rows.
- `IntegrationsSettingsTab.swift:23-87` owns two editor sheets; those behaviors
  must survive the container change.

## Reuse -> extend -> create decision

- Reuse `SettingsFormPage`, `SettingsFormSectionHeader`, native `Section`,
  `Picker`, `Toggle`, `LabeledContent`, `SettingsListDrillDownButtonRow`, and all
  existing view models/bindings.
- Extend shared section components so they emit Section-compatible content; do
  not let a child create another Form.
- Retain `DSGroup`/list surfaces only for collections named in the table.
- Do not create new view models, duplicate bindings, new navigation routes, or
  a second shortcut/model/integration component.

## Scope

**In scope**: the files in the drift check, existing previews for those files,
localized strings only if visible copy must be preserved/rekeyed, and this
plan/ledger status.

**Out of scope**: Activity/System/Modes routes; shortcut persistence/capture;
meeting detection/export behavior; AI model selection logic; speaker runtime;
integration execution/security; prompt data model; VoiceInk source.

## Commands

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'ShortcutSettingsViewModelTests|MeetingSettingsNavigationStateTests|AutoMeetingConfirmationSettingsTests|AssistantShortcutSettingsViewModelTests|IntegrationSettingsViewModelTests|SettingsSearchIndexTests|LocalizationKeyIntegrityTests'
make preview-check
make build-agent
make lint-agent
git diff --check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Expected: all selected tests pass; preview inventory/build/lint/diff checks exit
0; final aggregate status is PASS. Do not describe `preview-check` as rendering
or compiling previews.

## Git workflow

- Branch/worktree: `refactor/080-primary-settings-form-sections` in one isolated worktree.
- Commit logical, buildable slices with Conventional Commits; recommended split: Dictation, Meetings, then Assistant/Integrations.
- Do not push, merge, or open a PR unless instructed; update only this plan row after review/gates.

## Steps

### Step 1: Migrate Dictation as the first production exemplar

Use one `SettingsFormPage`. Make shortcut, Text handling, and transcription
routing native Sections. Replace simple `DSToggleRow` wrappers with native
labelled toggles appropriate to a saved settings Form; preserve help text and
bindings. Remove fixed label columns and ordinary `.labelsHidden()` use.

**Verify**: Dictation preview at 600/900/1200 pt has one scroll bar, aligned
Section guides, no centered group, and all four text-handling bindings work.

### Step 2: Migrate Meetings root and its scalar components

Put shortcut, Workflow, meeting transcription, intelligence, speaker ID, and
typography in the same page Form as separate Sections. Flatten unnecessary
VStacks so native rows own separators. Drill-down rows must still navigate to
monitoring, Export, and Prompts. Capability disabled opacity/toggle remains at
the page content boundary.

**Verify**: `MeetingSettingsNavigationStateTests` pass; navigate root -> each
subroute -> back/forward without losing state.

### Step 3: Migrate Export and Prompts subpages

Each subpage gets exactly one Form. Export retains conditional location,
template, safety policy, validation message, and editor sheet. Prompts retains
language, autodetect, create/edit list, and enabled-state behavior. Collections
may be custom row content inside a Section; do not wrap them in a second card.

**Verify**: expanded/collapsed and enabled/disabled previews align at all widths.

### Step 4: Migrate Assistant and Integrations

Make scalar controls native Sections and visible labelled rows. Keep integration
collections/editors composed, but remove any white outer card used only because
the old group primitive required it. Preserve sheet transactions and script
test result behavior.

**Verify**: assistant/integration focused tests pass; open/save/cancel/delete
editor paths behave exactly as before.

### Step 5: Run route-wide visual and behavioral review

Inspect light/dark, 600/900/1200 pt, accessibility text, capability disabled,
conditional expanded, empty, error, and loading states. Compare section anatomy
to the pinned VoiceInk pattern without copying styling or its 400 pt drawer.

## Test plan

- Dictation: all four text-handling bindings; shortcut validation state;
  provider local/cloud selection, loading, error, and configured states.
- Meetings: root plus monitoring/export/prompts route history; capability off;
  export disabled/enabled/missing-folder/template; prompt disabled/enabled.
- Assistant: capability off/on, shortcut conflict, and every visual-feedback
  conditional control.
- Integrations: empty/populated list and editor save/cancel/delete/advanced
  transitions without executing a real script.
- Model tests after the named existing XCTest classes; add view-model tests only
  when a container extraction exposes new pure behavior. Do not add snapshots.

## Done criteria

- [ ] Each primary root/subpage has exactly one vertical scroll owner.
- [ ] Scalar groups are native Sections in one page Form.
- [ ] No standalone `SettingsFormGroup` remains in in-scope product files.
- [ ] No ordinary picker hides its label or uses a fixed 100 pt label column.
- [ ] Retained collections are explicitly those listed above and have no extra outer white card.
- [ ] Navigation, persistence, disabled states, sheets, and localization tests pass.
- [ ] Full gate and required reviews pass.

## STOP conditions

- A migration changes a persisted value or introduces a second binding owner.
- A collection must be flattened in a way that loses selection/edit/delete semantics.
- Hardware, network, Keychain, model runtime, or script execution is triggered by a preview/test.
- More than the named journey/component files are required.

## Maintenance notes

Future scalar settings added to these journeys belong in the existing page Form
as a Section row. Collection editors may remain composed but must not introduce
their own scroll owner or card solely for background styling.
