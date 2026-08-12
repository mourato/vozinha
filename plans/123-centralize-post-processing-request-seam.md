# Plan 123: Centralize post-processing behind one explicit request seam

> **Executor instructions**: Read this plan completely. Run each verification
> command before advancing. Preserve the canonical-summary and trust-flag
> contracts. If a STOP condition occurs, report it instead of adding another
> compatibility protocol or silently falling back to live settings. Update the
> `plans/README.md` row only after review and the final gate.
>
> **Drift check (run first)**: `git diff --stat a5536db9..HEAD -- Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Services/Protocols.swift Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessing.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessingPipeline.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerTranscriptionPipeline.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerIncrementalShared.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/ConversationAndPostProcessing.swift Packages/MeetingAssistantCore/Sources/UI/Services/AssistantVoiceCommand/AssistantAIPhase.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plan 122 (`plans/122-extract-recording-lifecycle-boundary.md`)
- **Category**: tech-debt / architecture migration
- **Planned at**: commit `a5536db9`, 2026-08-11
- **Status**: DONE (merged into local `main` at `8a5907e9`; implementation
  `258d7dd9`)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — normal finalization, incremental finalization,
  retry, manual reprocess, and Assistant AI processing must share one request
  contract.
- **Reviewer required**: yes — canonical summary output, trust flags, prompt
  routing, provider selection, and fallback behavior are all sensitive.
- **Rationale**: The repository adapter already provides the right place to
  deepen, but several UI and AI paths still bypass it or resolve settings from
  the service singleton. One explicit request seam is safer than more overloads.
- **Escalate when**: the change requires a new AI target, a canonical-summary
  schema change, a provider SDK change, remote incremental processing, or a
  second post-processing repository/registry.

## Why this matters

Post-processing currently has multiple configuration and execution paths. The
normal transcription use case receives a domain configuration, while retry and
manual reprocess route through `RecordingManager` or a view model and the AI
service still resolves `AppSettingsStore.shared` internally. This can make a
summary use a different provider/model or structured-pipeline decision from
the one selected at the operation edge. A single explicit request preserves
the canonical summary contract and makes post-processing deterministic across
normal, retry, reprocess, and Assistant flows.

## Current state

- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces/DomainProtocols.swift:180-280` — `PostProcessingRepository` has mode-aware overloads and a separate `PostProcessingRepositorySelectionAware` protocol; `DomainPostProcessingSelection` already carries provider ID, model ID, and registration ID.
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/PostProcessing.swift:9-213` — the use case already builds a `PostProcessingConfiguration`, chooses structured vs fast processing from mode, and persists the output; this is the strongest existing domain seam to extend.
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift:193-221` — normal finalization passes prompt, mode, post-processing identity, selection, context, and structured-pipeline flags into the use case.
- `Packages/MeetingAssistantCore/Sources/Data/Services/Adapters/PostProcessingRepositoryAdapter.swift:8-177` — the real adapter maps domain prompts/selections to the legacy AI service, but its compatibility route owns a `settings = .shared` reference and resolves selected prompts itself.
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/Protocols.swift:145-200` — `PostProcessingServiceProtocol` exposes many legacy overloads and `selectionOverride` operations instead of one request object.
- `Packages/MeetingAssistantCore/Sources/AI/Services/PostProcessingService/PostProcessingService.swift:10-62` and `LegacyAPI.swift:90-205` — the service stores `AppSettingsStore.shared` and builds request configuration from live settings in normal legacy calls.
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessing.swift:8-120` — `UseCaseConfig` is assembled from session data and live settings; it is close to the required operation-edge snapshot but is owned by the UI extension.
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessingPipeline.swift:62-220` — retry/direct post-processing reads live settings, resolves prompts and selections, and calls the AI service directly.
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/ConversationAndPostProcessing.swift:250-335` — manual reprocess resolves structured mode, performance identity, and model from live settings and calls `PostProcessingService.shared` directly.
- `Packages/MeetingAssistantCore/Sources/UI/Services/AssistantVoiceCommand/AssistantAIPhase.swift:31-76` — Assistant AI processing calls the service directly with a prompt and mode, without a shared explicit selection request.

The reusable intelligence-kernel contract is defined by
`IntelligenceKernelMode`, `CanonicalSummary`, and
`DomainPostProcessingResult`. Preserve these invariants: schema versions stay
within `1...CanonicalSummary.currentSchemaVersion`, summaries are non-empty,
list entries are non-empty, action-item titles are non-empty, and confidence
scores remain in `0...1`. Keep mode flags and rollout controls in the existing
settings adapters. Do not log transcript text, prompts, vocabulary, API keys,
or provider credentials.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Architecture | `make arch-check` | exit 0 |
| Lint | `make lint-strict` | exit 0 with no new warnings |
| Post-processing validation | `./scripts/run-tests.sh --suite dev --file PostProcessingServiceValidationTests` | exit 0 |
| Domain post-processing | `./scripts/run-tests.sh --suite dev --file TranscribeAudioUseCasePostProcessingMacroMockingTests` | exit 0 |
| Recording post-processing | `./scripts/run-tests.sh --suite dev --file RecordingManagerPostProcessingLimitTests` | exit 0 |
| Summary regression | `make benchmark-summary-agent` | exit 0 or report-only result with no regression |
| Build | `make build-agent` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane auto"` | Full lane passes, or a pre-existing toolchain failure is recorded with no new source failure |
| Diff hygiene | `git diff --check` | no whitespace errors |

## Suggested executor toolkit

- Use `architecture` for the Domain → Data → AI dependency direction.
- Use `intelligence-kernel` for canonical summary, trust flags, mode routing,
  and benchmark gates.
- Use `swift-conventions` and `delivery-workflow` for implementation and
  validation.
- Use `data-persistence` only to verify that this plan does not change the
  storage schema; Plan 124 owns provenance persistence.

## Scope

**In scope**:

- Existing `PostProcessingRepository` contracts and the
  `PostProcessingRepositoryAdapter`.
- `PostProcessingServiceProtocol` and the explicit request implementation in
  `PostProcessingService`.
- `TranscribeAudioUseCase` post-processing configuration and callers.
- RecordingManager normal/incremental/retry post-processing paths.
- Manual transcription reprocess and Assistant AI post-processing callers.
- Matching tests and generated mocks under
  `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`.

**Out of scope**:

- `CanonicalSummary` schema changes, new summary fields, or benchmark-threshold
  changes.
- New AI providers, provider SDKs, network clients, or a provider registry.
- Persisting request provenance; Plan 124 owns Core Data/domain storage.
- Removing every `AppSettingsStore.shared` reference in the repository; Plan
  125 handles the remaining operation-edge coupling after this seam exists.
- Audio capture, transcription provider routing, XPC wire methods, and UI copy.

## Git workflow

- Use an isolated worktree/branch named `codex/123-post-processing-seam`.
- Match the repository's Conventional Commit style, for example
  `refactor(post-processing): centralize explicit request`.
- Do not push, merge, or absorb unrelated plan/document changes.

## Ordered implementation steps

### Step 1: Freeze the post-processing behavior matrix

Run the drift check and all focused suites. Inventory every production caller
of `processTranscription`, `processTranscriptionStructured`,
`selectionOverride`, `resolvedEnhancementsAIConfiguration`, and
`resolvedEnhancementsPerformanceIdentity`. Classify each caller as normal
finalization, incremental finalization, retry, manual reprocess, Assistant,
health/readiness, or legacy compatibility. Record for each path: kernel mode,
prompt source, provider/model source, structured/fast choice, fallback, and
performance identity.

**Verify**: every production execution caller has exactly one classification
and one proposed request source; no behavior changes are made in this step.

### Step 2: Define the canonical explicit request using existing types

Extend the existing domain seam rather than creating parallel configuration
types. Reuse `DomainPostProcessingSelection`, `PostProcessingConfiguration`,
`DomainPostProcessingPrompt`, and `DomainPostProcessingResult`. If the
current values cannot travel together, add one domain-owned
`DomainPostProcessingRequestConfiguration` containing only the missing
operation context (selection, mode, structured-pipeline decision, and any
explicit execution metadata required by a real caller). Do not put
`AppSettingsStore`, `PostProcessingService`, API keys, or UI state in Domain.

Make the explicit request operation canonical on `PostProcessingRepository`
and `PostProcessingServiceProtocol`. Keep legacy overloads only while a real
caller remains, and route them through a clearly named compatibility edge.
Remove `PostProcessingRepositorySelectionAware` only after all production and
test callers use the canonical operation; do not replace it with another
capability ladder.

**Verify**: domain and infrastructure targets compile; focused contract tests
prove that provider/model/registration, mode, structured choice, and prompt
values arrive unchanged at the adapter.

### Step 3: Make the adapter and AI service execute only explicit requests

Move prompt conversion, selection conversion, and provider/model routing into
`PostProcessingRepositoryAdapter` and `PostProcessingService`'s explicit path.
The normal explicit path must not resolve selected prompts, provider/model,
readiness, or structured-pipeline choice from live settings. Inject the
settings/readiness dependency at the composition edge only when a capability
check genuinely needs it; the request itself remains immutable.

Preserve the canonical summary pipeline, deterministic fallback, repair path,
sanitization, timeout/retry policy, privacy-safe diagnostics, and existing
mode flags. Compatibility overloads may continue to resolve their defaults at
the legacy edge until Step 5, but they must not be called by migrated paths.

**Verify**: `rg -n "AppSettingsStore\.shared|selectionOverride"` over the
explicit implementation shows only compatibility/legacy paths; provider and
structured-pipeline contract tests pass.

### Step 4: Migrate all execution callers

Create the request at each operation edge and pass it through the canonical
seam:

- normal full-file and incremental finalization use the session snapshot;
- retry uses the retry-boundary selection and preserves its explicit choice;
- manual reprocess creates a new explicit request from the user's selected
  reprocess settings;
- Assistant uses `.assistant`, its selected enhancement configuration, and the
  existing prompt/system-prompt behavior;
- health/readiness and legacy/imported-file compatibility remain separate and
  must not silently alter an explicit request.

Remove direct calls from UI/view-model code to `PostProcessingService.shared`
when a repository/use-case seam exists. Keep output normalization, context
metadata, canonical summary, and error/fallback ordering unchanged.

**Verify**: mutate settings after each request is created and prove that the
  provider/model, mode, structured choice, prompt, and performance identity
  used by the in-flight operation do not change. Normal, incremental, retry,
  manual reprocess, and Assistant tests pass.

### Step 5: Remove superseded overloads and capability casts

Search all production and test callers. Delete only overloads, protocol
conformances, and mutable override paths with no remaining caller. Preserve a
small compatibility surface for unconfigured legacy/imported-file paths and
document why it remains. Do not introduce a provider registry or a second
post-processing service.

**Verify**: `rg -n "PostProcessingRepositorySelectionAware|PostProcessingService\.shared|selectionOverride" Packages/MeetingAssistantCore/Sources` returns only explicitly documented compatibility edges; `make arch-check` and `make lint-strict` pass.

### Step 6: Run summary and final validation gates

Run the command table, including summary benchmarks. Review canonical summary
fixtures and output-state assertions for schema/trust regressions. Check that
no touched file exceeds the repository's 600-line preference without a
concrete ownership reason.

**Verify**: focused suites, summary benchmark, build, architecture, strict
lint, full validation, and `git diff --check` pass with no new baseline
failure.

## Test plan

- Extend adapter tests for explicit legacy-prompt conversion, provider/model
  selection, mode, structured/fast choice, and compatibility fallback.
- Extend `TranscribeAudioUseCasePostProcessingMacroMockingTests` for one
  explicit repository call and immutable request values.
- Extend `PostProcessingServiceValidationTests` for explicit local/remote
  selection, readiness, timeout/fallback, sanitizer behavior, and canonical
  summary invariants.
- Extend recording and retry tests for settings mutation after request
  creation.
- Extend Assistant tests for `.assistant` mode, prompt/system prompt, and
  explicit model selection.
- Run `make benchmark-summary-agent` and preserve the existing fixture and
  baseline format.

## Done criteria

- [x] One explicit post-processing request seam covers normal, incremental,
  retry, manual reprocess, and Assistant execution.
- [x] Explicit paths do not read `AppSettingsStore` or resolve mutable
  selection overrides after request creation.
- [x] The adapter owns domain-to-AI mapping and compatibility dispatch.
- [x] Canonical summary schema, trust flags, sanitization, repair, and
  deterministic fallback behavior remain unchanged.
- [x] Legacy overloads remain only for real compatibility callers and are
  identified by tests/search.
- [x] Focused tests, summary benchmark, architecture, lint, build, and full
  validation pass with no new baseline failure.
- [x] No persistence schema changes are included.
- [x] `plans/README.md` status row is updated.

## STOP conditions

- An explicit caller still needs mutable settings during execution; report the
  product rule conflict instead of reintroducing live reads.
- The proposed request would carry secrets, raw prompts, transcript content,
  UI objects, or `AppSettingsStore` into Domain.
- Preserving behavior requires changing the canonical summary schema,
  benchmark thresholds, or trust-flag semantics.
- A provider cannot honor the explicit selection without a provider SDK/API
  change.
- A direct UI caller cannot migrate without changing a public API or adding a
  new target.
- The executor needs a second service, registry, or capability protocol to
  make the migration work.

## Maintenance notes

- New post-processing callers must create one explicit request at their
  operation edge and use the existing adapter/use-case seam.
- Keep `IntelligenceKernelMode` and `CanonicalSummary` as the canonical terms;
  do not add mode-specific UI branches or duplicate summary schemas.
- Plan 124 may extend the request/provenance value for persistence, but it
  must not make persisted prompts, credentials, or transcript payloads part of
  diagnostics.
- Plan 125 may remove remaining settings coupling after this seam is stable;
  do not broaden this plan into a repository-wide singleton purge.

## Closeout evidence

- Implementation branch: `123-post-processing-seam`, final commit
  `258d7dd9`; integrated into local `main` by merge commit `8a5907e9`.
- Focused tests passed: `PostProcessingServiceValidationTests` (5),
  `TranscribeAudioPostProcessingTests` (12), Assistant AI phase (11), manual
  long-input reprocess (1), and meeting selection snapshot mutation (1).
- Stable toolchain: `/Applications/Xcode.app/Contents/Developer`.
- Full committed validation on the implementation branch and integrated
  `main`: build/test passed all 1,130 tests; architecture check passed;
  summary benchmark passed with baseline unchanged; `git diff --check` passed.
- `make lint-strict` remains red only for six pre-existing structural
  violations in the touched legacy surfaces (large bodies/file); no new
  violation remains from this plan. The validation result is therefore
  recorded as build/test PASS plus known lint-baseline limitation.
- Review remediation: frozen meeting selection was added to the session
  snapshot, and explicit structured fallback now preserves the request's
  system prompt/configuration instead of consulting live settings.
- No persistence/schema, provider SDK, or new capability protocol changes.
