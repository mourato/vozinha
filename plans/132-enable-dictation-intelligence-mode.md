# Plan 132: Enable dictation Intelligence Kernel mode

> **Executor instructions**: Follow this brief step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the local status row in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 08124206..HEAD -- Packages/MeetingAssistantCore/Sources/Common/Config/FeatureFlags.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ComputedProperties.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessing.swift Packages/MeetingAssistantCore/Sources/UI/Services/PostProcessingConfigurationProvider.swift Packages/MeetingAssistantCore/Sources/AI/Services/MeetingQAService.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/IntelligenceKernelContractsTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none strictly; prefer after 128–131 to reduce RecordingManager merge conflict noise
- **Category**: tech-debt
- **Planned at**: commit `08124206`, 2026-09-04
- **Finding ID**: `enable-dictation-intelligence-kernel-mode`
- **Publication**: local
- **Parent issue**: none
- **Issue**: none
- **Integration**: isolated worktree → merge to local `main` only when operator asks; no push unless requested

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` vs 129; `no` vs heavy RecordingManager post-processing edits in 128–131 unless rebased
- **Reviewer required**: `yes` — kernel mode flags are cross-cutting trust/routing surface
- **Rationale**: Flag flip is small, but removing hard-coded dictation bypasses can change when enhancement runs; needs contract tests.
- **Escalate when**: Scope expands to dictation Q&A product UI, canonical summary for dictation, or assistant mode enablement.

## Why this matters

`FeatureFlags.enableDictationIntelligenceMode` is still `false` (“Reserved for a
future phase”), while RecordingManager already runs dictation with
`IntelligenceKernelMode.dictation` and **hard-codes** dictation enhancement
gating to `true` instead of `isIntelligenceKernelModeEnabled(.dictation)`.
That split creates two mental orchestrators: kernel flags say off, runtime says
on. Completing the rollout flips the flag and routes dictation through the same
gate as meeting/assistant — without inventing dictation Meeting Q&A.

## Current state

```13:15:Packages/MeetingAssistantCore/Sources/Common/Config/FeatureFlags.swift
    /// Enables dictation mode execution through the shared intelligence kernel.
    /// Reserved for a future phase.
    public static let enableDictationIntelligenceMode: Bool = false
```

```141:151:Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ComputedProperties.swift
    func isIntelligenceKernelModeEnabled(_ mode: IntelligenceKernelMode) -> Bool {
        guard intelligenceKernelEnabled else { return false }
        switch mode {
        case .meeting: return FeatureFlags.enableMeetingIntelligenceMode
        case .dictation: return FeatureFlags.enableDictationIntelligenceMode
        case .assistant: return FeatureFlags.enableAssistantIntelligenceMode
        }
    }
```

Dictation bypass examples:

```252:257:Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/PostProcessing.swift
        let kernelModeEnabled: Bool = switch kernelMode {
        case .dictation:
            true
        case .meeting, .assistant:
            settings.isIntelligenceKernelModeEnabled(kernelMode)
        }
```

Same pattern in `PostProcessingConfigurationProvider.shouldApplyEnhancementsPostProcessing`.

`MeetingQAService.ask(_ request:)` still throws `.disabled` for `.dictation`
even if the flag were true — keep that unless this plan explicitly adds Q&A
(it must not).

Contract test today expects dictation mode **disabled**:
`IntelligenceKernelContractsTests.testAppSettingsReportsMeetingModeEnabledByDefault`.

Guidance: `.agents/skills/intelligence-kernel/SKILL.md` mode gating section.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift | `git diff --stat 08124206..HEAD -- <in-scope paths>` | empty or reviewed |
| Kernel contracts | `./scripts/run-tests.sh --suite dev --file IntelligenceKernelContractsTests` | all pass |
| Post-process related | `./scripts/run-tests.sh --suite dev --file PostProcessing*` (adjust to actual filenames present) | all pass |
| Lint | `make lint` | exit 0 / known baseline |
| Lane | `make validate-agent` | PASS / documented baseline |

## Suggested executor toolkit

- Project `intelligence-kernel` skill (required)
- `test-hygiene`
- Bind `delivery-contract` + worktree gate before first patch

## Scope

**In scope**:

- `FeatureFlags.swift` — set `enableDictationIntelligenceMode = true`; update comment
- `PostProcessing.swift` / `PostProcessingConfigurationProvider.swift` — remove
  dictation hard-coded `true`; use `isIntelligenceKernelModeEnabled`
- Any other call sites that special-case dictation kernel enablement the same way
  (grep `case .dictation:` near kernel gates before editing)
- `IntelligenceKernelContractsTests.swift` (+ related tests that assert false)
- Brief note in `.agents/skills/intelligence-kernel/SKILL.md` only if the
  “future phase” wording would become false (guidance-only; run
  `make guidance-check` if touched)

**Out of scope**:

- Implementing dictation Q&A answers in `MeetingQAService`
- Enabling `enableAssistantIntelligenceMode`
- Changing `dictationStructuredPostProcessingEnabled` default
- Plans 128–131 residency/shortcut/gate work
- New Settings toggles for kernel modes
- Copying VoiceInk code

## Git workflow

- Branch: `feat/enable-dictation-intelligence-mode`
- Commit style: `feat(kernel): enable dictation intelligence mode gating`
- Do NOT push unless requested

## Steps

### Step 1: Inventory call sites

Grep and list every place that:

- reads `enableDictationIntelligenceMode`
- hard-codes dictation kernel enablement
- branches on `IntelligenceKernelMode.dictation` for trust/QA/post-process gates

Paste the inventory into the PR/commit body (not into product logs).

**Verify**: inventory complete; no surprise UI that would light up Q&A for dictation.

### Step 2: Flip flag + unify gates

1. Set `enableDictationIntelligenceMode = true`.
2. Replace dictation hard-coded `true` enable checks with
   `settings.isIntelligenceKernelModeEnabled(kernelMode)` (including dictation).
3. Preserve existing dictation product behavior for enhancements:
   - Today dictation enhancements can run even when meeting post-processing
     global flag differs — keep the **product** rules in
     `shouldApplyEnhancementsPostProcessing` / style `postProcessingEnabled`,
     but the kernel **mode gate** must be honest.
4. Leave `MeetingQAService` dictation branch returning `.disabled` (explicit
   comment: Q&A not in this phase).

**Verify**: update `IntelligenceKernelContractsTests` to expect dictation
enabled; add a test that `ask(mode: .dictation)` still throws disabled.

### Step 3: Regression around enhancement gating

Add/adjust tests so that:

- With kernel globally on + dictation mode flag on → dictation enhancements still
  honor style/`postProcessingEnabled` / readiness issues.
- If someone sets `enableIntelligenceKernel = false` (via FeatureFlags in test
  doubles if available) → dictation enhancements do not bypass the kernel off
  switch. If FeatureFlags are static lets and cannot be toggled in tests, document
  that limitation and test the `isIntelligenceKernelModeEnabled` function logic
  via a test seam or by asserting current flag matrix only.

**Verify**: focused kernel + post-processing tests pass.

### Step 4: Lint + lane (+ guidance-check if skill text changed)

**Verify**: `make lint`; `make guidance-check` if `.agents/` touched; `make validate-agent`.

## Test plan

- Update `IntelligenceKernelContractsTests` expectations
- Explicit: dictation Q&A remains disabled
- Enhancement gating still respects style/readiness
- Pattern: existing kernel contract tests

## Done criteria

- [ ] `enableDictationIntelligenceMode == true`
- [ ] No hard-coded `true` for dictation kernel enablement in post-process gates
- [ ] Dictation Q&A still disabled
- [ ] Contract tests updated and passing
- [ ] Validation commands recorded
- [ ] No out-of-scope files modified
- [ ] Ledger row updated

## STOP conditions

- Flipping the flag disables dictation enhancements in production paths (behavior
  regression) — stop and fix gating composition before merge.
- Completing the mode appears to require shipping dictation Q&A UI — out of
  scope; report and keep Q&A disabled.
- Verification fails twice after a reasonable fix.

## Maintenance notes

- Reviewers: distinguish **kernel mode enabled** from **style post-processing
  enabled** and from **structured dictation pipeline** flag.
- Follow-up (not this plan): dictation grounded Q&A, assistant mode flag.
