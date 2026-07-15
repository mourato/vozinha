# Plan 091: Remove the empty Meeting Transcription Form row before Pyannote

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat cfb72f45..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceMeetingTranscriptionSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceTranscriptionProviderSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift \
>   plans/README.md
> ```
>
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `cfb72f45`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of plans 090 and 092
- **Reviewer required**: `no` — mechanical Form-row cleanup with a clear root cause
- **Rationale**: Single-file layout bug; no persistence, concurrency, or API change
- **Escalate when**: Fix requires restructuring download/delete behavior, ViewModel
  API changes, or touching more than three source files

## Why this matters

In Meetings → Meeting Transcription, users see Model picker, then a blank row
with horizontal separators and a stray vertical divider, then the Pyannote
download/remove block. That blank row is not intentional UI — it is a bare
`Divider()` treated as its own grouped-Form row. Removing it restores a clean
native section between model selection and diarization install status.

## Current state

`ServiceMeetingTranscriptionSection.swift` builds one `Section` with:

1. Caption `Text` (description)
2. Model `Picker`
3. Optional `DSCallout` when `shouldShowMeetingDiarizationAutoDisableWarning`
4. **`Divider()`** ← becomes an empty Form row under `.formStyle(.grouped)`
5. `HStack` with Pyannote name / description / install state + Download/Remove

Relevant excerpt:

```swift
Picker(
    "settings.service.model".localized,
    selection: Binding(
        get: { viewModel.selectedMeetingLocalModel },
        set: { viewModel.updateMeetingLocalModel($0) },
    ),
) {
    ForEach(viewModel.localModels) { localModel in
        Text(localModel.displayName).tag(localModel.model)
    }
}
.pickerStyle(.menu)

if viewModel.shouldShowMeetingDiarizationAutoDisableWarning {
    DSCallout(/* ... */)
}

Divider() // ← empty Form row / phantom vertical divider

HStack(alignment: .top, spacing: 12) {
    // Pyannote copy + Download/Remove
}
```

Grouped `Form` already draws separators between rows. Manual `Divider()` inside
a Section is redundant and, on macOS, commonly renders as a near-empty row
(matching the screenshot).

Sibling pattern: `ServiceTranscriptionProviderSection.swift` is the Dictation
provider/model Form section — use it as the structural reference for “native
rows, no decorative Dividers between scalar rows.”

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Confirm Divider sites | `rg -n "Divider\\(\\)" Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceMeetingTranscriptionSection.swift` | After fix: no matches (or only justified non-Form usage — prefer zero) |
| Preview inventory | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Lint | `make lint-agent` | exit 0 |
| Fast validate | `make validate-agent ARGS="--lane fast --agent"` | PASS |

## Suggested executor toolkit

- `macos-app-engineering` for Form/`Section` row anatomy
- Do not invent a new card wrapper for Pyannote

## Scope

**In scope**:

- `Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceMeetingTranscriptionSection.swift`
- Optional tiny preview polish in the same file if the existing `#Preview` still
  compiles
- `plans/README.md` status row

**Out of scope**:

- Diarization download/delete behavior or `ServiceSettingsViewModel`
- Speaker Identification section (separate control; plan 090 owns its toggle style)
- Dictation transcription provider section behavior changes
- Activity dashboard (plan 092)
- Boolean control style pass (plan 090)

## Git workflow

- Branch: `fix/091-meeting-transcription-empty-form-row`
- Commit: `fix(settings): remove empty Meeting Transcription Form divider row`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Delete the bare Form `Divider`

Remove the `Divider()` between the model picker / warning callout and the
Pyannote `HStack` in `ServiceMeetingTranscriptionSection.swift`.

Keep:

- description caption
- model picker
- conditional diarization warning callout
- Pyannote status + Download/Remove actions

Do not replace the Divider with another empty spacer, `Rectangle`, or nested
card. Rely on native Form row separators.

**Verify**:
`rg -n "Divider\\(\\)" Packages/MeetingAssistantCore/Sources/UI/components/settings/ServiceMeetingTranscriptionSection.swift`
→ no matches.

### Step 2: Flatten Pyannote into Form-friendly rows if the HStack still looks odd

After removing the Divider, open the Meetings preview / run the app mentally
against Form anatomy:

- If the Pyannote block still creates a single oversized custom row with a
  trailing vertical guide artifact, split it into native rows, for example:
  - title + status as `LabeledContent` / stacked `Text`
  - Download/Remove as a trailing button on that row or the next row
- Prefer the smallest change that removes empty chrome. Do **not** wrap the
  block in `DSCard`/`DSGroup` inside the Form Section.

**Verify**: `make preview-check` → exit 0; visual expectation: Model row, then
Pyannote content, with no blank sandwiched row.

### Step 3: Validate

Run build + lint + Fast `validate-agent`.

**Verify**: Commands table Fast gate → PASS; update ledger row to DONE.

## Test plan

- No new unit test is required for removing a decorative Divider.
- Preview in `ServiceMeetingTranscriptionSection.swift` must remain present
  (`make preview-check`).
- Manual check on Meetings tab: no empty row between Model and Pyannote;
  Download/Remove still works for installed and not-installed states.

## Done criteria

- [ ] No bare `Divider()` remains in `ServiceMeetingTranscriptionSection.swift`
- [ ] No blank Form row between model picker and Pyannote block
- [ ] Download/Remove and warning callout behavior unchanged
- [ ] `make preview-check`, `make build-agent`, `make lint-agent`, Fast
      `validate-agent` PASS
- [ ] No files outside Scope modified
- [ ] `plans/README.md` status updated

## STOP conditions

- Empty row persists after Divider removal — stop and report the remaining
  view identity (likely a nested `HStack`/`VStack` Form-row issue) instead of
  inventing a second container system.
- Fix appears to need ViewModel or localization changes.
- Scope creeps into Speaker Identification or Dictation provider sections.

## Maintenance notes

- Reviewers: reject new bare `Divider()` inside Settings `Form`/`Section`
  content unless there is a documented non-row use.
- Plan 080 already warned to flatten unnecessary VStacks so native rows own
  separators; this bug is the same class of regression.
