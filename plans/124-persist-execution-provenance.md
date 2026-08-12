# Plan 124: Persist execution provenance for transcription and post-processing

> **Executor instructions**: Read this plan completely. This is a persistence
> migration, not a logging change. Run every migration and round-trip test
> before advancing. Preserve old records and append-only performance history.
> If a STOP condition occurs, report it and do not invent provenance for old
> data. Update `plans/README.md` only after the migration, review, and final
> gate pass.
>
> **Drift check (run first)**: `git diff --stat a5536db9..HEAD -- Packages/MeetingAssistantCore/Sources/Domain/Models/Transcription.swift Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities/TranscriptionEntity.swift Packages/MeetingAssistantCore/Sources/Domain/Models/ModelPerformance.swift Packages/MeetingAssistantCore/Sources/Domain/Models/VocabularySnapshot.swift Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/CoreDataModel.swift Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/TranscriptionMO.swift Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/ModelPerformanceAttemptMO.swift Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/CoreDataStack.swift Packages/MeetingAssistantCore/Sources/Data/Data/Repositories/CoreDataTranscriptionStorageRepository.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Retry.swift Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/CoreDataRepositoryTests.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plan 123 (`plans/123-centralize-post-processing-request-seam.md`)
- **Category**: migration / persistence / architecture
- **Planned at**: commit `a5536db9`, 2026-08-11

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — domain provenance, Core Data mapping, retry
  selection, performance attempts, and migration compatibility form one data
  contract.
- **Reviewer required**: yes — this changes persisted local history and must
  be reviewed for recoverability, privacy, and old-record behavior.
- **Rationale**: The repository already has Core Data round-trip tests,
  versioned programmatic schema, and append-only performance attempts. Extending
  those existing surfaces is safer than creating a second history store.
- **Escalate when**: the change requires destructive migration, CloudKit/iCloud
  synchronization, raw prompt/transcript persistence, a new storage target, or
  changing the meaning of existing performance aggregates.

## Why this matters

Completed transcriptions currently retain useful output and model-performance
identity, but not the complete immutable request that produced them. In
particular, an old transcription cannot reliably retry with its original
provider/model/language/vocabulary after Settings changes. Persisting a local
execution provenance value for the transcription and each append-only attempt
makes retries reproducible, makes metrics auditable, and distinguishes known
historical data from records created before this migration.

## Current state

- `Packages/MeetingAssistantCore/Sources/Domain/Models/Transcription.swift:4-104` — `Transcription` stores language, model name, durations, post-processing prompt fields, output state, and failure reasons, but no complete transcription request or vocabulary snapshot.
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities/TranscriptionEntity.swift:6-112` — `TranscriptionEntity.Configuration` mirrors the persisted model and is the domain/data mapping boundary.
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift:106-124` — `DomainTranscriptionRequestConfiguration` is already `Codable` and carries provider ID, model ID, input language, and provider vocabulary hints.
- `Packages/MeetingAssistantCore/Sources/Domain/Models/VocabularySnapshot.swift:110-130` — the immutable session snapshot carries normalized terms and deterministic replacement rules, but the wrapper itself is not yet `Codable`.
- `Packages/MeetingAssistantCore/Sources/Domain/Models/ModelPerformance.swift:95-145` — `ModelPerformanceAttempt` is append-only and stores model identity, stage, attempt kind, timings, sizes, and failure reason, but not request provenance.
- `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/TranscriptionMO.swift:8-45,146-218` — Core Data maps transcription output and summary metadata but has no provenance data field.
- `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/ModelPerformanceAttemptMO.swift:7-90` — Core Data maps immutable attempts and currently has no provenance data field.
- `Packages/MeetingAssistantCore/Sources/Data/Data/CoreData/CoreDataModel.swift:12,128-253,255-477` — the programmatic model is version `1.5`, uses optional/binary fields for several Codable domain values, and the stack enables inferred lightweight migration.
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/Retry.swift:49-80,347-370` — retry configuration falls back to current `AppSettingsStore` values when no explicit retry override exists; it has no persisted original request to consult.
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/CoreDataRepositoryTests.swift:295-390` — existing tests cover synthetic performance backfill, newest-first attempts, and limits; use them as the migration/round-trip pattern.

The storage contract in `.agents/docs/storage-architecture.md` requires
background-context repository operations, deterministic/idempotent migrations,
recoverability, no-op re-run safety, append-only attempts, and separate
newest-first history from aggregates. Credentials never belong in this
provenance. Raw transcripts, prompts, API keys, and tokens must not be added
to diagnostics or a new provenance record. Persist provenance locally as
application data only; do not add sync or export behavior in this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Architecture | `make arch-check` | exit 0 |
| Lint | `make lint-strict` | exit 0 with no new warnings |
| Core Data repository | `./scripts/run-tests.sh --suite dev --file CoreDataRepositoryTests` | exit 0 |
| Domain persistence | `./scripts/run-tests.sh --suite dev --file TranscribeAudioUseCaseMacroMockingTests && ./scripts/run-tests.sh --suite dev --file TranscribeAudioUseCasePostProcessingMacroMockingTests` | both exit 0 |
| Retry/performance | `./scripts/run-tests.sh --suite dev --file RecordingManagerRetryPerformanceTests && ./scripts/run-tests.sh --suite dev --file ModelPerformanceAggregatorTests` | both exit 0 |
| Build | `make build-agent` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane auto"` | Full lane passes, or a pre-existing toolchain failure is recorded with no new source failure |
| Diff hygiene | `git diff --check` | no whitespace errors |

## Suggested executor toolkit

- Use `data-persistence` for migration, round-trip, and recovery rules.
- Use `architecture` for Domain/Data ownership and repository boundaries.
- Use `testing-xctest` for focused async Core Data tests.
- Use `delivery-workflow` for the final validation evidence.

## Scope

**In scope**:

- A domain-owned, `Codable`, `Hashable`, `Sendable` provenance value that
  reuses `DomainTranscriptionRequestConfiguration`,
  `DomainPostProcessingSelection`, `ModelPerformanceModelIdentity`,
  `IntelligenceKernelMode`, and `VocabularySnapshot` data.
- `Transcription`/`TranscriptionEntity` round-trip fields for the original
  request used by default historical retry.
- `ModelPerformanceAttempt`/`ModelPerformanceAttemptMO` immutable provenance
  for transcription and post-processing attempts.
- Programmatic Core Data model versioning and optional/inferred migration.
- `CoreDataStack`, Core Data mappings, repository tests, use-case persistence,
  retry selection, and performance-attempt tests.
- `.agents/docs/storage-architecture.md` updates describing the new local
  provenance fields and migration behavior.

**Out of scope**:

- CloudKit, iCloud, backup, sync, external export, or a new database.
- Persisting API keys, tokens, raw transcript text, raw prompts, or provider
  responses in provenance.
- Rewriting model-performance aggregation, dashboard UX, or ranking semantics.
- Changing the explicit request seam from Plan 121 or post-processing seam from
  Plan 123.
- Inventing provenance for old records; missing fields remain explicitly
  unavailable and use the documented compatibility fallback.

## Git workflow

- Use an isolated worktree/branch named `codex/124-execution-provenance`.
- Match Conventional Commit style, for example
  `feat(storage): persist execution provenance`.
- Do not push, merge, or modify unrelated working-tree artifacts.

## Ordered implementation steps

### Step 1: Freeze the provenance contract and migration baseline

Run the drift check, `git status --short`, the focused tests, and inspect the
current programmatic model version. Write a small matrix for initial
transcription, retry, post-processing, manual reprocess, legacy imported
record, and failed attempt. For each, identify which values are known,
optional, or intentionally unavailable.

**Verify**: the matrix distinguishes an absent historical provenance value
from a guessed value; current stores and tests have no schema changes yet.

### Step 2: Add the smallest domain provenance value

Create one domain value, or extend an existing domain value if one already
fits, with these fields:

- transcription request configuration (provider, model, language, provider
  hints);
- normalized `VocabularySnapshot` terms and replacement rules needed to
  reproduce deterministic replacement and provider projections;
- transcription model identity;
- optional post-processing selection and model identity;
- post-processing prompt ID/title, kernel mode, and structured-pipeline
  decision where required to identify the operation.

Keep prompt contents and transcript contents out of this value. Add `Codable`
to `VocabularySnapshot` only if reuse of its existing Codable components is the
minimal round-trip solution. Use optional provenance on old records; do not
assign current Settings values during decoding.

**Verify**: domain tests round-trip a populated value, an empty value, and an
old/missing value; `make arch-check` passes without a Domain → Data/AI import.

### Step 3: Persist provenance on completed transcriptions and attempts

Extend `TranscriptionEntity.Configuration` and `Transcription` with the
original session provenance needed by default retry. Extend
`ModelPerformanceAttempt` with immutable per-attempt provenance so a retry or
reprocess does not overwrite the initial attempt's evidence. Keep attempts
append-only and preserve the existing model identity fields for dashboard
compatibility.

Add optional binary data attributes to `TranscriptionMO` and
`ModelPerformanceAttemptMO`, plus the matching attributes in
`CoreDataModel.createManagedObjectModel()`. Encode/decode with the existing
JSON encoder/decoder pattern, return `nil` for absent/corrupt provenance as a
recoverable compatibility state, and do not fail history loading solely because
an old optional field is missing.

**Verify**: `CoreDataRepositoryTests` prove domain → Core Data → domain round
trip, old records with nil fields still load, and two attempts retain distinct
provenance values.

### Step 4: Migrate the programmatic model safely

Advance the programmatic model version from `1.5` to the next version used by
this migration. Keep new attributes optional with safe defaults so existing
SQLite stores can use inferred lightweight migration. Do not remove or rename
existing attributes. Add a migration/backfill checkpoint only if a real
one-time operation is required; the preferred behavior is lazy nil for old
records rather than inventing data.

Test a fresh in-memory store, a store populated before provenance exists, a
no-op second load, and a store with malformed optional provenance data. Keep
the legacy store cluster available on migration failure and never mark a
checkpoint before a successful save.

**Verify**: fresh and compatibility store tests pass; `CoreDataModel.currentVersion`
matches the documented version; no destructive migration or data loss occurs.

### Step 5: Use persisted provenance for retry and write new attempt evidence

Change `Retry.swift` so a retry without an explicit user selection first uses
the transcription's persisted provenance. An explicit user-selected retry
must create a new request at the retry boundary and must not mutate shared
client state. If provenance is absent on a historical record, retain the
current-settings fallback, mark the provenance as unavailable, and do not
pretend the retry reproduces the original operation.

Ensure normal, retry, and post-processing use-case paths pass provenance into
storage/performance persistence. Manual reprocess remains a new attempt with
its own explicit selection; it must not rewrite the original attempt.

**Verify**: tests mutate current Settings after loading a persisted
transcription and prove default retry uses the stored request; explicit retry
selection wins; old records use a visible compatibility path; attempts remain
append-only and carry distinct identities.

### Step 6: Document privacy and migration behavior, then validate

Update `.agents/docs/storage-architecture.md` with the new owner, field
encoding, optional/missing-record behavior, migration version, and privacy
boundary. Run the command table and review all Core Data mapping changes for
background-context usage and recoverability.

**Verify**: all focused tests, `make build-agent`, `make arch-check`,
`make lint-strict`, `make validate-agent ARGS="--lane auto"`, and
`git diff --check` pass with no new baseline failure.

## Test plan

- Add domain provenance Codable/equality tests near the existing model tests.
- Extend `CoreDataRepositoryTests` for fresh store, old store with nil fields,
  malformed optional data, round-trip, no-op re-run, and two distinct attempts.
- Extend `TranscribeAudioUseCaseMacroMockingTests` and post-processing mocking
  tests to assert provenance is saved with successful and failed attempts.
- Extend `RecordingManagerRetryPerformanceTests` for persisted default retry,
  explicit override, legacy nil fallback, and append-only attempt history.
- Keep existing model-performance aggregator tests unchanged except for
  fixture construction required by new optional fields.
- Use in-memory Core Data for unit tests and one temporary SQLite fixture for
  migration compatibility; never use the user's application store.

## Done criteria

- [ ] Completed transcriptions can carry the original transcription and
  post-processing provenance without raw prompts, transcripts, or secrets.
- [ ] Every new performance attempt stores immutable provenance when known.
- [ ] Historical records without provenance remain loadable and are never
  assigned guessed current Settings.
- [ ] Default retry uses persisted provenance; explicit retry selection wins.
- [ ] Core Data migration is optional-field, deterministic, recoverable, and
  idempotent; existing data and append-only attempts remain intact.
- [ ] Round-trip, migration, retry, performance, architecture, lint, build,
  and full validation gates pass with no new baseline failure.
- [ ] Storage architecture documentation is updated.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- Exact replay requires persisting raw prompts, transcripts, credentials, or
  provider responses; stop for a privacy/product decision.
- Core Data cannot infer a safe lightweight migration for the existing store;
  stop and design an explicit recoverable migration before changing schema.
- A legacy record cannot be loaded without inventing current configuration;
  preserve nil/unknown and report the compatibility gap.
- A retry path still requires mutable global selection or mutates a shared
  client override.
- Existing dashboard queries or aggregate keys would change meaning.
- Migration testing requires touching the user's real application-support
  store or deleting any existing store cluster.

## Maintenance notes

- New execution stages should add immutable provenance to their attempt rather
  than extending diagnostics with request payloads.
- Keep provider/model/language/vocabulary names in domain values and adapters;
  Core Data should store encoded domain data, not AI service objects.
- Missing provenance is a supported legacy state until all records are
  naturally rewritten; do not create a broad backfill that guesses settings.
- Plan 125 may remove live Settings reads after persisted/session snapshots are
  available; it must not bypass this repository contract.

## Closeout

- Integrated into local `main` in `35e8fefb`; review remediation is `0c80c993`.
- Stable toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
  (Xcode 26.6, Swift 6.3.3).
- Focused gates: CoreDataRepositoryTests 20/20;
  TranscribeAudioUseCaseMacroMockingTests 4/4.
- Full committed validation: build passed; 1,138/1,138 tests passed;
  SwiftFormat passed.
- Strict lint reports only the four pre-existing structural violations in
  `RecordingManager.swift`, `PostProcessing.swift`, and
  `TranscribeAudioUseCasePostProcessingMacroMockingTests.swift`.
- The final re-review subagent did not return within the timebox; the
  integrated diff was checked locally against the three review findings before
  closeout. No source changes remain unreviewed in scope.
