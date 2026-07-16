# Plan 106: Persist and snapshot dictation configuration per mode

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. Stop
> on any condition listed below; do not improvise. Update this plan's row in
> `plans/README.md` when complete unless the reviewer owns the index.
>
> **Drift check (run first)**:
> `git diff --stat 22794e18..HEAD -- Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionDeliveryService.swift`
> Compare every changed in-scope symbol with the current-state notes below.

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none
- **Category**: migration
- **Planned at**: commit `22794e18`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — persistence and runtime propagation share one contract
- **Reviewer required**: yes — Full-lane thermo-nuclear review is mandatory
- **Rationale**: This crosses persistence, transcription, concurrency, retry, and delivery boundaries.
- **Escalate when**: The solution needs a new public target dependency, touches audio callbacks, or exceeds eight production files beyond those listed here.

## Why this matters

Text handling and model controls are global today. Moving only their UI would
misrepresent actual behavior, and reading live settings after recording begins
can make one session change beneath the user. This plan makes the effective
mode the immutable source for transcription and delivery decisions.

## Current state

- `Infrastructure/Models/DictationStyle.swift:177` persists mode prompt,
  formatting, targeting, context, and enhancement fields, but no text-handling
  or transcription configuration.
- `AppSettingsStore/GeneralSettings.swift` owns global auto-copy/auto-paste;
  `AppSettings.swift` owns global smart spacing/paragraphs and dictation model
  selection; `TranscriptionModeSelection.swift` resolves those live globals.
- `AppSettingsStore/Initialization.swift` can bypass legacy-aware initialization
  by installing `defaultDictationStyles` when no modes key exists.
- `RecordingManager/RecordingManager.swift:145` snapshots context identifiers,
  not the effective mode configuration.
- `AI/Services/TranscriptionClient.swift` uses a mutable `selectionOverride` and
  global input language. Do not use that mutable next-call override as the
  normal session mechanism.
- `AI/Services/TranscriptionDeliveryService.swift` reads four booleans through
  `DeliverySettingsConfig` at delivery time.
- Existing mode `enhancementsSelection` is saved by the drawer, but the main
  transcription use case still resolves a global enhancement selection. Fix
  this existing propagation hole in the same snapshot.
- Conventions: value models are `Codable`, `Hashable`, and `Sendable`; use
  structured concurrency and keep local-first data local.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Targeted tests | `./scripts/run-tests.sh --suite dev --file AppSettingsDictationStylesTests` | exit 0, all selected tests pass |
| Runtime tests | `./scripts/run-tests.sh --suite dev --file TranscriptionDeliveryServiceTests` | exit 0 |
| Strict lint | `make lint-strict` | exit 0, no new warnings |
| Final gate | `make validate-agent ARGS="--lane auto"` | selects Full and exits 0 |

## Suggested executor toolkit

- Use `architecture`, `data-persistence`, `swift-concurrency-expert`,
  `testing-xctest`, and `delivery-workflow`.

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/{Initialization,LoadingHelpers,ContextWebTargets,ComputedProperties,Keys,AppSettings,GeneralSettings,TranscriptionModeSelection}.swift`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/DictationStylesSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/{RecordingManager,RecordingManagerStart,RecordingControl,RecordingManagerTranscriptionExecution,RecordingManagerTranscriptionPipeline,RecordingManagerIncrementalDictation,RecordingManagerIncrementalShared,Retry}.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/{RecordingManagerTranscriptionEntities,PostProcessing,PostProcessingPipeline}.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/PostProcessingConfigurationProvider.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/TranscriptionRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/{TranscriptionClient,LocalTranscriptionClient,TranscriptionDeliveryService,DeliverySettingsConfig}.swift`
- Matching tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`

**Out of scope**:

- Settings navigation or visible drawer controls (Plan 107).
- Assistant/meeting-specific model selection.
- Removing legacy UserDefaults keys before at least one release migration path exists.

## Git workflow

- Create an isolated worktree branch `codex/106-mode-dictation-snapshot`.
- One writing agent only. Use atomic Conventional Commits, for example
  `feat(modes): snapshot dictation configuration per mode`.
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Characterize legacy behavior before changing the schema

Extend `AppSettingsDictationStylesTests.swift` with fixtures for: no stored
modes, legacy modes with no new fields, multiple legacy modes, repeated loads,
and corrupt/unknown model identifiers. Assert that every legacy mode initially
preserves the old global text/model/language values.

**Verify**: `./scripts/run-tests.sh --suite dev --file AppSettingsDictationStylesTests` -> new tests fail only because the migration is not implemented.

### Step 2: Add compact per-mode value objects and an idempotent migration

Add `DictationTextHandlingPolicy` (copy, paste, smart spacing, smart
paragraphs) and `DictationTranscriptionConfiguration` (concrete provider/model
selection plus language hint) as small Sendable Codable values owned with
`DictationStyle`. Extend decoding without breaking old payloads. Add a schema
marker or equivalent idempotent migration that seeds **every** existing legacy
mode from current globals; new modes later inherit the default mode. Normalize
missing model IDs through the registry without silently changing a valid ID.
Update default-style construction and normalization so fields are never lost.

**Verify**: `./scripts/run-tests.sh --suite dev --file AppSettingsDictationStylesTests` -> all legacy, idempotence, and normalization cases pass.

### Step 3: Resolve the active mode once at recording start

Extend the recording session snapshot with the effective mode ID and immutable
text, transcription, language, context, formatting, and enhancement values.
Build it in `RecordingManagerStart.swift` from the captured bundle/URL and use
that same value through stop, full-file, incremental, retry, metrics, success,
and failure paths. Do not re-resolve a live mode after capture begins.

**Verify**: add focused RecordingManager/use-case tests proving that changing
the default or matched mode mid-session does not alter the active session;
`./scripts/run-tests.sh --suite dev --test testModeConfigurationIsStableDuringSession` -> pass.

### Step 4: Make transcription selection an explicit request value

Thread the snapshot's concrete provider/model and input-language values through
the use-case/repository/client boundary. Replace normal-session reliance on
`TranscriptionClient.selectionOverride`; retain it only for an explicitly
documented exceptional caller or remove it if no caller remains. Thread the
snapshotted `enhancementsSelection` through `makeUseCaseConfig` and
post-processing instead of resolving the global dictation enhancement setting.

**Verify**: add tests for two modes selecting different provider/model/language
and enhancement values across full and incremental transcription; run the new
test classes with `./scripts/run-tests.sh --suite dev --file <TestClass>` -> pass.

### Step 5: Deliver with the snapshotted text policy

Change delivery to accept an immutable text-handling value. Full, incremental,
and retry paths must use it for copy/paste/spacing/paragraph behavior. Keep a
compatibility adapter only where non-dictation callers still require globals.

**Verify**: `./scripts/run-tests.sh --suite dev --file TranscriptionDeliveryServiceTests` -> tests cover two different mode policies and mid-session global mutation; all pass.

### Step 6: Run the Full lane and review

Run strict lint, the canonical Full gate, then the required thermo-nuclear
review. Fix all Critical and Medium findings before completion.

**Verify**: `make lint-strict && make validate-agent ARGS="--lane auto"` -> Full lane selected and PASS evidence produced.

## Test plan

- Extend `AppSettingsDictationStylesTests` and
  `DictationStylesSettingsViewModelTests` for decode/migrate/inherit/save.
- Extend `TranscriptionDeliveryServiceTests` for immutable mode policy.
- Add focused tests for full-file, incremental, retry, model/language selection,
  invalid model fallback, and the existing per-mode enhancement selection.
- Assert the migration is idempotent and does not overwrite already customized
  per-mode values.

## Done criteria

- [ ] Every stored/new mode has explicit text and transcription values.
- [ ] Legacy values migrate to every legacy mode exactly once.
- [ ] A recording uses one immutable effective-mode snapshot in all paths.
- [ ] Main dictation no longer reads live global text/model/language/enhancement settings.
- [ ] Strict lint, targeted tests, Full validation, and required review pass.
- [ ] Only in-scope files and this ledger are modified.

## STOP conditions

- A provider/model cannot be represented by a stable persisted identifier.
- Incremental or retry flow cannot accept explicit configuration without a new
  cross-target public API not listed above.
- Migration would overwrite a mode that already contains new fields.
- The active mode can change intentionally during one recording; report the
  product rule conflict before proceeding.

## Maintenance notes

- Reviewers should trace one mode from decode -> start snapshot -> client ->
  post-processing -> delivery, not merely inspect the UI.
- Keep legacy globals only as migration/fallback inputs; Plan 107 removes their
  Dictation page controls.
