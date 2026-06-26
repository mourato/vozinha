# Plan 003: Decide imported-recording meeting behavior

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 48329a03..HEAD -- README.md Packages/MeetingAssistantCore/Sources/Domain/Models Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionImportViewModel.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel Packages/MeetingAssistantCore/Sources/UI/components/shared/TranscribeFileButton.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ImportAudioUseCaseMacroMockingTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `48329a03`, 2026-06-25

## Why this matters

Prisma advertises file import and already transcribes dropped audio/video files. But imported recordings are explicitly excluded from meeting conversation features, source retagging, and meeting title persistence. That makes old meeting recordings second-class even though they are a natural local-first use case.

This is a product decision first. The executor should make the smallest design spike that resolves the behavior: either keep imports as transcription-only and make the UI copy explicit, or support a "meeting import" path that enables summaries/Q&A/meeting title for imported recordings.

## Current state

- `README.md:12` advertises file import.
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionImportViewModel.swift:27` supports file picker import:

```swift
public func selectAndImportFile() {
    let panel = NSOpenPanel()
    ...
    panel.allowedContentTypes = [
        .audio, .mpeg4Audio, .mp3, .wav,
        .movie, .mpeg4Movie, .quickTimeMovie,
    ]
```

- `Packages/MeetingAssistantCore/Sources/Domain/Models/Meeting.swift:161` blocks imported files from meeting conversation:

```swift
public var supportsMeetingConversation: Bool {
    capturePurpose == .meeting && app != .importedFile
}
```

- `Packages/MeetingAssistantCore/Sources/Domain/Models/TranscriptionMetadata.swift:34` repeats the same rule:

```swift
public var supportsMeetingConversation: Bool {
    capturePurpose == .meeting && meetingApp != .importedFile
}
```

- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/TranscriptionSettingsViewModel/ConversationAndPostProcessing.swift:577` prevents retagging imported files:

```swift
func updateCapturePurpose(for metadata: TranscriptionMetadata, to capturePurpose: CapturePurpose) async {
    let metadataApp = DomainMeetingApp(rawValue: metadata.appRawValue) ?? .unknown
    guard metadataApp != .importedFile else { return }
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Direction tests | `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` | exit 0 |
| Import tests | `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ImportAudioUseCaseMacroMockingTests.swift` | exit 0 |
| Preview check | `make preview-check` | exit 0 if UI changed |
| Build | `make build-agent` | exit 0 |
| Full-lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- A short design note under `plans/003-imported-recording-decision.md` or a GitHub issue if the operator asks for issue publication.
- If implementing the narrow approved behavior in the same branch: domain support predicates, import view model labels/options, transcription settings view-model tests, localization strings.

**Out of scope**:
- Do not add cloud sync.
- Do not redesign the whole import screen.
- Do not change provider/model retry eligibility except where imported meeting behavior requires source classification.
- Do not enable meeting Q&A for imported files unless the design decision explicitly chooses that behavior.

## Git workflow

- Branch: `advisor/003-imported-recording-meeting-behavior`
- Use Conventional Commits, for example: `feat(transcription): classify imported recordings for meeting analysis`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Write the product decision before code

Create a short decision note in `plans/003-imported-recording-decision.md` with one selected option:

- Option A: imports remain transcription-only. Update UI copy so users do not expect meeting Q&A/summaries.
- Option B: imports can be classified as meeting recordings. Imported meeting recordings support meeting title, summaries, and Q&A.

Recommended answer: Option B, because local-first users often have past calls they cannot capture live, and the app already supports imported audio/video transcription.

**Verify**: `git diff -- plans/003-imported-recording-decision.md` -> note exists and states one selected option.

### Step 2: If Option B is selected, add an explicit imported meeting classification

Avoid silently changing all imported files. Add an explicit way for import to produce a meeting capture purpose, for example:

- import UI asks or defaults with a compact control for "Meeting recording" vs "Dictation/audio note"
- imported meeting keeps `MeetingApp.importedFile`, but `capturePurpose == .meeting`
- domain `supportsMeetingConversation` checks `capturePurpose == .meeting` and no longer excludes `.importedFile`

Update both domain model surfaces:

- `Packages/MeetingAssistantCore/Sources/Domain/Models/Meeting.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Domain/Entities/MeetingEntity.swift`
- `Packages/MeetingAssistantCore/Sources/Domain/Models/TranscriptionMetadata.swift`

**Verify**: `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ImportAudioUseCaseMacroMockingTests.swift` -> exit 0.

### Step 3: Let imported meeting metadata use meeting actions

If Option B is selected:

- remove or narrow the guard at `ConversationAndPostProcessing.swift:577`
- allow imported meeting metadata to open meeting conversation when `capturePurpose == .meeting`
- preserve dictation behavior for imported files classified as dictation
- add tests proving imported meeting supports conversation and imported dictation does not

**Verify**: `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` -> exit 0.

### Step 4: Update UI copy and localization

If Option A is selected, update import/history copy to clarify imports are transcription-only.

If Option B is selected, add localized labels for the classification control and any changed action text. Follow the repo rule: user-facing strings must use `"key".localized`.

**Verify**: `make preview-check` -> exit 0 if SwiftUI views changed.

### Step 5: Run compile and lint gates

This is a Medium-risk Full-lane change because it changes user-facing workflow and domain support predicates.

**Verify**: `make build-agent` -> exit 0.

**Verify**: `make lint` -> exit 0.

## Test plan

- Add tests for `supportsMeetingConversation` on imported meeting vs imported dictation.
- Add view-model tests for imported metadata actions.
- Preserve existing tests that protect retry eligibility and imported-file retry behavior.

## Done criteria

- [ ] A decision note exists and selects Option A or Option B.
- [ ] If Option A: UI copy clearly says imported files are transcription-only.
- [ ] If Option B: imported meeting recordings can use meeting conversation/Q&A actions, while imported dictation/audio notes cannot.
- [ ] All new user-facing text is localized.
- [ ] `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/TranscriptionSettingsViewModelTests.swift` exits 0.
- [ ] `./scripts/run-tests.sh --file Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ImportAudioUseCaseMacroMockingTests.swift` exits 0.
- [ ] `make build-agent` exits 0.
- [ ] `make lint` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- The desired product behavior cannot be resolved from code and the operator has not accepted Option A or Option B.
- Enabling meeting conversation for imported files would expose missing persisted fields that require a Core Data migration.
- The change requires broad retry/transcription provider eligibility changes.
- Any verification command fails twice after a reasonable fix attempt.

## Maintenance notes

Imported recordings should stay explicit. Reviewers should reject a change that makes every import a meeting by accident, because dictation/audio-note imports are still valid. If Option B lands, update any future history filtering and metrics work to treat imported meetings as meeting capture purpose without assuming a detected meeting app.
