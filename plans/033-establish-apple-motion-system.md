# Plan 033: Establish the Apple-style motion and material foundation

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 546f869e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppDesignSystem.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsWindowBackground.swift Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSCard.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `546f869e`, 2026-07-10

## Why this matters

Prisma has individual motion decisions, but no central interaction vocabulary that maps the new `apple-design` guidance into reusable SwiftUI APIs. That forces each feature to choose its own `easeInOut`, transition, material fallback, and Reduce Motion behavior. This plan creates the small shared foundation that later plans can reuse instead of adding bespoke animation constants to each surface.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift` owns the only named motion helper for settings, and it is a fixed-duration ease:

```text
SettingsMotion.swift:3 enum SettingsMotion {
SettingsMotion.swift:4     static let sectionDuration: Double = 0.18
SettingsMotion.swift:5     static var sectionAnimation: Animation {
SettingsMotion.swift:6         .easeInOut(duration: sectionDuration)
SettingsMotion.swift:9     static func sectionTransition(reduceMotion: Bool = false) -> AnyTransition {
SettingsMotion.swift:10        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
```

- `AppDesignSystem` already centralizes accessibility and recording-indicator hover constants:

```text
AppDesignSystem.swift:18 public enum Accessibility {
AppDesignSystem.swift:19     public static var reduceTransparency: Bool {
AppDesignSystem.swift:20         NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
AppDesignSystem.swift:23     public static var increaseContrast: Bool {
AppDesignSystem.swift:24         NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
AppDesignSystem.swift:344    public static let recordingIndicatorHoverEnterResponse: CGFloat = 0.22
AppDesignSystem.swift:345    public static let recordingIndicatorHoverEnterDamping: CGFloat = 0.86
```

- `SettingsWindowBackground` already has a Reduce Transparency fallback and should remain the shell-material owner:

```text
SettingsWindowBackground.swift:18 if AppDesignSystem.Accessibility.reduceTransparency {
SettingsWindowBackground.swift:19     AppDesignSystem.Colors.windowBackground
SettingsWindowBackground.swift:22     VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
SettingsWindowBackground.swift:26     AppDesignSystem.Colors.settingsWindowMaterialOverlay
```

- The new `apple-design` skill says the default UI spring should be critically damped, Reduce Motion should use short opacity transitions, and translucent chrome should not rely on hard dividers.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AppleMotion|SettingsMotion|AppDesignSystem'` | exit 0; all matching tests pass |
| Preview coverage | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Lint touched files | `swiftformat --lint Packages/MeetingAssistantCore/Sources/UI/components/design-system Packages/MeetingAssistantCore/Sources/UI/components/settings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests` | exit 0 |

## Suggested executor toolkit

- Use `macos-app-engineering` for SwiftUI/AppKit shell conventions.
- Use `apple-design` for spring, material, Reduce Motion, and typography rules.
- Use `testing-xctest` for focused XCTest helpers.

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppDesignSystem.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppleMotion.swift` (create if needed)
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsWindowBackground.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSCard.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppleMotionTests.swift` (create)
- `plans/README.md`

**Out of scope**:
- Do not refactor `FloatingRecordingIndicatorView` in this plan; plan 034 owns that.
- Do not change onboarding screens; plan 037 owns that.
- Do not do broad typography migration; plan 036 owns that.
- Do not create a second design system or duplicate `AppDesignSystem`.

## Git workflow

- Branch: `ui/033-apple-motion-system`
- Commit message: `feat(ui): add Apple motion foundation`
- Keep this as one product-code commit plus tests. Do not push or open a PR unless instructed.

## Steps

### Step 1: Add a small shared motion vocabulary

Create `AppleMotion.swift` under `components/design-system` or extend `AppDesignSystem` if the reviewer prefers fewer files. The API must expose these values:

- `defaultSpring`: `.spring(response: 0.35, dampingFraction: 1.0)`
- `interactiveSpring`: `.spring(response: 0.3, dampingFraction: 0.85)`
- `pressSpring`: `.spring(response: 0.15, dampingFraction: 1.0)`
- `reduceMotionFade`: `.easeInOut(duration: 0.2)`
- `transition(reduceMotion:edge:)` returning `.opacity` for Reduce Motion and `.move(edge:).combined(with: .opacity)` otherwise
- `animation(reduceMotion:kind:)` returning `reduceMotionFade` for Reduce Motion where a value animation is still useful, and `nil` only when no animation should run

Keep names direct. Avoid generic abstractions like `MotionPresetProtocol`.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter AppleMotion` -> either no tests yet or all new tests pass after Step 2.

### Step 2: Add focused tests for motion policy

Create `AppleMotionTests.swift`. Test only deterministic API behavior:

- Reduce Motion transition uses `.opacity` by constructing a value through a helper if direct `AnyTransition` equality is not possible.
- Default and interactive values are reachable through named APIs.
- Existing recording-indicator hover constants remain unchanged unless intentionally moved.

If SwiftUI animation equality is not practical, test through public enum cases or helper return values instead of fragile string descriptions.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter AppleMotion` -> exit 0.

### Step 3: Route SettingsMotion through the shared foundation

Update `SettingsMotion` so section animation and section transition use the new motion vocabulary:

- Normal section reveal should use the default spring or a named non-bouncy settings spring.
- Reduce Motion should use a short opacity transition, not `nil` everywhere.
- Keep existing call sites source-compatible where possible.

Do not remove `SettingsMotion`; existing settings call sites should continue compiling.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter SettingsMotion` -> exit 0 or no matching tests; then `make preview-check` -> exit 0.

### Step 4: Add material/high-contrast helpers without restyling every surface

Extend `AppDesignSystem` with narrowly named helpers for:

- material-backed settings card fill
- reduced-transparency fallback
- increased-contrast stroke
- titlebar bottom treatment that can later replace hard dividers

Update `DSCard(style: .settings)` and `SettingsWindowBackground` only if this reduces duplication and preserves current appearance. Keep visual changes minimal in this foundation plan.

**Verify**: `make preview-check` -> exit 0.

### Step 5: Update the plan ledger

Update `plans/README.md` row 033 from `TODO` to `DONE` after implementation.

**Verify**: `make build-agent` -> exit 0.

## Test plan

- New `AppleMotionTests.swift` covers named motion policy and Reduce Motion helper behavior.
- Existing preview coverage checks should catch missing SwiftUI previews after file creation.
- Build gate confirms new package file is discovered by SwiftPM.

## Done criteria

- [ ] New motion foundation exists and is reused by `SettingsMotion`.
- [ ] Reduce Motion policy returns short opacity-based feedback instead of simply dropping all animation where feedback is useful.
- [ ] Settings material helpers preserve existing Reduce Transparency behavior.
- [ ] `swift test --package-path Packages/MeetingAssistantCore --filter 'AppleMotion|SettingsMotion|AppDesignSystem'` exits 0.
- [ ] `make preview-check` exits 0.
- [ ] `make build-agent` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- Adding `AppleMotion.swift` is not picked up by the Swift package after `make build-agent`.
- The new helper requires touching more than 8 source files.
- Preview checks fail in unrelated surfaces and the failure is not clearly caused by this change.
- The implementation starts changing visible layout or indicator behavior; that belongs to later plans.

## Maintenance notes

Future UI work should use this foundation for spring values, Reduce Motion, and material fallbacks. Reviewers should reject new local `.easeInOut(duration:)` constants in interactive surfaces unless the PR explains why the shared motion vocabulary is not suitable.
