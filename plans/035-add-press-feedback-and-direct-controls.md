# Plan 035: Add immediate press feedback and direct-manipulation controls

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 546f869e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/design-system Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsRowClickSurface.swift Packages/MeetingAssistantCore/Sources/UI/components/transcription/TranscriptionAudioPlayerView.swift Packages/MeetingAssistantCore/Sources/UI/components/transcription/TranscriptionCardView.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/033-establish-apple-motion-system.md
- **Category**: tech-debt
- **Planned at**: commit `546f869e`, 2026-07-10

## Why this matters

The `apple-design` skill puts response first: controls should react at press-down, not only after click/tap completion. Prisma has several custom controls that are functionally correct but visually inert until the action fires. This plan adds a small reusable press surface and applies it to high-value custom controls without redesigning settings or transcription flows.

## Current state

- `DSToggleRow` toggles the row on tap but has no press-down visual state:

```text
DSToggleRow.swift:16 public var body: some View {
DSToggleRow.swift:38     Toggle("", isOn: $isOn)
DSToggleRow.swift:43 .contentShape(Rectangle())
DSToggleRow.swift:44 .onTapGesture {
DSToggleRow.swift:45     isOn.toggle()
```

- `SettingsRowClickSurface` captures mouseDown immediately, but it does not expose press state to SwiftUI content:

```text
SettingsRowClickSurface.swift:20 content()
SettingsRowClickSurface.swift:21     .contentShape(Rectangle())
SettingsRowClickSurface.swift:22     .overlay {
SettingsRowClickSurface.swift:94 override func mouseDown(with event: NSEvent) {
SettingsRowClickSurface.swift:97     if event.clickCount >= 2 {
SettingsRowClickSurface.swift:102    coordinator.handleSingleClick()
```

- `TranscriptionAudioPlayerView` has a direct scrubber gesture, which is the good local exemplar:

```text
TranscriptionAudioPlayerView.swift:46 .gesture(
TranscriptionAudioPlayerView.swift:47     DragGesture(minimumDistance: 0)
TranscriptionAudioPlayerView.swift:48         .onChanged { value in
TranscriptionAudioPlayerView.swift:49             let progress = max(0, min(1, value.location.x / geometry.size.width))
TranscriptionAudioPlayerView.swift:50             viewModel.seek(to: progress)
```

- `TranscriptionCardView` toggles expansion on the whole card with `onTapGesture`, which can compete with nested controls and has no explicit press surface:

```text
TranscriptionCardView.swift:97 public var body: some View {
TranscriptionCardView.swift:108 .contentShape(Rectangle())
TranscriptionCardView.swift:109 .onTapGesture {
TranscriptionCardView.swift:110     onToggleExpand()
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsRowClickSurface|TranscriptionAudioPlayer|TranscriptionSettingsViewModelTests'` | exit 0; all matching tests pass |
| Preview coverage | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Lint touched files | `swiftformat --lint Packages/MeetingAssistantCore/Sources/UI/components/design-system Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Sources/UI/components/transcription Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests` | exit 0 |

## Suggested executor toolkit

- Use `apple-design` for press feedback and gesture checklist.
- Use `accessibility-audit` if changing keyboard/focus semantics.
- Use `testing-xctest` if adding AppKit click-capture tests.

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/PressableButtonStyle.swift` or a similarly narrow new component
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSToggleRow.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorSupport.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsRowClickSurface.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/transcription/TranscriptionAudioPlayerView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/transcription/TranscriptionCardView.swift` only for hit-testing conflicts if needed
- Focused tests under `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests`
- `plans/README.md`

**Out of scope**:
- Do not redesign settings rows.
- Do not add haptics or sound feedback on macOS.
- Do not change transcription card action menus or destructive-action behavior.
- Do not replace native `Toggle`, `Button`, `Menu`, or `Picker` where the native control already gives correct feedback.

## Git workflow

- Branch: `ui/035-press-feedback-controls`
- Commit message: `feat(ui): add immediate press feedback to custom controls`
- Keep behavior and visual feedback changes together only where they are inseparable.

## Steps

### Step 1: Create a reusable press style for custom buttons

Add a small SwiftUI `ButtonStyle` that scales or tints controls while `configuration.isPressed` is true.

Requirements:

- Use plan 033's press spring.
- Scale should be subtle, around `0.97`.
- Respect Reduce Motion by using opacity/tint feedback without scale if needed.
- Expose a plain, reusable name such as `PressableButtonStyle`.

**Verify**: `make preview-check` -> exit 0.

### Step 2: Apply press feedback to action icon buttons

Update `ActionIconButton` in `FloatingRecordingIndicatorSupport.swift` to use the shared press style. Preserve current hover colors and keyboard shortcuts.

Do not change icons, help keys, or action semantics.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter RecordingIndicator` -> exit 0.

### Step 3: Add row press feedback without double toggles

Update `DSToggleRow` so the whole row gives immediate visual feedback before toggling. Prefer converting the row shell to a `Button` with `.buttonStyle(.plain)` or a custom press surface. Ensure clicking the native switch does not toggle twice.

Acceptance behavior:

- Clicking row label area toggles once.
- Clicking the switch toggles once.
- Row visibly responds while pressed.
- Accessibility remains a combined row with a toggle control where possible.

**Verify**: add or update a focused test if the current test harness can exercise the toggle; otherwise rely on preview/build and document the manual behavior in PR notes. `make preview-check` -> exit 0.

### Step 4: Improve scrubber feedback in TranscriptionAudioPlayerView

Keep the direct `DragGesture(minimumDistance: 0)`, but add visible press/drag state:

- track whether the pointer is actively scrubbing
- make the waveform/progress affordance brighten or scale subtly while scrubbing
- keep progress clamped to `0...1`
- keep seeking continuous during `.onChanged`

Do not add momentum to audio scrubbing; scrubbers should follow the pointer exactly.

**Verify**: `make preview-check` -> exit 0.

### Step 5: Reduce card hit-test conflicts if needed

If nested buttons in `TranscriptionCardView` accidentally trigger card expansion, replace the whole-card `onTapGesture` with a clearer click surface around only the collapsed card body or header area.

Do this only if you reproduce the conflict while testing. Do not redesign the card.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter TranscriptionSettingsViewModelTests` -> exit 0.

### Step 6: Validate and update the plan ledger

Update `plans/README.md` row 035 from `TODO` to `DONE`.

Run:

```bash
make preview-check
make build-agent
```

## Test plan

- Prefer focused unit tests for any new pure helper.
- Use previews to validate SwiftUI custom control compilation.
- Manual QA in PR notes should cover: row label click, switch click, icon button press, scrubber drag, nested transcription card buttons.

## Done criteria

- [ ] A reusable press feedback style exists.
- [ ] `ActionIconButton` and `DSToggleRow` show immediate press feedback.
- [ ] `DSToggleRow` does not double-toggle.
- [ ] Audio scrubber remains continuous and has visible drag state.
- [ ] `make preview-check` exits 0.
- [ ] `make build-agent` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- Adding row press feedback requires replacing native Settings controls broadly.
- Accessibility semantics regress and cannot be fixed locally.
- Transcription card hit testing requires a full card redesign.
- The implementation touches more than 8 source files.

## Maintenance notes

Future custom controls should use the shared press style instead of local hover-only behavior. Reviewers should pay close attention to double-trigger bugs whenever a row wraps a native control.
