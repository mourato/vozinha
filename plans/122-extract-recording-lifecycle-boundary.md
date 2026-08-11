# Plan 122: Extract the RecordingManager lifecycle boundary

> **Executor instructions**: Read this plan completely. This is a serial,
> high-risk architecture refactor. Run every verification command before
> moving to the next step. If a STOP condition occurs, report it and do not
> replace the existing lifecycle with speculative coordinators. Update the
> `plans/README.md` row only after the final review and validation pass.
>
> **Drift check (run first)**: `git diff --stat a5536db9..HEAD -- Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTranscriptionTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/IncrementalDictationTranscriptionCoordinatorTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/IncrementalMeetingTranscriptionCoordinatorTests.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plan 121 (`plans/121-deepen-transcription-execution-seam.md`)
- **Category**: tech-debt / architecture migration
- **Planned at**: commit `a5536db9`, 2026-08-11
- **Status**: DONE — merged into local `main` at `183bee4e`; review remediation in `61b13e7f`

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — start, stop, cancellation, incremental capture,
  retry, and observable state share one lifecycle owner.
- **Reviewer required**: yes — the refactor changes state ownership and must
  be reviewed against failure, cancellation, and recording invariants.
- **Rationale**: The current manager is already decomposed into extensions,
  but the extensions still mutate one large `@MainActor` state object. A
  single focused lifecycle boundary is the narrowest safe extraction.
- **Escalate when**: the extraction needs a new public target, changes the
  audio callback path, changes the public `RecordingServiceProtocol`, or
  requires more than one new orchestration abstraction.

## Why this matters

`RecordingManager` remains the mutable owner of capture state, transcription
session state, incremental coordinators, retry state, post-processing state,
progress tasks, permissions, meeting notes, and UI publishers. Splitting the
file into extensions improved navigation but did not create an architectural
boundary: start, stop, cancellation, and unexpected recorder failure still
duplicate reset logic and can evolve inconsistently. Extracting one lifecycle
owner makes state transitions explicit and gives the most failure-prone paths a
small test surface without changing audio or transcription behavior.

## Current state

The manager is a `@MainActor` observable facade and owns both UI state and
workflow dependencies:

- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManager.swift:10-134` — declares `RecordingManager`, its published state, more than twenty service dependencies, lifecycle tasks, active session snapshots, and incremental coordinators.
- `RecordingManager.swift:152-208` — `TranscriptionSessionSnapshot` already groups immutable per-session values. Reuse it; do not introduce a second session vocabulary.
- `RecordingManagerStart.swift:35-94` — `startCapture` guards exclusivity, mutates published state, captures telemetry, and delegates to `prepareAndStartRecording`.
- `RecordingManagerStart.swift:117-180` — `prepareAndStartRecording` captures context, dictation mode, vocabulary, and the explicit transcription configuration before starting audio.
- `RecordingManagerStop.swift:12-86` — `stopRecording` stops both recorders, creates the session snapshot, processes audio, then selects incremental or full-file finalization.
- `RecordingManagerStop.swift:89-154` — startup cancellation and active cancellation both repeat cleanup and state-reset operations.
- `LifecycleHelpers.swift:15-50` — unexpected recorder failure performs a third variant of the same cleanup/reset sequence.
- `RecordingManager/Retry.swift:12-140` — retry is a separate workflow and must remain a caller of the lifecycle/session boundary, not be silently folded into start/stop.

The project is macOS 15+ Swift 6.2 with strict concurrency and default
nonisolated actor isolation. UI and lifecycle state remains `@MainActor`; audio
render callbacks remain allocation-minimal and outside this plan. Domain terms
are `Dictation mode`, `Transcription configuration`, and `Incremental
transcription`; do not introduce `profile`, `preset`, or `streaming
transcription` as synonyms. Follow the existing `reuse -> extend -> create`
rule and keep physical files under the existing
`Sources/UI/Services/RecordingManager/` owner directory.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Architecture | `make arch-check` | exit 0; no module-boundary violations |
| Lint | `make lint-strict` | exit 0 with no new warnings |
| Focused recording tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter RecordingLifecycleCoordinatorTests` | 16 lifecycle tests pass |
| Focused transcription tests | `./scripts/run-tests.sh --suite dev --file RecordingManagerTranscriptionTests` | exit 0 |
| Incremental tests | `./scripts/run-tests.sh --suite dev --file IncrementalDictationTranscriptionCoordinatorTests && ./scripts/run-tests.sh --suite dev --file IncrementalMeetingTranscriptionCoordinatorTests` | both exit 0 |
| Build | `make build-agent` | exit 0; Debug build succeeds |
| Full gate | `make validate-agent ARGS="--lane auto"` | selected Full lane passes, or any pre-existing toolchain failure is recorded without a new source failure |
| Diff hygiene | `git diff --check` | no whitespace errors |

## Suggested executor toolkit

- Use `architecture` for ownership and dependency direction.
- Use `swift-conventions` with the project overlay for Swift structure and
  naming.
- Use `delivery-workflow` for the final risk and validation evidence.
- Do not use `audio-realtime` to rewrite callbacks; this plan must stay above
  the recorder hot path.

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManager.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStart.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStop.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/LifecycleHelpers.swift`
- Existing lifecycle/session helper files under the same directory when the
  ownership move requires it.
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTranscriptionTests.swift`
- Existing incremental and retry tests needed to preserve the contract.

**Out of scope**:

- `MeetingAssistantCoreAudio` recorder implementation, render callbacks,
  buffering, audio merging algorithms, and permissions behavior.
- The explicit transcription seam delivered by Plan 121.
- Post-processing request semantics; Plan 123 owns that boundary.
- Core Data fields or migrations; Plan 124 owns execution provenance.
- Settings UI, new recording modes, new providers, XPC methods, and public
  target dependencies.
- A second coordinator for each sub-flow. Do not create separate start,
  stop, retry, and incremental coordinators in this plan.

## Git workflow

- Use an isolated worktree/branch named `codex/122-recording-lifecycle`.
- Match the repository's Conventional Commit style, for example
  `refactor(recording): extract lifecycle boundary`.
- Do not push, merge, or modify unrelated dirty plan artifacts.

## Ordered implementation steps

### Step 1: Freeze the lifecycle contract

Run the drift check, `git status --short`, the focused recording and
incremental suites, `make arch-check`, and `git diff --check`. Build a compact
state-transition table for `startCapture`, successful `stopRecording`, stop
without transcription, startup cancellation, active cancellation, recorder
failure, and transcription failure. Record which published properties and
cleanup actions each path owns. Do not change production code until the table
matches the tests and the current implementation.

**Verify**: all baseline commands complete; every transition lists its final
values for `isStartingRecording`, `isRecording`, `isTranscribing`,
`currentMeeting`, `currentCapturePurpose`, exclusivity ownership, temporary
files, incremental coordinators, and active transcription snapshots.

### Step 2: Define one lifecycle owner without changing the public facade

Introduce the smallest single lifecycle boundary in the existing
`RecordingManager` directory. The boundary may be named
`RecordingLifecycleCoordinator` if no existing type can own it, but it must
have one owner and one responsibility: coordinate capture lifecycle
transitions while `RecordingManager` remains the `@MainActor` observable
facade and `RecordingServiceProtocol` implementation.

Keep `TranscriptionSessionSnapshot` as the immutable handoff value. The new
owner may call existing services through injected dependencies or a narrow
facade, but do not pass the entire `RecordingManager` into it and do not move
all manager properties wholesale. Keep UI publishers and user-visible state
on `RecordingManager`; move only the orchestration needed to make start/stop/
cancel/failure transitions singular.

**Verify**: `make build-agent` passes; `rg -n "class RecordingManager|protocol RecordingServiceProtocol" Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager` shows the public facade remains; no new target or dependency is introduced.

### Step 3: Migrate start, stop, and cancellation in order

Move the start transition first, then successful stop/finalization, then both
cancellation variants. Preserve the existing order of recorder shutdown,
incremental cancellation, temporary-file cleanup, snapshot capture,
exclusivity release, sounds, and state reset. Use existing helpers instead of
copying cleanup logic into the new owner. Keep the explicit transcription
configuration captured at session start and pass the existing snapshot to the
transcription pipeline.

**Verify**: the focused RecordingManager and RecordingManagerTranscription
tests pass; add regression tests that assert the exact cleanup/state outcome
for startup cancellation, active cancellation, stop without transcription,
and stop with a full-file transcription.

### Step 4: Route unexpected failure and preserve adjacent flows

Route unexpected recorder failure through the same lifecycle cleanup boundary.
Keep retry, incremental finalization, meeting notes, automatic meeting
recording, and progress reporting as callers or collaborators unless the
transition table proves they are lifecycle state transitions. Do not absorb
their domain behavior into the new owner merely to reduce file count.

**Verify**: the incremental dictation, incremental meeting, retry-performance,
and existing recording tests pass; a failure test proves exclusivity and
temporary state are released exactly once.

### Step 5: Remove only superseded lifecycle duplication

After all callers use the new boundary, delete private lifecycle helpers that
have no caller. Keep compatibility helpers that still have a real production
caller. Review the resulting dependency direction: UI owns orchestration,
Domain owns contracts/use cases, Data owns storage, AI owns provider and
post-processing adapters, and Audio owns capture.

**Verify**: `rg -n "resetAfterDiscardingRecording|handleUnexpectedRecorderFailure|cancelRecording|stopRecording|startCapture"` shows one canonical implementation for each lifecycle transition; `make arch-check` and `make lint-strict` pass.

### Step 6: Run the final gate and review

Run all commands in the table, review the complete diff for state-order
changes, and check that no touched file exceeds the repository's 600-line
preference without a concrete ownership reason. Update this plan's row only
after the required review and validation are complete.

**Verify**: focused tests, `make build-agent`, `make arch-check`,
`make lint-strict`, `make validate-agent ARGS="--lane auto"`, and
`git diff --check` pass with no new baseline failure.

## Test plan

- Extend `RecordingManagerTests` for the lifecycle transition table and exact
  state/cleanup outcomes.
- Extend `RecordingManagerTranscriptionTests` for snapshot handoff through
  stop, full-file fallback, and transcription failure.
- Keep `IncrementalDictationTranscriptionCoordinatorTests`,
  `IncrementalMeetingTranscriptionCoordinatorTests`, and
  `RecordingManagerRetryPerformanceTests` as regression suites.
- Add one failure-path test proving unexpected recorder failure releases
  exclusivity, clears active capture state, and does not leave a coordinator
  or temporary file behind.
- Run the test files through `scripts/run-tests.sh`; do not introduce a new
  test framework or production-only test hook.

## Done criteria

- [x] `RecordingManager` remains the public `@MainActor` observable facade.
- [x] One lifecycle owner is responsible for start, stop, cancellation, and
  unexpected recorder-failure transitions.
- [x] `TranscriptionSessionSnapshot` remains the single session handoff value.
- [x] No audio callback or recorder hot-path code changes.
- [x] No duplicate cleanup/reset implementation remains for the migrated
  transitions.
- [x] Existing recording, incremental, retry, architecture, lint, build, and
  full validation gates pass with no new baseline failure.
- [x] Only in-scope source/tests and the plan ledger are modified.
- [x] `plans/README.md` status row is updated.

## Closeout evidence

- Implementation was merged into local `main` through `0b010176`; the stale
  callback, reset-serialization, and test-size findings were remediated in
  `61b13e7f` and integrated by merge `183bee4e`.
- Final review manually audited the integrated remediation diff and found no
  unresolved findings. The independent automated reviewer did not return
  before the closeout window, so no automated approval is claimed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
  --filter RecordingLifecycleCoordinatorTests`: 16 tests passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make arch-check`,
  `make build-agent`, and `make validate-agent ARGS="--lane auto"`: passed;
  the integrated full lane passed on Xcode 26.6.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make lint-strict`
  and `make guidance-check`: passed with zero SwiftLint warnings.
- `git diff --check a5536db9..183bee4e`: passed. The implementation commits
  touched only the Plan 122 source/test surface; unrelated planning work
  remains unstaged.

## STOP conditions

- The lifecycle owner must know about provider/model selection or read
  `AppSettingsStore` to work; keep configuration resolution at the operation
  edge and report the conflict.
- The extraction requires passing `RecordingManager` itself into the new owner
  or recreating its entire property bag; stop and redesign the boundary.
- A transition changes recorder callback timing, audio buffer ownership, or
  the XPC/transcription request contract.
- Existing tests disagree about cancellation order, incremental fallback, or
  exclusivity ownership.
- The work requires a second coordinator or a new public module/target.
- A validation failure is caused by a new source/compiler error rather than a
  previously recorded environment/toolchain failure.

## Maintenance notes

- New capture lifecycle transitions must be added to the single lifecycle
  owner and its state-transition tests.
- New transcription behavior should consume `TranscriptionSessionSnapshot`
  rather than reading current Settings from the manager.
- Keep post-processing request resolution in Plan 123's boundary and storage
  provenance in Plan 124; do not grow this lifecycle owner into a general AI
  coordinator.
