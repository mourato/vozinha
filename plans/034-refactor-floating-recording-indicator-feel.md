# Plan 034: Make the floating recording indicator structurally ready for fluid interaction

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 546f869e..HEAD -- App/AppDelegate/RecordingUI.swift Packages/MeetingAssistantCore/Sources/UI/Presentation/FloatingRecordingIndicatorController.swift Packages/MeetingAssistantCore/Sources/UI/Presentation/RecordingIndicatorOverlayLayout.swift Packages/MeetingAssistantCore/Sources/UI/components/recording Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/033-establish-apple-motion-system.md
- **Category**: tech-debt
- **Planned at**: commit `546f869e`, 2026-07-10

## Why this matters

The floating recording indicator is Prisma's most visible live surface. It should feel immediate, anchored, and interruptible because it appears during recording, processing, confirmation, warnings, and Assistant flows. Today it works, but the implementation is too concentrated to evolve safely: one 1,235-line view mixes sizing, hover state, menus, overlays, countdowns, visualizers, and mode rendering. This plan decomposes it and replaces fixed fade/frame behavior with a foundation for Apple-style motion.

## Current state

- `FloatingRecordingIndicatorView.swift` is a large multi-responsibility view:

```text
FloatingRecordingIndicatorView.swift:12 public struct FloatingRecordingIndicatorView: View {
FloatingRecordingIndicatorView.swift:25 @Environment(\.accessibilityReduceMotion) private var reduceMotion
FloatingRecordingIndicatorView.swift:26 @State private var isHovering = false
FloatingRecordingIndicatorView.swift:27 @State private var hoverCollapseTask: Task<Void, Never>?
FloatingRecordingIndicatorView.swift:59 public var body: some View {
FloatingRecordingIndicatorView.swift:60     switch renderState.mode {
```

- Warning overlays use move+opacity transitions directly in the indicator:

```text
FloatingRecordingIndicatorView.swift:122 .overlay(alignment: .top) {
FloatingRecordingIndicatorView.swift:124     if let warningDescriptor = postProcessingWarningDescriptor {
FloatingRecordingIndicatorView.swift:126         .transition(.move(edge: .top).combined(with: .opacity))
FloatingRecordingIndicatorView.swift:129     if isRecordingMode, audioMonitor.isSilenceWarningVisible {
FloatingRecordingIndicatorView.swift:131         .transition(.move(edge: .top).combined(with: .opacity))
```

- Hover expansion already uses springs, but the constants live in layout tokens:

```text
FloatingRecordingIndicatorView.swift:1078 withAnimation(
FloatingRecordingIndicatorView.swift:1079     .spring(
FloatingRecordingIndicatorView.swift:1080         response: AppDesignSystem.Layout.recordingIndicatorHoverEnterResponse,
FloatingRecordingIndicatorView.swift:1081         dampingFraction: AppDesignSystem.Layout.recordingIndicatorHoverEnterDamping
```

- The controller fades the NSPanel and changes panel geometry with `setContentSize` / `setFrameOrigin`:

```text
FloatingRecordingIndicatorController.swift:168 if isRunningTests || prefersReducedMotion {
FloatingRecordingIndicatorController.swift:175 NSAnimationContext.runAnimationGroup { context in
FloatingRecordingIndicatorController.swift:176     context.duration = 0.12
FloatingRecordingIndicatorController.swift:177     panel.animator().alphaValue = 1
FloatingRecordingIndicatorController.swift:544 panel.setContentSize(panelContentSize(for: style, renderState: currentRenderState))
FloatingRecordingIndicatorController.swift:567 panel.setFrameOrigin(NSPoint(x: x, y: y))
```

- Prior project guidance says `MeetingDetector` must stay detector-only and recording presentation should reuse this floating indicator pipeline rather than creating a second overlay.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused indicator tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'FloatingRecordingIndicatorWidthTests|RecordingIndicatorOverlayLayoutTests|RecordingIndicatorRenderStateTests|RecordingIndicatorSuperConfigurationTests|RecordingIndicatorPostProcessingWarningTests'` | exit 0; all pass |
| AppKit lifecycle tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AssistantOverlayLifecycleTests|AssistantIndicatorActionWiringTests|MeetingNotesFloatingPanelControllerTests'` | exit 0; all pass |
| Preview coverage | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Full gate | `make lint && make build-test` | exit 0, or report known unrelated baseline separately |

## Suggested executor toolkit

- Use `apple-design` for interruptibility, spring, material, and Reduce Motion rules.
- Use `macos-app-engineering` for NSPanel/SwiftUI hosting boundaries.
- Use `testing-xctest` for indicator width and controller tests.

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift`
- New sibling files under `FloatingRecordingIndicatorView/`, for example `FloatingRecordingIndicatorMainPill.swift`, `FloatingRecordingIndicatorSuperCard.swift`, `FloatingRecordingIndicatorControls.swift`, `FloatingRecordingIndicatorOverlays.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorSupport.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorConfirmationView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/FloatingRecordingIndicatorController.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/FloatingRecordingIndicatorWidthTests.swift`
- New focused tests if needed
- `plans/README.md`

**Out of scope**:
- Do not create a new overlay/window/controller.
- Do not move automatic meeting countdown ownership into `MeetingDetector`.
- Do not change recording/transcription business logic.
- Do not redesign menu bar commands.
- Do not add drag-to-reposition unless the reviewer explicitly expands scope; this plan prepares geometry and motion for it but does not ship a new user-facing setting.

## Git workflow

- Branch: `ui/034-floating-indicator-feel`
- Commit message: `refactor(recording): prepare floating indicator for fluid motion`
- Split into two commits if useful: extraction first, motion/controller behavior second.

## Steps

### Step 1: Extract render subviews without behavior changes

Reduce `FloatingRecordingIndicatorView.swift` below 600 lines by extracting self-contained sibling views/functions. Keep public API stable.

Recommended extraction order:

1. main pill and shared pill background
2. super card and footer controls
3. overlay/warning composition
4. picker controls and action buttons if still too large

Keep sizing utilities in `FloatingRecordingIndicatorViewUtilities` until tests are adjusted. Do not copy sizing constants into new files.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` -> exit 0.

### Step 2: Replace local transitions with shared motion policy

Use the motion foundation from plan 033 for warning overlays, processing stage changes, confirmation countdown, and hover expansion. Requirements:

- Normal warning entry/exit uses the shared spring/move transition.
- Reduce Motion uses opacity-only transition.
- Hover expansion still starts immediately on pointer entry and collapses after the existing short grace period.
- Keep the current hover widths stable; do not reintroduce content-size loops.

**Verify**: `make preview-check` -> exit 0.

### Step 3: Centralize panel presentation animation

In `FloatingRecordingIndicatorController`, introduce a small private presentation helper for show/hide alpha animation and reduced-motion behavior. Requirements:

- Keep test path immediate.
- Keep Reduce Motion immediate or short opacity-only.
- Ensure hide completion still checks `visibilityTransitionID`.
- Do not block input while fade animation runs.

Prefer a minimal AppKit helper over a broad animation framework. If using `NSAnimationContext`, keep it isolated and named.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'AssistantOverlayLifecycleTests|AssistantIndicatorActionWiringTests'` -> exit 0.

### Step 4: Make geometry changes explicit and non-jumpy

Audit `applyPanelGeometry`, `panelWidth`, `panelHeight`, and `positionPanel`.

Target behavior:

- Size changes caused by mode/status updates remain deterministic and tested.
- Position changes are grouped with size updates to avoid visible jump between setContentSize and setFrameOrigin.
- Reduced Motion does not animate large panel movement.
- Future drag/reposition work can reuse the geometry helper without touching rendering code.

Do not animate panel frame unless you can prove it is smooth and interruptible on macOS with the current NSPanel setup. A well-structured non-animated geometry update is acceptable here.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` -> exit 0.

### Step 5: Add or update tests for extracted behavior

Add tests for any new pure sizing/motion helpers. Preserve existing long-duration timer coverage. If view extraction exposes testable pure helpers, test those rather than brittle rendered SwiftUI internals.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter 'FloatingRecordingIndicatorWidthTests|RecordingIndicatorOverlayLayoutTests|RecordingIndicatorRenderStateTests|RecordingIndicatorSuperConfigurationTests|RecordingIndicatorPostProcessingWarningTests'` -> exit 0.

### Step 6: Validate and update the plan ledger

Update `plans/README.md` row 034 from `TODO` to `DONE`.

Run:

```bash
make preview-check
make build-agent
make lint
make build-test
```

If `make build-test` fails only on the known unrelated `MetricsDashboardViewModelTests` baseline, record the exact failure and the focused passing indicator tests in the PR notes.

## Test plan

- Preserve and extend `FloatingRecordingIndicatorWidthTests`.
- Preserve `RecordingIndicatorOverlayLayoutTests`, `RecordingIndicatorRenderStateTests`, and `RecordingIndicatorSuperConfigurationTests`.
- Add focused tests for new pure geometry helpers if introduced.
- Use `make preview-check` because this is a SwiftUI decomposition.

## Done criteria

- [ ] `FloatingRecordingIndicatorView.swift` is below 600 lines or the PR notes justify why it remains above the limit and opens a follow-up.
- [ ] Indicator subviews are colocated under `FloatingRecordingIndicatorView/` with unique filenames.
- [ ] Warning/processing/hover transitions use the shared motion foundation.
- [ ] Reduce Motion behavior remains non-vestibular.
- [ ] Focused indicator tests pass.
- [ ] `make preview-check` and `make build-agent` pass.
- [ ] Full-lane gate attempted and result documented.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- The extraction requires changing recording manager, detector, or transcription behavior.
- NSPanel geometry changes trigger constraint-loop warnings or panel flicker that cannot be fixed locally.
- More than 8 source files outside the recording indicator family need changes.
- Existing indicator width tests become unmaintainable because sizing moved into SwiftUI-only view state.

## Maintenance notes

The long-term goal is a draggable, interruptible, velocity-aware floating surface. This plan deliberately stops before user-facing drag/reposition behavior so the structural decomposition lands first. Reviewers should scrutinize any duplicated sizing math and any new animation that changes `frame` every tick.
