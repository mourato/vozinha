# Plan 125: Reduce operation-time coupling to AppSettingsStore.shared

> **Executor instructions**: Read this plan completely. This is the final
> plan in the current architecture sequence and depends on the explicit
> request, lifecycle, and provenance boundaries already being stable. Work in
> small classified slices. Do not attempt a repository-wide singleton purge.
> If a STOP condition occurs, report it instead of creating a mega-settings
> service. Update `plans/README.md` only after the final review and gate.
>
> **Drift check (run first)**: `git diff --stat a5536db9..HEAD -- Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService Packages/MeetingAssistantCore/Sources/AI/Services/LocalTranscriptionClient.swift Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionDeliveryService.swift Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/ConversationAndPostProcessing.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: Plans 122, 123, and 124
- **Category**: tech-debt / dependency-boundary migration
- **Planned at**: commit `a5536db9`, 2026-08-11

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — the remaining Settings reads cross recording,
  post-processing, retry, local transcription compatibility, delivery, and
  persisted provenance.
- **Reviewer required**: yes — the goal is selective dependency inversion,
  not merely replacing one singleton with another.
- **Rationale**: Plans 122–124 create the operation/session/persistence
  boundaries needed to remove live global reads safely. The narrowest change
  is to migrate only operational paths and keep UI, composition-root, health,
  and legacy compatibility reads where they are semantically appropriate.
- **Escalate when**: the work needs a new global settings abstraction, changes
  UserDefaults keys/migrations, changes public target dependencies, or cannot
  classify a `.shared` read as operation, UI, readiness, composition root, or
  legacy compatibility.

## Why this matters

`AppSettingsStore.shared` is convenient at the composition root but hides
dependencies inside operational services. A service can therefore change its
behavior when Settings mutate during a recording, retry, post-processing
request, or delivery operation, and tests must manipulate global state to
control it. After Plans 122–124 provide lifecycle snapshots, explicit
post-processing requests, and persisted provenance, the remaining operation
reads can be moved to the edge while preserving legitimate UI, readiness,
startup, and legacy fallback behavior.

## Current state

The codebase already has useful narrow values and providers to reuse:

- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManager.swift:110,319-373` — `PostProcessingConfigurationProvider` is already injectable; the manager also has a large initializer/composition surface where operation dependencies can be supplied.
- `RecordingManager/RecordingManagerTranscriptionPipeline.swift:77,144-148` — normal finalization reads Settings for auto-export and post-processing configuration even though the session already owns transcription values.
- `RecordingManager/RecordingManagerIncrementalShared.swift:255-258` — incremental finalization reconstructs post-processing configuration from live Settings.
- `RecordingManager/Retry.swift:73-76,297,347-368` — retry reads current language, vocabulary, post-processing identity, provider selection, and dictation configuration; Plan 124 should make the persisted request the default source.
- `RecordingManager/PostProcessingPipeline.swift:76-139` — direct post-processing resolves live enabled/readiness/selection state before calling the AI service.
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift:9-18,152-177` — the adapter stores `settings = .shared` and resolves selected prompts on compatibility paths.
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/PostProcessingService.swift:48-53` and its `LegacyAPI.swift`/`StructuredAPI.swift` helpers — the service owns a live Settings reference and uses it to resolve request configuration in legacy routes.
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/ConversationAndPostProcessing.swift:257-323` — manual reprocess resolves performance identity, model, structured choice, and service singleton directly.
- `Packages/MeetingAssistantCore/Sources/AI/Services/LocalTranscriptionClient.swift:52-55,106-110,161-166` — language and diarization use Settings only when an explicit request is absent or the compatibility fallback is enabled.
- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionDeliveryService.swift:17-20` — delivery already accepts a narrow `DeliverySettingsConfig` value with a `.shared` default; this is a model for edge injection, not a reason to create a general settings service.
- `RecordingManager.swift:230-234,386-388` and automatic-recording/status helpers — startup, UI/context policy, health, and readiness reads are not all operation-time coupling and must be classified before changing.

The project rule is to resolve configuration at the operation edge and pass
immutable domain values inward. Reuse existing `DictationTranscriptionConfiguration`,
`DomainTranscriptionRequestConfiguration`, `VocabularySnapshot`,
`PostProcessingConfigurationProvider`, `DeliverySettingsConfig`, and
`ModelResidencyTimeoutSettingsProviding`. Do not introduce a catch-all
`SettingsService` or pass `AppSettingsStore` into Domain/AI code when a narrow
value or provider is sufficient.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Settings-read inventory | `rg -n "AppSettingsStore\\.shared" Packages/MeetingAssistantCore/Sources` | every result is classified and any remaining result belongs to the documented allowlist |
| Architecture | `make arch-check` | exit 0 |
| Lint | `make lint-strict` | exit 0 with no new warnings |
| Recording/settings tests | `./scripts/run-tests.sh --suite dev --file RecordingManagerTests && ./scripts/run-tests.sh --suite dev --file RecordingManagerTranscriptionTests` | both exit 0 |
| Post-processing tests | `./scripts/run-tests.sh --suite dev --file PostProcessingServiceValidationTests && ./scripts/run-tests.sh --suite dev --file TranscribeAudioUseCasePostProcessingMacroMockingTests` | both exit 0 |
| Persistence/retry tests | `./scripts/run-tests.sh --suite dev --file CoreDataRepositoryTests && ./scripts/run-tests.sh --suite dev --file RecordingManagerRetryPerformanceTests` | both exit 0 |
| Build | `make build-agent` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane auto"` | Full lane passes, or a pre-existing toolchain failure is recorded with no new source failure |
| Diff hygiene | `git diff --check` | no whitespace errors |

## Suggested executor toolkit

- Use `architecture` for dependency direction and composition-root decisions.
- Use `data-persistence` when the source of a retry setting changes from live
  Settings to persisted provenance.
- Use `swift-conventions` and `delivery-workflow` for source and validation.

## Scope

**In scope**:

- Operation-time Settings reads in RecordingManager transcription,
  incremental finalization, retry, post-processing, and delivery paths.
- Explicit-route Settings reads in `PostProcessingService`,
  `PostProcessingRepositoryAdapter`, `LocalTranscriptionClient`, and manual
  reprocess.
- Narrow initializer/provider injection and test doubles for the migrated
  paths.
- Tests and a short update to the relevant architecture/storage maintenance
  notes if the allowlist or composition-root rule changes.

**Out of scope**:

- A repository-wide removal of `AppSettingsStore.shared`.
- Settings UI, `AppSettingsStore` key names, UserDefaults migration, or mode
  persistence.
- Composition-root defaults that intentionally construct the app with
  `.shared`.
- Readiness/health checks, previews, settings view models, and user-facing
  settings display when they are not part of an in-flight operation.
- Legacy/imported-file compatibility routes that intentionally use a default
  only when no explicit request exists; keep those edges visible and tested.
- New target dependencies, a mega-settings DTO, or a provider registry.

## Git workflow

- Use an isolated worktree/branch named `codex/125-settings-boundary`.
- Match Conventional Commit style, for example
  `refactor(settings): inject operation configuration`.
- Do not push, merge, or absorb unrelated working-tree changes.

## Ordered implementation steps

### Step 1: Inventory and classify every remaining singleton read

Run the inventory command and inspect every production result. Classify each
read as one of:

1. operation input or decision;
2. readiness/health observation;
3. composition-root/startup wiring;
4. UI/settings presentation;
5. legacy/imported-file compatibility.

Only category 1 is an automatic migration target. For category 2–5, record
why the live read is correct and what test protects it. Compare the inventory
with the explicit seams and provenance from Plans 122–124 before editing.

**Verify**: a checked-in implementation note or plan handoff table identifies
every remaining production `.shared` read; no unclassified read is changed.

### Step 2: Establish edge-owned configuration values

At the composition or operation edge, obtain the current Settings values once
and convert them to the narrowest existing value type. Use session snapshots
for recording/transcription, explicit post-processing requests for AI work,
persisted provenance for default historical retry, and `DeliverySettingsConfig`
for delivery. Inject narrow providers where an operation genuinely needs a
dynamic capability check, such as API-key readiness; do not pass the mutable
store inward.

Keep `AppSettingsStore` out of Domain. Keep provider/model/language/vocabulary
selection out of legacy compatibility APIs once an explicit request exists.

**Verify**: focused tests compile with injected values and no migrated domain
or AI contract imports `AppSettingsStore` solely to resolve an operation
request.

### Step 3: Migrate RecordingManager and retry paths

Remove live Settings reads from normal full-file and incremental finalization
after the session snapshot is available. Capture any remaining operation
policy, such as auto-export or audio preparation, at the lifecycle boundary
and carry it with the session snapshot when it affects the in-flight result.

Change retry to use Plan 124's persisted provenance by default, with an
explicit user-selected retry configuration taking precedence. Resolve current
Settings only when creating a new explicit retry override or when handling a
legacy record with no provenance, and make that fallback visible in tests.

Do not change microphone/device resolution, startup toggles, or readiness code
unless Step 1 classified them as operation-time inputs for the same request.

**Verify**: mutate Settings after recording/retry starts; full-file,
incremental, fallback, retry, export policy, and performance identity remain
stable for the operation. Recording, incremental, retry, and persistence tests
pass.

### Step 4: Migrate post-processing and local AI explicit routes

Use Plan 123's explicit post-processing request in normal, retry, manual
reprocess, and Assistant paths. Remove live configuration resolution from the
explicit route in `PostProcessingService`, `PostProcessingRepositoryAdapter`,
and `ConversationAndPostProcessing`; retain Settings only at the edge that
creates a new request or in a clearly named legacy overload.

Make `LocalTranscriptionClient` treat explicit language/model/diarization
values as authoritative. Keep its Settings fallback only for unconfigured
legacy callers and cover that distinction with tests. Preserve
`TranscriptionDeliveryService`'s narrow settings value pattern and inject it
at the caller rather than broadening it.

**Verify**: `rg -n "AppSettingsStore\\.shared|PostProcessingService\\.shared"
` over the migrated execution methods shows only compatibility/composition
edges; settings mutation after request creation does not change provider,
model, language, mode, structured choice, or delivery policy.

### Step 5: Remove accidental defaults and document the allowlist

After all migrated callers use injected values, remove default `.shared`
parameters from internal operation-only initializers where doing so cannot
break the composition root. Keep public/legacy compatibility defaults only if
there is a real caller and document the fallback boundary. Do not change
settings keys or migration behavior.

Update the relevant architecture/storage guidance with the rule: `.shared` is
allowed at composition/UI/readiness/legacy edges, while operational services
consume explicit snapshots or narrow providers. Include the exact allowlisted
categories, not a promise that the repository has zero singleton reads.

**Verify**: the inventory command output is explainable line by line; no
migrated operation method reads `.shared`; `make arch-check` and
`make lint-strict` pass.

### Step 6: Run the final gate and review

Run the command table, review dependency injection at construction sites, and
check that the source of every operation setting is visible in the call graph.
Confirm no new global mutable state, `@unchecked Sendable` escape, or broad
settings facade was introduced.

**Verify**: focused tests, build, architecture, strict lint, full validation,
and `git diff --check` pass with no new baseline failure.

## Test plan

- Add a settings-mutation test for normal recording and incremental finalization
  proving the session snapshot wins over current Settings.
- Add retry tests for persisted provenance, explicit override, and legacy
  missing-provenance fallback.
- Add post-processing tests for injected selection/configuration and manual
  reprocess without `PostProcessingService.shared`.
- Add local-client tests distinguishing explicit language/diarization from the
  legacy Settings fallback.
- Preserve existing delivery tests with an injected `DeliverySettingsConfig`.
- Add a lightweight inventory assertion or documented allowlist check if the
  repository's architecture-check tooling can express it without creating a
  new bespoke framework.

## Done criteria

- [ ] All operation-time Settings reads in the scoped paths are replaced by
  session snapshots, explicit requests, persisted provenance, or narrow
  injected providers.
- [ ] Remaining `.shared` reads are limited to documented composition-root,
  UI, readiness/health, and legacy compatibility edges.
- [ ] No `AppSettingsStore` dependency crosses into Domain merely to resolve a
  request.
- [ ] No mega-settings service, provider registry, or new global mutable state
  is introduced.
- [ ] Settings mutation tests prove in-flight operations remain stable.
- [ ] Recording, post-processing, retry, local-client, persistence,
  architecture, lint, build, and full validation gates pass with no new
  baseline failure.
- [ ] The singleton-boundary rule is documented for future callers.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- A read cannot be classified without changing product semantics; stop and
  request a product decision rather than guessing.
- Removing `.shared` requires changing UserDefaults keys, migrations, or
  settings UI behavior.
- An operation needs live mutation by design; make that product rule explicit
  and keep the dependency at the edge instead of hiding it.
- The proposed solution introduces a catch-all settings object, a service
  locator, or a second singleton.
- A legacy fallback cannot remain wire/behavior compatible without expanding
  out-of-scope provider/XPC behavior.
- The change requires broad concurrency escapes or changes audio callback
  ownership.

## Maintenance notes

- New operations must resolve Settings once at their edge and pass a narrow
  immutable value inward.
- New health/readiness code may observe Settings, but it must not mutate or
  replace an in-flight request.
- Keep compatibility reads visible and temporary; remove them only when their
  last real caller disappears.
- This plan is intentionally last in the sequence; if Plans 122–124 do not
  expose a stable operation/session/provenance boundary, stop rather than
  forcing the singleton cleanup early.
