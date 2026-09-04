# Plan 128: Eager dictation ASR warmup during capture

> **Executor instructions**: Follow this brief step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the local status row in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 08124206..HEAD -- Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerIncrementalShared.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManager.swift Packages/MeetingAssistantCore/Sources/AI/Services/FluidAIModelManager.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `08124206`, 2026-09-04
- **Finding ID**: `dictation-eager-asr-warmup`
- **Publication**: local
- **Parent issue**: none
- **Issue**: none
- **Integration**: isolated worktree → merge to local `main` only when operator asks; no push unless requested

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent of plan 129; serialize with 130/131 on shared RecordingManager/residency files
- **Reviewer required**: `yes` — audio/transcription path + model residency interaction
- **Rationale**: Touches ASR load timing and capability gates; not a mechanical one-liner.
- **Escalate when**: Scope expands to Enhance/XPC warm prepare, cloud streaming providers, or meeting-path warmup redesign beyond the dictation-focused API.

## Why this matters

Dictation stop→text latency is dominated by cold local ASR. Today warmup is
deferred **3 seconds after** recording starts, gated on
`isMeetingTranscriptionEnabled`, and loads the **meeting** model selection —
so a dictation-mode Parakeet selection can miss warmup entirely or warm the
wrong model. Eager, purpose-aware prepare during capture (VoiceInk-inspired;
GPL inspiration only) cuts first-utterance and stop→paste latency without
keeping models resident for 30 minutes (see plan 131).

## Current state

Key files:

- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManager.swift` — `Constants.deferredIncrementalWarmupDelay = 3_000_000_000` (3s)
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift` — after `startRecorder`, `commitRecordingStart` calls `scheduleDeferredIncrementalWarmupIfNeeded`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerIncrementalShared.swift` — `warmupIncrementalTranscriptionIfNeeded()` → `TranscriptionClient.warmupModelIfNeededInBackground()`
- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift` — warmup gated on meeting capability and meeting selection

Excerpts (planned-at SHA):

```467:478:Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift
    public func warmupModelIfNeededInBackground() {
        guard FeatureFlags.enableCachedTranscriptionReadinessGate else { return }
        guard settingsStore.isMeetingTranscriptionEnabled else { return }
        guard cachedReadinessState != .healthy else { return }

        Task { @MainActor [weak self] in
            do {
                try await self?.warmupModel()
```

```125:156:Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift
    public func warmupModel() async throws {
        guard settingsStore.isMeetingTranscriptionEnabled else {
            // ... skip ...
            return
        }
        // local path:
        await FluidAIModelManager.shared.loadModels()
        let meetingSelection = settingsStore.resolvedTranscriptionSelection(for: .meeting)
        // may also load diarization for meeting
```

```257:257:Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift
        scheduleDeferredIncrementalWarmupIfNeeded(meetingID: meeting.id)
```

Conventions:

- `reuse → extend → create`; prefer extending `TranscriptionClient` / `FluidAIModelManager.loadModels(for:)` over new coordinators.
- Never log transcript text, prompts, or secrets (`AGENTS.md`).
- Local model residency remains mandatory (`modelResidencyTimeout`); this plan only changes **when** load happens, not the global timeout policy (plan 131 owns unload-after-dictation).
- VoiceInk is **inspiration only** (GPL-3.0); do not copy source.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift | `git diff --stat 08124206..HEAD -- <in-scope paths>` | empty or reviewed mismatches |
| Focused tests | `./scripts/run-tests.sh --suite dev --file TranscriptionClientWarmupTests` (or the new/extended file you add) | all pass |
| Residency regression | `./scripts/run-tests.sh --suite dev --file LocalModelResidencyCoordinatorTests` | all pass |
| Lint | `make lint` | exit 0 (or only known baseline violations documented) |
| Lane | `make validate-agent` | PASS for changed surface / documented baseline |

## Suggested executor toolkit

- Primary: project `audio-realtime` + `intelligence-kernel` overlays as needed
- Complementary: `swift-concurrency-expert` if Task/`@MainActor` boundaries get messy
- `test-hygiene` when adding/running tests
- Bind `delivery-contract` + worktree gate before first patch

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift`
- `Packages/MeetingAssistantCore/Sources/AI/Services/LocalTranscriptionClient.swift` (only if needed for purpose-aware load)
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManager.swift` (warmup delay constant / helpers)
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerIncrementalShared.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerIncrementalDictation.swift` (only if start-order hook is cleaner here)
- New or extended tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/` for purpose-aware warmup gating
- Localization keys **only** if a user-visible settings string is required (prefer none)

**Out of scope**:

- Plan 130 ready-gate / buffer queue
- Plan 131 post-dictation unload policy
- Enhance/LLM XPC prepare-during-record (optional follow-up; do not block on it)
- Meeting-path warmup redesign beyond sharing the new purpose-aware API
- Cloud streaming providers
- Copying VoiceInk code

## Git workflow

- Branch: `perf/dictation-eager-warmup` (isolated worktree per `core/policies/worktrees.md`)
- Commit style: Conventional Commits, e.g. `perf(dictation): warm ASR for active style during capture`
- Do NOT push or open a PR unless the operator instructed it

## Steps

### Step 1: Add purpose-aware warmup API on TranscriptionClient

Extend warmup so callers can request warmup for a concrete
`TranscriptionExecutionMode` / provider selection / model ID (dictation style
snapshot already stored as `activeTranscriptionConfiguration` on
`RecordingManager`).

Requirements:

1. Dictation warmup must **not** require `isMeetingTranscriptionEnabled`.
2. Dictation warmup must load `activeTranscriptionConfiguration.modelID` (or the
   passed selection), not blindly `resolvedTranscriptionSelection(for: .meeting)`.
3. Dictation warmup must **not** load diarization models.
4. Meeting callers can keep existing behavior by wrapping the old entry points.
5. Keep `warmupModelIfNeededInBackground` as a thin wrapper; add a background
   variant that accepts the dictation configuration.

**Verify**: `./scripts/run-tests.sh --suite dev --file LocalModelResidencyCoordinatorTests` still passes (no accidental residency regressions from compile-only yet).

### Step 2: Trigger eager warmup for dictation at capture start

In the dictation start path (`RecordingManagerStart` /
`prepareIncrementalDictationSessionIfNeeded` / shared helpers):

1. Once `activeTranscriptionConfiguration` is set and incremental dictation is
   selected (or even for batch dictation when local model will run on stop),
   kick warmup **immediately** (no 3s defer for dictation).
2. Keep deferred warmup for meeting incremental if still desired, or share the
   eager path with meeting only if behavior stays equivalent — prefer
   **dictation-only** change to minimize risk.
3. Ensure warmup is cancelled/ignored if the session ends before it completes
   (existing deferred task cancel pattern in `cancelDeferredIncrementalWarmup`).

**Verify**: build compiles via focused test target; add a unit test that asserts
dictation warmup is invoked with the dictation model id and is not gated on
`isMeetingTranscriptionEnabled` (inject settings/mock client as existing tests do).

### Step 3: Characterization tests

Add tests covering:

- Warmup skipped when meeting capability off **for meeting mode** (preserve old gate).
- Warmup allowed for dictation when meeting capability off.
- Dictation warmup requests the dictation/style model id, not meeting selection.
- Dictation warmup does not request diarization load.

Model after existing settings-isolation patterns in
`IntelligenceKernelContractsTests` / residency tests (acquire
`AppSettingsTestIsolationLock` when touching `AppSettingsStore.shared`).

**Verify**:
`./scripts/run-tests.sh --suite dev --file <YourNewOrExtendedWarmupTests>` → all pass.

### Step 4: Lint + lane

**Verify**: `make lint` then `make validate-agent` → PASS / documented baseline only.

## Test plan

- New/extended warmup tests as in Step 3.
- Do not add UI or Instruments harness in this plan.
- Manual (operator, optional): start dictation with Parakeet, confirm first
  preview/stop latency improves when model was cold; no transcript content in
  logs.

## Done criteria

- [ ] Dictation warmup uses the active dictation/style model id
- [ ] Dictation warmup is not gated on `isMeetingTranscriptionEnabled`
- [ ] Dictation path no longer waits the 3s deferred delay before starting warmup
- [ ] Focused warmup + residency tests pass
- [ ] `make lint` and `make validate-agent` recorded with results
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` row updated with commit / review / validation evidence

## STOP conditions

- `warmupModel` / `loadModels(for:)` API shape has drifted so purpose-aware load
  cannot reuse `FluidAIModelManager.loadModels(for:)` without a larger refactor.
- Fix appears to require changing Enhance/XPC prepare pipelines (defer to
  follow-up; do not expand this plan).
- Enabling eager load causes measurable regressions in meeting capture start
  that cannot be confined to dictation-only call sites.
- Verification fails twice after a reasonable fix.

## Maintenance notes

- Plan 130 should treat “ASR readiness after this warmup” as the ready-gate
  signal.
- Plan 131 should unload after dictation without fighting this eager load.
- Reviewers: confirm no meeting diarization load on dictation warmup; confirm
  no PII in new log lines.
