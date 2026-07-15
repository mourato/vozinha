# Plan 081: Migrate the complete System settings hierarchy to native Form sections

> **Executor instructions**: Execute after Plan 079. Use one isolated worktree.
> Cover System root plus Models, Dictionary, Sound, Permissions, and Protected
> Apps. Preserve route/search/state behavior and never use real audio hardware,
> Keychain, network, or model downloads in tests/previews.

> **Drift check (run first)**:
>
> ```bash
> git diff --stat a9a86350..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/AudioSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModelsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/PermissionsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/EnhancementsSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceSettingsContent.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/AIProviderIntegrationCard.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/EnhancementsProviderModelsPage.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests \
>   plans/README.md
> ```

## Status

DONE — implemented on `refactor/081-system-settings-form-sections`; focused tests, preview coverage, lint, build, and Full validation passed.

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/079-establish-single-form-settings-surface.md`
- **Category**: tech-debt
- **Planned at**: commit `a9a86350`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — routes share General, provider, model, and search components; only one writer is allowed.
- **Reviewer required**: `yes` — broad UI and provider/audio surfaces require thermo and visual review.
- **Rationale**: More than eight files across all System destinations; not Fast-lane work.
- **Escalate when**: Audio runtime, Keychain storage, model residency/downloads, persistence migrations, or route taxonomy must change.

## Why this matters

System is the deepest settings hierarchy and currently contains the widest mix
of `SettingsFormGroup`, `SettingsListGroup`, `DSGroup`, one-off `Form`, manual
label columns, and collection/status cards. Standardizing it proves the Form
contract across root and detail pages without erasing the distinct affordances
of model lists, dictionary entries, permission status, or protected-app lists.

## Current state and classification

- `SystemSettingsTab.swift:4-50` maps root, models, dictionary, sound,
  permissions, and protectedApps.
- `GeneralSettingsTab.swift:46-160,217-344` mixes custom lists with Appearance
  and Storage Forms. App Behavior and Recording Indicator are scalar settings
  and must convert. System drill-down lists remain navigation collections.
- `AudioSettingsTab.swift:58-189` mixes Forms with a custom Audio Processing
  group; device and feedback Forms contain composite VStacks/manual rows.
- `ServiceSettingsContent.swift:54-313` mixes local-model/status collections
  with cloud/runtime scalar Forms and fixed 100 pt label columns.
- `AIProviderIntegrationCard.swift:34-62` creates a one-off inner Form instead
  of participating in the page Form.
- `VocabularySettingsTab.swift:18-72` and `PermissionsSettingsTab.swift:32-85`
  are collection/status surfaces; retain their semantics while normalizing the
  page width/header/background contract.

Required classification:

| Convert to Sections | Retain as collection/status/navigation |
|---|---|
| App Behavior, Appearance, Recording Indicator, Storage | System destination drill-down rows |
| Audio format/devices/processing/feedback scalar rows | device choice collection inside its Section |
| cloud provider credentials/configuration and runtime settings | local model downloads, provider registration/model list, service status |
| protected-app enable/configuration toggles | protected-app list/search |
| dictionary edit fields when presented as settings | dictionary rules list |
| permission actions when editable | permission status/state blocks |

## Reuse -> extend -> create decision

- Reuse Plan 079 components, native rows, injected
  `GeneralSettingsAudioDeviceManaging`, existing view models, routes, search
  manifests, Keychain manager boundaries, and provider components.
- Extend provider/audio child components to emit Section-compatible rows; a
  child must not instantiate another Form.
- Retain list/status cards only for the right-hand column of the table.
- Do not create a second settings shell, provider abstraction, audio manager,
  credential store, model registry, or navigation route.

## Scope

**In scope**: all drift-check source files; narrowly related settings component
files revealed by direct calls; existing localized strings/previews/tests; plan
status/ledger.

**Out of scope**: Activity/primary/Modes pages; device discovery/runtime audio;
Keychain semantics; provider API calls; model downloads/residency; persistence
schema; System route taxonomy; redesign of collection row content.

## Commands

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'GeneralSettingsAppearanceTests|GeneralSettingsAudioDevicesTests|GeneralSettingsAudioProcessingTests|AppSettingsAudioDuckingTests|AISettingsViewModelTests|VocabularySettingsViewModelTests|SettingsSectionTests|SettingsSearchIndexTests|LocalizationKeyIntegrityTests'
make preview-check
make build-agent
make lint-agent
git diff --check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Expected: all focused tests pass with injected audio test doubles; no real
hardware/network/Keychain operation; final Full aggregate PASS.

## Git workflow

- Branch/worktree: `refactor/081-system-settings-form-sections` in one isolated worktree.
- Use buildable Conventional Commit slices: General, Sound, Models/providers, then Dictionary/Permissions/Protected Apps.
- Preserve unrelated changes and do not push, merge, or open a PR unless instructed.

## Steps

### Step 1: Preserve the route and create a route coverage matrix

Before changing views, enumerate each `SystemSettingsRoute` and its header,
Form/collection classification, preview state, and back behavior. Do not change
the enum or `SettingsPage` navigation.

**Verify**: `SettingsSectionTests` and `SettingsSearchIndexTests` pass.

### Step 2: Migrate General root

Use one Form page. Convert App Behavior, Appearance, Recording Indicator, and
Storage to Sections with visible native labels. Keep destination drill-downs as
native navigation rows/Section or a retained list surface, consistently aligned.
Preserve conditional indicator rows, cleanup dialogs, launch-at-login errors,
and cancel-shortcut validation.

**Verify**: General settings tests pass; narrow/wide previews cover indicator on/off and storage cleanup enabled/disabled.

### Step 3: Migrate Sound

Flatten Audio Format, Devices, Processing, and Feedback into Sections in one
Form. Replace manual dividers/fixed label columns with native rows where
possible. Preserve device modes, media handling, ducking, silence removal,
feedback preview, custom power source, and Reduce Motion transitions.

**Verify**: injected-device tests pass and no preview constructs a real hardware discovery session.

### Step 4: Migrate Models/provider scalar configuration

Make one page Form own provider credentials/configuration and runtime scalar
Sections. Change `AIProviderIntegrationCard` and service child views to emit
rows/Sections, not nested Forms. Use visible `Picker`/`LabeledContent`; remove
ordinary `.labelsHidden()` and 100 pt label columns. Retain model download,
registration, and service status collections as composed Section content.

**Verify**: provider/model previews use fakes, show empty/loading/error/configured states, and never expose credentials in logs or snapshots.

### Step 5: Normalize Dictionary, Permissions, and Protected Apps

Do not mechanically turn collection/status cards into scalar Forms. Ensure each
page has one vertical scroll owner, consistent header/gutters, full-width outer
surface, and no redundant white card around its collection. Editable scalar
controls belong in Sections; list rows retain selection/add/delete/status
affordances.

**Verify**: dictionary, permissions, search, empty, and populated previews align at 600/900/1200 pt.

### Step 6: Complete behavioral and visual validation

Exercise every System route, back navigation, search deep link, light/dark,
Dynamic Type, Reduce Transparency, disabled/error/loading/empty states. Run the
focused tests and Full gate once the visual review is clean.

## Test plan

- General: appearance values, launch-at-login error, indicator conditional
  rows, shortcut interval validation, storage cleanup enabled/disabled/error.
- Sound: default/custom input, unavailable device, media handling, ducking,
  silence removal, feedback preview, and injected no-device state.
- Models: empty/loading/error/configured provider, runtime selection, local
  model/status collections, and redacted credential fields.
- Dictionary/Permissions/Protected Apps: empty/populated/error/status and
  add/edit/delete/open-System-Settings actions using existing fakes.
- Route/search tests must cover every `SystemSettingsRoute` and legacy redirect.

## Done criteria

- [x] Every System destination has one vertical scroll owner.
- [x] Scalar configuration uses one Form with Sections; no nested/per-group Forms.
- [x] All Section bounds align at 600/900/1200 pt.
- [x] No main-page maximum width, ordinary hidden label, or fixed label column remains.
- [x] Collection/status exceptions retain behavior without redundant outer white cards.
- [x] Routes/search, audio-test-double, provider, vocabulary, and localization tests pass.
- [x] Full gate and required reviews pass.

## STOP conditions

- A preview/test touches real hardware, network, Keychain, or model download.
- A container refactor requires changing provider/audio/persistence behavior.
- Native Form cannot preserve collection selection/edit/status affordances.
- Any route/search contract must change.

## Maintenance notes

Reviewers must distinguish scalar settings from collections/status. Native Form
is the default for the former, not a mandate to flatten every rich list.
