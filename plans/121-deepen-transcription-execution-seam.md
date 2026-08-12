# Plan 121: Centralize transcription execution behind one explicit request seam

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. Stop
> on any condition listed below; do not improvise. Update this plan's row in
> `plans/README.md` when complete unless the reviewer owns the index.
>
> **Drift check (run first)**:
> `git diff --stat cb03f184..HEAD -- Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/TranscriptionRepositoryAdapter.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Services/Protocols.swift Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift Packages/MeetingAssistantCore/Sources/AI/Services/XPC MeetingAssistantAI/Sources/MeetingAssistantAIService.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager Packages/MeetingAssistantCore/Sources/UI/Services/AssistantVoiceCommand`
> Compare every changed in-scope symbol with the current-state notes below.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plans 106 and 110 (both DONE)
- **Category**: architecture migration
- **Planned at**: commit `cb03f184`, 2026-08-11
- **Completed**: local `main` commit `a5536db9`, 2026-08-11
- **Closeout toolchain**: Xcode 26.6 (`/Applications/Xcode.app`), Swift 6.3.3
- **Closeout validation**:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make validate-agent ARGS="--lane auto --committed --base cb03f184 --head main --agent"`: PASS (Full lane)
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-sensitive`: reproduces six pre-existing readiness-test failures; the same baseline is recorded in `.agents/reports/phase0-audio-baseline-2026-05-25.md`
  - The initial stable-toolchain run required removing only the stale generated SwiftPM `.build` cache from another checkout; no source files changed.

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — the domain interface, provider dispatch, XPC
  payload, and session snapshot form one contract
- **Reviewer required**: yes — Full-lane thermo-nuclear review is mandatory
- **Rationale**: This crosses domain, data, infrastructure, AI, XPC, retry,
  incremental capture, and Assistant execution paths.
- **Escalate when**: the change needs a new public target dependency, changes
  the XPC process boundary beyond explicit transcription request fields,
  touches audio callbacks, or requires remote incremental transcription.

## Decision record

- Deepen the existing `TranscriptionRepositoryAdapter` as the domain seam.
  Do not create a new factory, coordinator, or provider registry.
- Reuse `DomainTranscriptionRequestConfiguration` and
  `DictationTranscriptionConfiguration`. Add fields only when a real path
  cannot carry its already-existing operation context.
- Capture one effective transcription configuration at the operation edge:
  recording-session start for RecordingManager and immediately before the
  Assistant command transcription phase. The adapter and client execute that
  value; they do not read `AppSettingsStore` on the normal path.
- Keep incremental transcription local-only. Capability checks use the
  captured provider/model; unsupported incremental capture keeps the existing
  full-file fallback.
- Evolve the existing XPC payload in place with explicit provider/model/language
  data. Preserve the wire method and decode compatibility for an older payload;
  do not add a second XPC method.
- Preserve compatibility overloads during migration. Remove duplicate
  capability protocols, runtime-cast ladders, and mutable `selectionOverride`
  usage only after all production callers and contract tests use the explicit
  request path.

## Why this matters

Transcription selection is currently shallow across several modules. The
adapter, use case, RecordingManager, incremental coordinator, Assistant phase,
and XPC client each know part of the capability ladder or resolve live
settings. That weakens locality: changing a mode during a session can change
the provider, model, language, or incremental decision halfway through the
operation.

The deletion test is positive for the existing adapter: deleting it would move
the response mapping and capability dispatch into the use case and UI callers,
not remove complexity. Deepening that adapter gives the interface a real test
surface and gives future providers one seam to implement and verify.

## Current state

- `DomainTranscriptionRequestConfiguration` already carries provider ID, model
  ID, input language, and vocabulary hints in
  `Domain/Domain/Interfaces/DomainProtocols.swift:106-124`.
- The domain interface family is split between `TranscriptionRepository` and
  configuration/purpose/diarization protocols at
  `Domain/Domain/Interfaces/DomainProtocols.swift:62-148`.
- `TranscriptionRepositoryAdapter` has the real domain seam, but its
  unconfigured route dispatches among purpose and diarization capabilities at
  `Data/Services/Adapters/TranscriptionRepositoryAdapter.swift:67-101`, while
  its configured route falls back to that live route when the infrastructure
  capability is unavailable at lines 111-148.
- `TranscribeAudioUseCase` repeats the domain capability ladder with runtime
  casts at `Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift:92-130`.
- `RecordingManagerTranscriptionExecution` resolves selection and language
  from `AppSettingsStore`, then repeats the infrastructure capability ladder
  at `UI/Services/RecordingManager/RecordingManagerTranscriptionExecution.swift:35-121`.
- `TranscriptionClient` has a mutable next-call `selectionOverride`, resolves
  unconfigured file and sample requests from settings, and checks incremental
  support through the live selected mode at
  `AI/Services/TranscriptionClient.swift:21-58` and `:277-389`.
- Incremental capture stores an optional dictation configuration but still
  casts to `TranscriptionServiceConfigurationAware` and checks live model
  support in `UI/Services/RecordingManager/RecordingManagerIncrementalShared.swift:25-47` and `:172-182`.
- Assistant snapshots vocabulary, selection, and language, but uses its own
  `AssistantCommandTranscribing` protocol instead of the shared explicit
  transcription interface at `UI/Services/AssistantVoiceCommand/AssistantTranscriptionPhase.swift:7-56`.
- The XPC client reads `AppSettingsStore` and sends only diarization/speaker
  settings at `AI/Services/XPC/MeetingAssistantAIClient.swift:83-145`. The XPC
  service then uses the local model and language defaults at
  `MeetingAssistantAI/Sources/MeetingAssistantAIService.swift:10-38`.
- Existing tests cover session snapshots, vocabulary propagation, use-case
  execution, incremental behavior, Assistant transcription, and XPC status,
  but no test owns the complete provider/capability matrix at the adapter seam.

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift`
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/TranscriptionRepositoryAdapter.swift`
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/Protocols.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/LocalTranscriptionClient.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/XPC/{MeetingAssistantAIClient,MeetingAssistantXPCModels,MeetingAssistantXPCProtocol}.swift`
- `MeetingAssistantAI/Sources/MeetingAssistantAIService.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/{RecordingManagerStart,RecordingManagerTranscriptionExecution,RecordingManagerTranscriptionPipeline,RecordingManagerIncrementalDictation,RecordingManagerIncrementalMeeting,RecordingManagerIncrementalShared,IncrementalTranscriptionCoordinatorCore,Retry,RecordingControl}.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/AssistantVoiceCommand/{AssistantVoiceCommandService,AssistantTranscriptionPhase}.swift`
- Matching tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`, including the existing RecordingManager, incremental, Assistant, use-case, and XPC test files plus a focused adapter contract test if no existing test file can own that surface.

**Out of scope**:

- Splitting `RecordingManager` into a new lifecycle module (candidate 2).
- Settings UI, mode persistence, navigation, or vocabulary persistence; Plans
  106-110 already own those concerns.
- New transcription providers, provider SDK changes, or a provider registry.
- Remote or XPC incremental transcription.
- Post-processing architecture, delivery policy, or Assistant integrations.
- Audio callback, buffer, or recorder implementation changes.
- New dependencies, targets, CI/CD, or public distribution work.

## Git workflow

- Create an isolated worktree branch `codex/121-transcription-execution-seam`.
- One writing agent only. Use atomic Conventional Commits, for example
  `refactor(transcription): centralize explicit execution request`.
- Do not push, merge into `main`, or open a PR unless instructed.

## Steps

### Step 1: Freeze the behavior matrix and verify drift

Inventory every production caller of `transcribe`,
`supportsIncrementalTranscription`, `selectionOverride`,
`resolvedTranscriptionSelection`, and
`resolvedTranscriptionInputLanguageCode`. Classify each caller as full-file,
retry, incremental, Assistant, health/readiness, or legacy/imported-file.

Run the existing focused suites before changing contracts:

```sh
./scripts/run-tests.sh --suite dev --file RecordingManagerTranscriptionTests
./scripts/run-tests.sh --suite dev --file IncrementalDictationTranscriptionCoordinatorTests
./scripts/run-tests.sh --suite dev --file IncrementalMeetingTranscriptionCoordinatorTests
./scripts/run-tests.sh --suite dev --file AssistantTranscriptionPhaseTests
./scripts/run-tests.sh --suite dev --file TranscribeAudioUseCaseMacroMockingTests
./scripts/run-tests.sh --suite dev --file MeetingAssistantAIClientTests
```

Record any baseline failure before proceeding. Do not change behavior while
only building the matrix.

**Verify**: every production path has one named configuration source and one
named execution seam; no unclassified caller remains.

### Step 2: Make the existing domain seam explicit and singular

Extend the canonical `TranscriptionRepository` contract with the two existing
configuration-aware operations, preserving the current unconfigured overloads
only as compatibility entry points. Remove
`TranscriptionRepositoryConfigurationAware` after its callers and generated
mocks have migrated; do not add a replacement protocol.

Keep `CapturePurpose`/operation context as an explicit argument rather than
coupling the Domain target to an Infrastructure-only execution enum. Preserve
the existing `DomainTranscriptionRequestConfiguration` value shape unless a
verified caller needs an additional domain-owned field.

Update `TranscribeAudioUseCase` to call the explicit repository operation when
configuration is present. Its fallback may call the unconfigured compatibility
overload, but it must contain no runtime casts to purpose, diarization, or
configuration protocols. Update macro mocks and tests through the canonical
interface.

Move all domain-level purpose/diarization dispatch into
`TranscriptionRepositoryAdapter`. The adapter remains responsible for mapping
infrastructure responses to domain responses and for the compatibility route;
the use case and UI do not know which capability protocol won.

**Verify**: adapter contract tests cover configured file and sample requests,
diarization override, capture purpose, vocabulary propagation, and the legacy
fallback route. `TranscribeAudioUseCase` tests prove the configured branch is
selected without a runtime protocol cast.

### Step 3: Make `TranscriptionClient` an explicit execution adapter

Make the existing explicit file/sample request operations part of the normal
`TranscriptionService` contract used by `TranscriptionRepositoryAdapter` and
Assistant. Remove `TranscriptionServiceConfigurationAware` after migration;
retain the smaller purpose/diarization capabilities only if a real remaining
implementation needs them, and keep their dispatch below the adapter seam.

The explicit route must:

- select provider, model, language, vocabulary, and execution context only from
  the request values;
- keep local, Groq, ElevenLabs, and XPC routing in `TranscriptionClient`;
- preserve local-model diarization adjustment based on the explicit model;
- never read `AppSettingsStore` or consume `selectionOverride`;
- leave legacy unconfigured overloads as compatibility-only routes until Step 6.

Add the smallest explicit incremental capability query to the existing
execution interface. It must receive the concrete provider/model selection,
return false for remote and XPC incremental execution, and use the selected
local model's capability rather than resolving the current settings mode.

**Verify**: the provider matrix proves that each explicit request reaches the
correct backend/model/language and that incremental support is stable when
settings mutate after the request is created. No production explicit path
contains a live settings lookup.

### Step 4: Thread one configuration through RecordingManager and retry

Create the domain request configuration once from the already-captured
`DictationTranscriptionConfiguration` and `VocabularySnapshot` at the
recording-session boundary. Store or pass that value with the existing session
snapshot; do not reconstruct it from current settings in the pipeline.

Migrate the following paths to the same explicit request:

- full-file transcription and finalization;
- retry, using the stored configuration by default;
- incremental sample windows and incremental capability checks;
- incremental full-file fallback and final response finalization;
- model-performance identity and related metrics.

An intentional user-selected retry model remains allowed, but it must be
converted to a new explicit request at the retry boundary. It must not mutate
the shared `TranscriptionClient.selectionOverride` slot. Preserve the existing
`RetryTranscriptionSelectionMatrix` behavior and error/fallback semantics.

Remove the capability ladders and live selection/language reads from
`RecordingManagerTranscriptionExecution`. Health/readiness may remain a
separate service concern, but it must not alter the transcription request.

**Verify**: tests mutate mode, provider, model, language, and vocabulary
settings after session start and prove that full-file, retry, incremental, and
fallback requests retain the original values. Tests also prove remote and
unsupported local models choose the existing full-file fallback.

### Step 5: Give Assistant the same explicit request path

Build the Assistant transcription configuration once immediately before the
command transcription phase from its selected provider/model/language and
vocabulary snapshot. Pass the same request values through
`AssistantTranscriptionPhase` using the shared explicit transcription
interface.

Remove `AssistantCommandTranscribing` if the canonical `TranscriptionService`
contract can be injected directly. If a test-only seam is still required, it
must be a typealias or existing shared contract, not an Assistant-specific
capability protocol.

Preserve Assistant's `.assistant` execution context, normalization order,
empty-command handling, and integration dispatch. No Assistant path may
resolve a provider or language after its request is created.

**Verify**: Assistant tests cover explicit local/remote selection, language,
vocabulary, and settings mutation during the request without changing the
command transcription behavior.

### Step 6: Carry the explicit request across XPC and remove duplication

Extend the existing `MeetingAssistantXPCModels.AppSettings` Codable payload with
the explicit provider ID, model ID, input language, and execution context needed
by transcription. Keep old fields and defaulted decoding for compatibility;
keep the existing `MeetingAssistantXPCProtocol.transcribe` method.

Change `MeetingAssistantAIClient` so its explicit request route encodes the
captured values and does not read `AppSettingsStore`. Keep an unconfigured
compatibility overload only if a real caller remains, and make its fallback
resolution visible at that edge.

Change `MeetingAssistantAIService` to validate the explicit provider, pass the
explicit local model ID and language hint to `LocalTranscriptionClient`, and
preserve diarization/speaker settings. It must not silently replace a valid
explicit model with the XPC service default.

Once all callers use the explicit route, remove the compatibility protocol
casts and mutable `selectionOverride` writes. Delete only protocols and
overloads with no remaining production or test caller. Keep any capability
protocol that still represents a real implementation seam, but confine its
selection to the adapter/client and document why it remains.

**Verify**: XPC payload tests cover new encode/decode, old payload defaults,
provider/model/language mapping, and no settings-store read in the explicit
client route. `rg` shows no UI/use-case/Assistant capability ladder and no
normal-path `selectionOverride` mutation.

### Step 7: Run architecture, concurrency, and Full-lane validation

Run the targeted suites and then the repository gates:

```sh
make arch-check
make lint-strict
make test-sensitive
make validate-agent ARGS="--lane auto"
```

The auto gate should select Full for this cross-module change. Run the required
thermo-nuclear review after validation and fix all Critical and Medium findings.
Check that no file in the touched surface exceeds the repository's 600-line
preference without a concrete ownership reason.

**Verify**: all targeted tests, architecture checks, strict lint, sensitive
tests, Full validation, and review pass with no new baseline failures.

## Test plan

- Adapter contract matrix for configured file/sample requests, provider/model,
  language, vocabulary, purpose, diarization, and legacy fallback.
- Use-case tests proving one explicit repository call and no capability ladder.
- Recording session immutability across full-file, retry, incremental, and
  full-file fallback paths.
- Incremental capability tests for remote providers, XPC, supported local
  models, and unsupported local models.
- Assistant request immutability and shared explicit-interface coverage.
- XPC payload compatibility and explicit local model/language propagation.
- Regression coverage for performance identity, diarization behavior, retry
  override behavior, empty commands, and error mapping.
- Diagnostics assertions that provider/model labels are allowed but raw
  vocabulary, transcripts, prompts, and credentials are never logged.

## Done criteria

- [ ] One explicit transcription request path covers full-file, retry,
  incremental, fallback, and Assistant execution.
- [ ] `TranscriptionRepositoryAdapter` owns domain-level capability dispatch;
  UI and use-case callers no longer repeat capability ladders.
- [ ] `TranscriptionClient` routes explicit provider/model/language/vocabulary
  values without live settings reads or mutable next-call overrides.
- [ ] A session/Assistant request remains stable after settings or vocabulary
  changes.
- [ ] Incremental remains local-only and preserves the existing full-file
  fallback.
- [ ] XPC receives and applies the explicit local model and language while
  remaining wire-compatible with the old payload.
- [ ] Duplicate protocols and compatibility overloads are removed only when
  unused; any deliberate remainder is confined to the adapter/client seam.
- [x] Targeted tests, architecture checks, strict lint, Full validation, and
  required review pass.
- [x] `make test-sensitive` was rerun with the compatible toolchain and
  reproduced only the six documented pre-existing readiness failures; no new
  Plan 121 failure was found.
- [ ] Only in-scope files, `CONTEXT.md`, this plan, and the ledger are modified.

## STOP conditions

- A real caller requires concurrent mutable `selectionOverride` semantics;
  stop and redesign the request ownership before continuing.
- XPC compatibility requires a second wire method, an identity change, or a
  new public target dependency.
- A provider cannot honor the explicit model/language values without changing
  its external API or documented behavior.
- Incremental support would need remote delivery or audio-callback changes.
- A session path cannot capture a stable configuration at its operation edge;
  report the product rule conflict rather than reintroducing live reads.
- Swift 6.2 actor isolation or `Sendable` constraints require `Task.detached`,
  shared mutable state, or a broad concurrency escape hatch.
- Existing behavior tests disagree with the approved local-only incremental or
  retry fallback decisions.

## Maintenance notes

- A new transcription caller must pass an explicit configuration and use the
  existing adapter/client seam; it must not read settings to choose a provider.
- A new provider must add explicit request mapping and capability tests at the
  adapter/client seam before adding UI or use-case branches.
- Keep `Dictation mode` and `Transcription configuration` as the canonical
  domain terms; do not introduce a second name for the same snapshot.
