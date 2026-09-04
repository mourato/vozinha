# Plan 131: Unload local ASR after dictation session

> **Executor instructions**: Follow this brief step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the local status row in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 08124206..HEAD -- Packages/MeetingAssistantCore/Sources/AI/Services/LocalModelResidencyCoordinator.swift Packages/MeetingAssistantCore/Sources/AI/Services/FluidAIModelManager.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerStop.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ModelResidencyTimeoutOption.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/LocalModelResidencyCoordinatorTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plan 128 (eager load without a matching unload would increase RAM dwell)
- **Category**: perf
- **Planned at**: commit `08124206`, 2026-09-04
- **Finding ID**: `dictation-post-session-model-unload`
- **Publication**: local
- **Parent issue**: none
- **Issue**: none
- **Integration**: isolated worktree → merge to local `main` only when operator asks; no push unless requested

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — serialize after 128; avoid conflicting residency edits with 130 unless rebase-aware
- **Reviewer required**: `yes` — residency policy is a hard AGENTS.md invariant
- **Rationale**: Changing when models leave RAM affects meeting reuse, diarization, and memory; needs tests and careful in-use checks.
- **Escalate when**: Scope expands to per-model residency settings UI overhaul, XPC process teardown, or unloading Enhance/LLM runtimes.

## Why this matters

Global `modelResidencyTimeout` defaults to **30 minutes**. VoiceInk unloads ASR
after each finished dictation session. With plan 128’s eager warmup, keeping
Parakeet resident for 30 minutes after a short dictate wastes RAM on smaller
Macs. This plan adds a **dictation-session unload override** that respects
`isASRInUse` / meeting activity and does not weaken the mandatory residency
registry coverage rule.

## Current state

- `LocalModelResidencyCoordinator` polls every 30s and unloads when
  `now - lastASRActivityAt >= modelResidencyTimeout.inactivityInterval`.
- Options: 5/10/15/30/60 minutes or `never` — **no sub-minute / immediate**.
- `FluidAIModelManager.unloadASRFromMemoryIfPossible()` already no-ops when
  `isASRInUse`.
- Dictation stop/delivery ends in `RecordingManagerStop` /
  `TranscriptionDeliveryService` without residency hooks.

```109:127:Packages/MeetingAssistantCore/Sources/AI/Services/LocalModelResidencyCoordinator.swift
    func evaluateAndUnloadIfNeeded(now: Date = Date()) {
        guard let timeoutInterval = settingsStore.modelResidencyTimeout.inactivityInterval else {
            return
        }
        // unload ASR / diarization when idle past timeout
    }
```

AGENTS.md / project-standards: every local model must remain residency-managed
with unload hooks; do not invent an unmanaged load path.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift | `git diff --stat 08124206..HEAD -- <in-scope paths>` | empty or reviewed |
| Residency tests | `./scripts/run-tests.sh --suite dev --file LocalModelResidencyCoordinatorTests` | all pass |
| Lint | `make lint` | exit 0 / known baseline |
| Lane | `make validate-agent` | PASS / documented baseline |

## Suggested executor toolkit

- Project `audio-realtime` + `project-standards` residency rules
- `test-hygiene`
- Bind `delivery-contract` + worktree gate before first patch
- Land/rebase after plan 128

## Scope

**In scope**:

- `LocalModelResidencyCoordinator.swift` — API to request post-dictation unload
  or schedule a short grace timer
- `FluidAIModelManager.swift` — only if activity stamps / unload helpers need a
  narrow extension
- `RecordingManagerStop.swift` (and/or delivery completion hook) — call unload
  policy after successful dictation finalize/cancel when ASR idle
- Tests in `LocalModelResidencyCoordinatorTests.swift` (+ new file if cleaner)
- Optional settings: **prefer no new Settings UI** in v1; hardcode a small grace
  (e.g. 60–120s) or immediate unload-when-idle. If a setting is truly needed,
  add a dictation-specific timeout option without changing meeting default 30m.

**Out of scope**:

- Changing default global `modelResidencyTimeout` for meetings
- Unloading diarization on dictation end if meeting may still need it — leave
  diarization on global timeout unless proven idle and dictation-only
- Enhance/LLM model unload
- Plan 130 gate logic
- Copying VoiceInk code

## Git workflow

- Branch: `perf/dictation-post-session-unload`
- Commit style: `perf(dictation): unload local ASR after dictation idle grace`
- Do NOT push unless requested

## Steps

### Step 1: Choose policy (encode in code, do not bikeshed)

Recommended default for this plan (do not expand without STOP):

1. After dictation session reaches terminal state (delivered, failed, or
   canceled) and ASR is not in use, schedule **grace unload** at **120 seconds**
   of no ASR activity, **or** immediate `unloadASRFromMemoryIfPossible()` if
   grace is zero — prefer **120s** so back-to-back dictates reuse the warm model
   from plan 128.
2. Meeting capture active → never unload.
3. Global `modelResidencyTimeout == .never` → still honor never (do not force
   unload).
4. If global timeout is shorter than grace, the existing monitor already wins —
   do not lengthen residency.

Document the chosen grace constant next to the call site.

**Verify**: write failing tests first for the chosen policy (TDD welcome).

### Step 2: Implement coordinator API

Add something equivalent to:

- `scheduleDictationIdleUnload(grace: TimeInterval)`
- cancel on new ASR activity / meeting start / `startMonitoring` teardown

Implementation notes:

- Reuse `unloadASRFromMemoryIfPossible()`; do not bypass in-use guards.
- Update `lastASRActivityAt` semantics only if required; prefer not rewriting
  activity tracking.
- Keep registry coverage logging intact.

**Verify**: unit tests with `MockLocalModelResidencyManager` (already in
`LocalModelResidencyCoordinatorTests`).

### Step 3: Hook dictation session end

From the dictation stop/finalize path (after delivery attempt or cancel
cleanup), call the schedule API when `capturePurpose == .dictation`.

Do not call from meeting stop.

**Verify**: a RecordingManager-level test if cheap; otherwise coordinator tests +
a focused call-site test/mock. Avoid UI tests.

### Step 4: Lint + lane

**Verify**: `make lint` then `make validate-agent`.

## Test plan

- Grace elapsed + not in use → unload
- In use → no unload
- Meeting activity / non-dictation → schedule not armed (or canceled)
- `modelResidencyTimeout == .never` → no forced unload
- New dictation/warmup activity cancels pending grace

Pattern: existing `LocalModelResidencyCoordinatorTests`.

## Done criteria

- [ ] Dictation end schedules bounded ASR unload without breaking meeting residency
- [ ] `never` timeout still disables forced unload
- [ ] In-use guard preserved
- [ ] Tests cover grace / cancel / never / in-use
- [ ] `make lint` + `make validate-agent` recorded
- [ ] No out-of-scope files modified
- [ ] Ledger row updated

## STOP conditions

- Unload races with incremental finalize (`isASRInUse` false too early) causing
  crashes or reload loops — stop and harden in-use tracking before shipping.
- Fix requires changing global default timeout for all modes.
- Verification fails twice after a reasonable fix.

## Maintenance notes

- Reviewers: confirm plan 128 warmup + this unload do not thrash on every
  keypress (grace exists for a reason).
- Follow-up: optional Settings control for dictation grace; diarization policy
  if a local model couples ASR+diarization memory.
