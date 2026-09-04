# Plan 130: Incremental dictation ready-gate for early audio

> **Executor instructions**: Follow this brief step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the local status row in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 08124206..HEAD -- Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerIncrementalShared.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerIncrementalDictation.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalTranscriptionCoordinator.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalTranscriptionCoordinatorCore.swift Packages/MeetingAssistantCore/Sources/AI/Services/TranscriptionClient.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTranscriptionSupportTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plan 128 (eager warmup readiness signal)
- **Category**: perf
- **Planned at**: commit `08124206`, 2026-09-04
- **Finding ID**: `dictation-incremental-ready-gate`
- **Publication**: local
- **Parent issue**: none
- **Issue**: none
- **Integration**: isolated worktree → merge to local `main` only when operator asks; no push unless requested

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — depends on 128’s purpose-aware warmup/ready signal; shares incremental coordinator files with possible 131 touchpoints
- **Reviewer required**: `yes` — realtime audio buffering + concurrency
- **Rationale**: Audio buffer queuing on the incremental path is easy to get subtly wrong (memory growth, dropped speech, false fallback).
- **Escalate when**: Scope expands to cloud streaming sockets, meeting incremental redesign, or a new audio device graph.

## Why this matters

VoiceInk buffers realtime PCM behind a chunk gate until the streaming provider
is ready, then flushes. Our dictation incremental path starts the recorder only
after `coordinator.start()`, so startup ordering is better — but early VAD
windows can still hit a **cold** ASR while warmup is in flight, then mark
`requiresLegacyFallback` and pay full-file latency. A bounded ready-gate keeps
early speech for the warm model (or a controlled flush) instead of degrading on
the first utterance.

Inspiration only from VoiceInk’s gate idea; **do not copy GPL code**.

## Current state

Start order today (`RecordingManagerStart`):

1. Set `activeTranscriptionConfiguration`
2. `prepareIncrementalDictationSessionIfNeeded` → install buffer forwarder → `coordinator.start()`
3. `startRecorder`
4. Deferred warmup after 3s (plan 128 removes this for dictation)

Forwarder already queues via `AsyncStream` with pending-buffer pressure
(`RecordingManagerIncrementalShared.IncrementalBufferForwarder`), but it does
**not** wait for ASR readiness before `coordinator.append` → `transcribe(window:)`.

```74:80:Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/IncrementalTranscriptionCoordinatorCore.swift
    func append(bufferBox: RecordingManager.SendableIncrementalAudioBufferBox) async {
        guard !requiresLegacyFallback else { return }

        do {
            let windows = try await voiceActivityKernel.append(buffer: bufferBox.buffer)
            for window in windows {
                try await transcribe(window: window)
```

Warmup entry (pre-128): background, meeting-gated, deferred.

Existing forwarder tests:
`Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/RecordingManagerTranscriptionSupportTests.swift`

Conventions:

- Prefer extending `IncrementalTranscriptionCoordinatorCore` / forwarder over a
  parallel buffer pipeline.
- Bounded memory: hard cap on queued duration or buffer count; on overflow,
  prefer documented fallback over unbounded growth.
- `ponytail:` comment if a temporary O(n) queue ceiling is intentional.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift | `git diff --stat 08124206..HEAD -- <in-scope paths>` | empty or reviewed |
| Forwarder tests | `./scripts/run-tests.sh --suite dev --file RecordingManagerTranscriptionSupportTests` | all pass |
| New gate tests | `./scripts/run-tests.sh --suite dev --file IncrementalReadyGateTests` (name may vary) | all pass |
| Lint | `make lint` | exit 0 / known baseline |
| Lane | `make validate-agent` | PASS / documented baseline |

## Suggested executor toolkit

- Project `audio-realtime`
- `swift-concurrency-expert` for actor/buffer ownership
- `test-hygiene`
- Bind `delivery-contract` + worktree gate before first patch
- Confirm plan 128 is merged (or rebase onto its worktree) before coding

## Scope

**In scope**:

- `IncrementalTranscriptionCoordinator.swift` / `IncrementalTranscriptionCoordinatorCore.swift`
- `RecordingManagerIncrementalShared.swift` (forwarder or readiness hook)
- `RecordingManagerIncrementalDictation.swift` (wire readiness from warmup)
- Minimal TranscriptionClient / FluidAI readiness query already introduced by plan 128 (consume, do not redesign)
- Tests for gate open / queue / flush / overflow→fallback
- Optional: shared helper used by meeting incremental **only if** identical and low-risk; default is dictation-first

**Out of scope**:

- Replacing VAD (`RealtimeVoiceActivityWindowAssembler`)
- Cloud streaming providers
- Changing full-file silence compaction
- Unload policy (plan 131)
- Copying VoiceInk code

## Git workflow

- Branch: `perf/dictation-incremental-ready-gate`
- Commit style: `fix(dictation): gate incremental audio until ASR is ready`
- Do NOT push unless requested

## Steps

### Step 1: Define readiness signal

Reuse plan 128’s purpose-aware warmup completion / cached readiness:

- “Ready” means local ASR for the active dictation model is loaded (or
  incremental path explicitly marks ready after successful warmup Task).
- If warmup fails, open the gate anyway and allow existing fallback behavior
  (do not hang recording forever).

Expose a small API on the coordinator, e.g. `setASRReady(_:)` / `markReady()`,
callable from RecordingManager when warmup finishes.

**Verify**: unit test can construct coordinator and flip readiness without audio hardware.

### Step 2: Bounded pre-ready queue

While not ready:

- Continue accepting PCM/windows into a **bounded** queue (choose one ceiling:
  ~2–3s of audio **or** N buffers; document the ceiling with `ponytail:` if
  simplistic).
- Do not call `transcribe(window:)` until ready.
- On ready: flush in order, then live-append.
- On overflow before ready: set controlled `requiresLegacyFallback` (or drop
  oldest only if you can prove finalize still correct — prefer fallback).

Keep WAV/full-file capture untouched; gate is for incremental preview/final only.

**Verify**: tests simulate not-ready → enqueue → ready → flush order preserved.

### Step 3: Wire dictation start path

After plan 128 eager warmup starts:

1. Start coordinator + recorder as today.
2. Gate closed until warmup completion callback/task.
3. On stop before ready: flush whatever remains into finalize path or fall back
   to full-file (must not deadlock stop).

**Verify**: stop-while-warming test (async) does not hang; falls back or flushes.

### Step 4: Lint + lane

**Verify**: `make lint` then `make validate-agent`.

## Test plan

- Ordered flush after ready
- Overflow triggers fallback (or documented drop policy)
- Stop while not ready does not deadlock
- Existing forwarder pressure tests still pass

Pattern: `RecordingManagerTranscriptionSupportTests`.

## Done criteria

- [ ] Early incremental audio is held until ASR ready or warmup failure opens gate
- [ ] Queue is bounded; overflow behavior is tested
- [ ] Stop during warmup never hangs
- [ ] Focused tests + `make lint` + `make validate-agent` recorded
- [ ] No out-of-scope files modified
- [ ] Ledger row updated

## STOP conditions

- Plan 128 not available and inventing a second warmup API would duplicate it —
  stop and rebase onto 128.
- Correctness requires redesigning VAD or the full incremental actor model.
- Verification fails twice after a reasonable fix.

## Maintenance notes

- Reviewers: check MainActor vs coordinator actor hops; no transcript text in
  logs; memory ceiling is real under long cold loads.
- Follow-up: apply the same gate to meeting incremental if metrics show the
  same cold-start fallback pattern.
