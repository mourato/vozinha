# Plan 129: Dictation shortcut hybrid/PTT parity and characterization

> **Executor instructions**: Follow this brief step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the local status row in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 08124206..HEAD -- App/SmartShortcutHandler.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Services/ShortcutExecutionEngine.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsCoreConfiguration.swift Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSShortcutControlsRow.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ShortcutDefinitionAndEngineTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (parallelizable with 128/130/131)
- **Category**: dx
- **Planned at**: commit `08124206`, 2026-09-04
- **Finding ID**: `dictation-shortcut-hybrid-ptt-parity`
- **Publication**: local
- **Parent issue**: none
- **Issue**: none
- **Integration**: isolated worktree → merge to local `main` only when operator asks; no push unless requested

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent workstream from residency/warmup plans
- **Reviewer required**: `yes` — global shortcut behavior is user-visible and easy to regress
- **Rationale**: Logic already exists (`holdOrToggle`); work is extraction, tests, UX clarity, and threshold parity — still MED because shortcut regressions are costly.
- **Escalate when**: Scope expands to a new shortcut backend, Accessibility APIs, or redesign of meeting/assistant shortcut modes beyond shared engine reuse.

## Why this matters

VoiceInk’s comfort model is toggle / push-to-talk / hybrid. We already ship
`ShortcutActivationMode.holdOrToggle` (default for dictation) plus pure
`.hold` and `.toggle`, but the hybrid branch lives only in App-layer
`SmartShortcutHandler` with **no characterization tests**, a fixed
`0.35s` threshold (VoiceInk hybrid uses `0.5s`), and settings copy that does
not clearly say “hybrid / hold-to-talk”. This plan closes that gap without
inventing a second activation system.

## Current state

Key files:

- `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsCoreConfiguration.swift` — `ShortcutActivationMode` cases
- `App/SmartShortcutHandler.swift` — hybrid logic (`handleHoldOrToggleDown/Up`)
- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/ShortcutExecutionEngine.swift` — hold / toggle / doubleTap engine used by non-hybrid modes
- `App/GlobalShortcutController.swift` — wires dictation/meeting handlers
- Defaults: `dictationShortcutActivationMode = .holdOrToggle` in `DefaultsReset.swift`

Hybrid behavior today:

```101:131:App/SmartShortcutHandler.swift
    private func handleHoldOrToggleDown() {
        holdOrTogglePressStartTime = Date()
        holdOrToggleWasRecordingAtPress = isRecordingProvider()

        if isRecordingProvider() {
            actionHandler(.stopRecording)
            holdOrToggleStartedRecording = false
        } else {
            holdOrToggleStartedRecording = true
            actionHandler(.startRecording)
        }
    }

    private func handleHoldOrToggleUp() {
        // ...
        if !holdOrToggleWasRecordingAtPress {
            let heldDuration = Date().timeIntervalSince(startTime)
            if heldDuration >= holdThreshold, holdOrToggleStartedRecording {
                actionHandler(.stopRecording)
            }
        }
    }
```

Default threshold: `holdThreshold: TimeInterval = 0.35` in `SmartShortcutHandler.init`.

Settings display name for hybrid: `settings.shortcuts.activation_mode.hold_or_press`.

Conventions:

- Prefer moving testable logic into `MeetingAssistantCore` (`ShortcutExecutionEngine`) rather than adding App-target XCTest harnesses.
- User-facing strings use `"key".localized`; remove orphans if keys change.
- Do not copy VoiceInk source (GPL-3.0).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift | `git diff --stat 08124206..HEAD -- <in-scope paths>` | empty or reviewed |
| Engine tests | `./scripts/run-tests.sh --suite dev --file ShortcutDefinitionAndEngineTests` | all pass |
| New hybrid tests | `./scripts/run-tests.sh --suite dev --file ShortcutHoldOrToggleTests` (name may vary) | all pass |
| Lint | `make lint` | exit 0 / known baseline |
| Lane | `make validate-agent` | PASS / documented baseline |

## Suggested executor toolkit

- `macos-app-shell` / project overlay for AppKit shortcut wiring
- `localization` if UI copy keys change
- `test-hygiene` for new tests
- Bind `delivery-contract` + worktree gate before first patch

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/Infrastructure/Services/ShortcutExecutionEngine.swift` (extend with holdOrToggle transitions)
- `App/SmartShortcutHandler.swift` (thin adapter over engine)
- Optionally `Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsCoreConfiguration.swift` (docs/comments only; keep raw value `holdOrToggle` for persistence)
- Localization for activation-mode display strings under existing shortcut keys
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSShortcutControlsRow.swift` only if picker labels need a helper
- New tests: `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ShortcutHoldOrToggleTests.swift` (or extend `ShortcutDefinitionAndEngineTests.swift`)
- `docs/ui.md` **only** if a durable UX rule for activation modes is newly established (prefer a short note; skip if unchanged)

**Out of scope**:

- New activation enum cases / UserDefaults migration of raw values
- Middle-click / mouse triggers (VoiceInk-only)
- Assistant integration shortcut redesign
- Changing default away from `.holdOrToggle` unless tests prove it is broken
- Copying VoiceInk code

## Git workflow

- Branch: `feat/dictation-shortcut-hybrid-parity`
- Commit style: `fix(shortcuts): characterize hold-or-toggle hybrid activation`
- Do NOT push unless requested

## Steps

### Step 1: Encode hybrid transitions in ShortcutExecutionEngine

Move the holdOrToggle state machine into `MeetingAssistantCore` so it is unit
testable. Preserve exact current semantics unless Step 3 explicitly changes
threshold:

| Press state | Down | Up |
|-------------|------|----|
| Idle | `.start` | if held ≥ threshold → `.stop`; if short press → no-op (stay recording) |
| Already recording | `.stop` | no-op |

Keep `holdThreshold` injectable (default may change in Step 3).

**Verify**: engine compiles; existing `ShortcutDefinitionAndEngineTests` still pass.

### Step 2: Thin SmartShortcutHandler

Delegate `.holdOrToggle` to the engine (or a dedicated helper type colocated with
the engine). Remove duplicated private hybrid state from the App adapter once
behavior is covered by tests.

**Verify**: app target builds (`make build-agent` or project-equivalent).

### Step 3: Threshold + UX clarity

1. Align default hybrid threshold with VoiceInk-like comfort **`0.5s`**, or keep
   `0.35s` only if you document why in the commit body after manual feel check.
   Prefer `0.5s` unless it clearly hurts double-activation.
2. Update localized display strings so dictation settings communicate:
   - `hold` → push-to-talk / hold
   - `toggle` → press to start/stop
   - `holdOrToggle` → hybrid (short press toggles; hold talks)
3. Do **not** rename the persisted raw value `holdOrToggle`.

**Verify**: localization integrity if keys change (`make localization-check` or the lane that includes it).

### Step 4: Characterization tests

Cover at least:

- Idle + short press → start only (no stop on up)
- Idle + long press (≥ threshold) → start then stop on up
- Recording + down → stop; up → no restart
- `reset()` clears hybrid state so a stranded press cannot stop the next session incorrectly

**Verify**:
`./scripts/run-tests.sh --suite dev --file ShortcutHoldOrToggleTests` (or extended engine file) → all pass.

### Step 5: Lint + lane

**Verify**: `make lint` then `make validate-agent`.

## Test plan

- Core engine tests as Step 4 (pattern: `ShortcutDefinitionAndEngineTests`).
- Manual (operator): with dictation set to Hybrid, verify short press leaves
  recording on; long press acts as PTT; pure Hold and Toggle still work.

## Done criteria

- [ ] Hybrid state machine lives in testable core code
- [ ] Characterization tests cover short/long/idle/recording cases
- [ ] Settings copy clearly distinguishes hold / toggle / hybrid
- [ ] Persisted `holdOrToggle` raw value unchanged
- [ ] `make lint` + `make validate-agent` recorded
- [ ] No out-of-scope files modified
- [ ] Ledger row updated

## STOP conditions

- Hybrid semantics in production differ from the table above in a way that
  changing them would break user muscle memory — stop and report before
  “fixing.”
- Moving logic into Core requires AppKit types inside MeetingAssistantCore.
- Verification fails twice after a reasonable fix.

## Maintenance notes

- Reviewers: watch for race between async `performAction` and key-up timing;
  existing GlobalShortcutController already awaits actions — do not introduce
  fire-and-forget starts that break PTT release-to-stop.
- Deferred: configurable threshold in Settings UI (not required here if default
  is correct).
