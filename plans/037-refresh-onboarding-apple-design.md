# Plan 037: Refresh onboarding with scalable Apple-style layout and transitions

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 546f869e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/onboarding Packages/MeetingAssistantCore/Sources/UI/components/onboarding Packages/MeetingAssistantCore/Sources/UI/ViewModels/OnboardingViewModel.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/033-establish-apple-motion-system.md, plans/036-normalize-typography-and-scaled-layout.md
- **Category**: direction
- **Planned at**: commit `546f869e`, 2026-07-10

## Why this matters

Onboarding is the first-run trust surface for a local-first recorder that needs permissions, model readiness, shortcuts, and meeting setup. The current flow is honest and functional, but visually it predates the new Apple-design bar: fixed window/layout, opaque background, fixed icon sizes, and step changes without spatial continuity. This plan modernizes onboarding without changing readiness semantics.

## Current state

- `OnboardingView` uses a fixed window-sized frame and opaque background:

```text
OnboardingPage.swift:39 public var body: some View {
OnboardingPage.swift:40     VStack(spacing: 0) {
OnboardingPage.swift:42         OnboardingStepIndicator(...)
OnboardingPage.swift:49         contentView
OnboardingPage.swift:55 .frame(width: 620, height: 520)
OnboardingPage.swift:56 .background(Color(NSColor.windowBackgroundColor))
```

- The welcome step uses a large fixed SF Symbol and simple centered content:

```text
OnboardingWelcomeView.swift:18 Image(systemName: "waveform.circle.fill")
OnboardingWelcomeView.swift:21 .frame(width: 100, height: 100)
OnboardingWelcomeView.swift:26 Text("onboarding.welcome.title".localized)
OnboardingWelcomeView.swift:41 Button("onboarding.welcome.button".localized, action: onGetStarted)
```

- The step indicator uses fixed circles and fixed ease animations:

```text
OnboardingStepIndicator.swift:40 Circle()
OnboardingStepIndicator.swift:42 .frame(width: 32, height: 32)
OnboardingStepIndicator.swift:59 .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCompleted)
OnboardingStepIndicator.swift:60 .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCurrent)
```

- Prior onboarding implementation guidance says completion must stay honest about readiness and the meeting capability step must explicitly enable `isMeetingTranscriptionEnabled`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused onboarding tests | `swift test --package-path Packages/MeetingAssistantCore --filter Onboarding` | exit 0; all onboarding tests pass |
| Preview coverage | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Lint touched files | `swiftformat --lint Packages/MeetingAssistantCore/Sources/UI/pages/onboarding Packages/MeetingAssistantCore/Sources/UI/components/onboarding Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests` | exit 0 |

## Suggested executor toolkit

- Use `apple-design` for spatial transitions, materials, Reduce Motion, and typography.
- Use `macos-app-engineering` for SwiftUI window/sheet layout.
- Use `accessibility-audit` if changing focus, reduced motion, or VoiceOver grouping.

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/pages/onboarding/OnboardingPage.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingWelcomeView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingStepIndicator.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingPermissionRow.swift`
- Other onboarding step views only for shared layout extraction
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/*Onboarding*`
- `plans/README.md`

**Out of scope**:
- Do not change onboarding readiness rules.
- Do not remove the meeting recording step.
- Do not change permission request behavior.
- Do not change model download behavior.
- Do not create marketing/landing-page content.

## Git workflow

- Branch: `ui/037-onboarding-apple-design`
- Commit message: `refactor(onboarding): refresh first-run layout and motion`
- Keep behavior-preserving layout work and any test updates in one commit.

## Steps

### Step 1: Extract a shared onboarding container

Create a small container component inside the onboarding folder to own:

- material-aware background
- max content width
- responsive vertical spacing
- Reduce Transparency fallback
- common padding

Use existing `SettingsWindowBackground` or `AppDesignSystem` material helpers when possible. Do not duplicate a new visual-effect bridge.

**Verify**: `make preview-check` -> exit 0.

### Step 2: Replace fixed root sizing with scalable constraints

Update `OnboardingView` so content can adapt within the hosting window:

- keep the window's current default size through `OnboardingWindowController`
- replace hard root `.frame(width:height:)` with min/max constraints where possible
- preserve comfortable first-run composition at 620x520
- avoid text clipping at larger Dynamic Type sizes

**Verify**: `make preview-check` -> exit 0.

### Step 3: Add spatial step transitions

Use the shared motion foundation for step changes:

- normal motion: same spring both forward and backward
- Reduce Motion: opacity-only transition
- transition should preserve orientation; do not randomly insert from one edge and remove from another
- do not block controls during transition

If `OnboardingViewModel` does not expose direction, add minimal local state in `OnboardingView` to compare old and new step index. Do not move navigation logic out of the view model.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter Onboarding` -> exit 0.

### Step 4: Modernize the step indicator without changing semantics

Apply plan 036 typography/scaled metrics to `OnboardingStepIndicator`:

- scaled circle size
- semantic fonts
- shared motion foundation
- same accessibility label
- no hidden progress state changes

**Verify**: `make preview-check` -> exit 0.

### Step 5: Refresh welcome and permission rows

Update welcome and permission rows to use:

- semantic fonts and scaled icon sizes
- `.foregroundStyle` instead of fixed `.foregroundColor` where applicable
- material/card styling from the design system
- immediate press feedback for custom row/button wrappers where plan 035 APIs are available

Do not add repeated explanatory copy. Keep onboarding concise.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter Onboarding` -> exit 0.

### Step 6: Validate and update the plan ledger

Update `plans/README.md` row 037 from `TODO` to `DONE`.

Run:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter Onboarding
make preview-check
make build-agent
```

## Test plan

- Existing onboarding tests must continue to pass.
- Add tests only if transition direction/state logic enters a testable helper.
- Manual PR notes should cover Reduce Motion, larger Dynamic Type preview, and the meeting-readiness completion state.

## Done criteria

- [ ] Onboarding root no longer relies on a fixed content frame for layout.
- [ ] Step transitions use the shared motion foundation and respect Reduce Motion.
- [ ] Welcome, step indicator, and permission rows use semantic/scaled typography.
- [ ] Readiness and completion behavior are unchanged.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter Onboarding` exits 0.
- [ ] `make preview-check` exits 0.
- [ ] `make build-agent` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- The refresh requires changing permission/model/meeting readiness behavior.
- Layout changes require replacing `OnboardingWindowController`.
- Dynamic Type fixes require touching non-onboarding settings surfaces.
- New motion causes test flakiness or blocks interaction during transition.

## Maintenance notes

Onboarding should remain a setup workflow, not a marketing page. Future changes should preserve honest readiness reporting and use the shared motion/typography policies instead of local fixed constants.
