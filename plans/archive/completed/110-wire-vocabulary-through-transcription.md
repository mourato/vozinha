# Plan 110: Wire vocabulary snapshots through transcription and enhancement

> **Executor instructions**: Follow the plan and update the ledger. Use only
> current official provider documentation during the capability step.
>
> **Drift check (run first)**:
> `git diff --stat 22794e18..HEAD -- Packages/MeetingAssistantCore/Sources/Domain/Domain/Interfaces Packages/MeetingAssistantCore/Sources/Domain/Domain/UseCases/TranscribeAudioUseCase Packages/MeetingAssistantCore/Sources/AI Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager Packages/MeetingAssistantCore/Sources/UI/Services/AssistantVoiceCommand`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/109-promote-dictionary-and-add-vocabulary-workflow.md`
- **Category**: migration
- **Planned at**: commit `22794e18`, 2026-07-16
- **Completed**: 2026-07-16 (remediation: explicit `vocabularyHints`, ElevenLabs `keyterms`, privacy disclosure)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — one snapshot contract must cover every path
- **Reviewer required**: yes — privacy and cross-module Full review
- **Rationale**: Vocabulary may be disclosed to external providers and affects transcript correctness.
- **Escalate when**: Official provider docs conflict with the installed SDK/API, require new entitlements, or lack a documented vocabulary input.

## Why this matters

Adding terms to a list is useful only if transcription or enhancement consumes
them. Consumption must be explicit, immutable per session, provider-capability
aware, and truthful about external transmission.

## Current state

- `DomainProtocols.swift:69` has no vocabulary/hotword input.
- Replacement rules run after ASR and before preprocessing/post-processing in
  `TranscribeAudioUseCase.swift`; retry and Assistant paths also apply them.
- VoiceInk projects normalized terms into AI enhancement context and selected
  provider APIs, but duplicates normalization across adapters. Prisma must use
  one local `VocabularySnapshot` and no adapter may query persistence directly.
- Prisma providers and their APIs may change. Only official current docs can
  establish whether a provider supports prompts, keyterms, hotwords, limits,
  and data handling.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Sensitive tests | `make test-sensitive` | exit 0 |
| Architecture | `make arch-check` | exit 0 |
| Strict lint | `make lint-strict` | exit 0 |
| Final | `make validate-agent ARGS="--lane auto"` | Full PASS |

## Suggested executor toolkit

- Use `architecture`, `data-persistence`, `swift-concurrency-expert`,
  `testing-xctest`, `documentation`, and `delivery-workflow`.
- For provider capability research, use current official provider/API docs only
  and record links/date in the implementation PR or owning code comment.

## Scope

**In scope**:

- `Domain/Domain/Interfaces/DomainProtocols.swift`
- `Domain/Domain/UseCases/TranscribeAudioUseCase/TranscribeAudioUseCase.swift`
- A new domain/infrastructure `VocabularySnapshot` and capability value.
- `AI/Services/TranscriptionClient.swift` and only the provider adapters proven
  by official documentation to support vocabulary.
- `AI/Services/PostProcessingService/` prompt/configuration files.
- `UI/Services/RecordingManager/` snapshot/full/incremental/retry files.
- `UI/Services/AssistantVoiceCommand/AssistantTranscriptionPhase.swift`
- Matching tests and privacy-facing localization/copy if external sending occurs.

**Out of scope**: Undocumented provider parameters, provider-specific
persistence reads, CloudKit, and deterministic replacement behavior.

## Git workflow

- Isolated branch/worktree: `codex/110-vocabulary-transcription`.
- One writer. Commit example:
  `feat(transcription): apply session vocabulary hints`.

## Steps

### Step 1: Record a provider capability matrix

Inventory the exact local, Groq, ElevenLabs, streaming, and retry adapters in
the live tree. For each, verify current official support, parameter name,
limits, language constraints, and whether terms leave the device. Mark each as
supported, unsupported, or blocked; never infer support from VoiceInk.

**Verify**: add a concise dated matrix to the owning implementation comment or
test fixture and ensure every adapter is classified. If none supports terms,
continue with escaped enhancement context only and report that limitation.

### Step 2: Create one normalized immutable snapshot

Expose a Sendable `VocabularySnapshot` from the local owner created in Plan
109. It must trim/deduplicate once, provide deterministic ordering, support
explicit provider limit projection, and never log raw terms. Capture it at the
same session boundary as Plan 106's mode configuration.

**Verify**: unit tests cover normalization, limits, stable ordering, empty
snapshot, and session immutability.

### Step 3: Thread vocabulary through explicit request contracts

Extend the transcription request/use-case/repository boundary with the snapshot
or a provider-neutral hint value. Supported adapters map it to documented API
fields; unsupported adapters ignore it explicitly. No adapter reads
`AppSettingsStore`.

**Verify**: adapter tests assert exact request inclusion, limit enforcement,
unsupported omission, and no term values in diagnostics.

### Step 4: Add an escaped enhancement fallback

Project terms into post-processing instructions as data, not executable prompt
text: delimit/escape them and instruct the model to prefer spelling without
inventing content. Apply only when enhancement runs. Preserve deterministic
substitutions after transcription in their current order.

**Verify**: prompt/config tests cover quotes, delimiters, injection-like terms,
empty lists, and disabled enhancement.

### Step 5: Cover every execution path

Use the same snapshot for full-file, incremental, retry, and Assistant
transcription. Assert transcript and segment parity and that changing Dictionary
mid-session affects only the next session.

**Verify**: targeted RecordingManager, TranscribeAudioUseCase, Retry, and
Assistant tests all pass, then `make test-sensitive` -> pass.

### Step 6: Validate architecture, privacy, and Full lane

If any external provider receives vocabulary, add accurate localized disclosure
at the owning UI boundary. Run architecture, lint, Full validation, and review.

**Verify**: `make arch-check && make lint-strict && make validate-agent ARGS="--lane auto"` -> Full PASS; privacy reviewer has no Critical/Medium finding.

## Test plan

- Snapshot normalization/limits/immutability.
- Supported and unsupported provider request mapping.
- Escaped enhancement context and disabled enhancement.
- Full, incremental, retry, Assistant, transcript/segment parity.
- Diagnostics contain no raw vocabulary terms.

## Done criteria

- [x] Vocabulary affects supported transcription/enhancement paths.
- [x] Every provider has an explicit capability classification.
- [x] All execution paths use one immutable snapshot.
- [x] No adapter reads persistence or logs terms.
- [x] Any external disclosure is localized and accurate.
- [x] Full validation and review: Full `validate-agent` PASS; privacy review completed with disclosure/wire-limit tighten (`dde4da0c`); merged to `main`.

## STOP conditions

- Official documentation does not support the planned provider parameter.
- Terms would be sent externally without a clear product disclosure.
- A provider limit cannot be enforced deterministically.
- Vocabulary requires weakening prompt-injection boundaries.

## Maintenance notes

- Recheck the capability matrix when provider APIs change.
- Keep substitutions deterministic and separate from probabilistic vocabulary hints.

