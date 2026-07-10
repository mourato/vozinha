# Plan 036: Normalize typography and scaled layout in core UI surfaces

> **Executor instructions**: Follow this plan step by step. Run every verification command and confirm the expected result before moving to the next step. If anything in the "STOP conditions" section occurs, stop and report; do not improvise. When done, update the status row for this plan in `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 546f869e..HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppDesignSystem.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsSidebarView.swift Packages/MeetingAssistantCore/Sources/UI/components/onboarding Packages/MeetingAssistantCore/Sources/UI/components/transcription Packages/MeetingAssistantCore/Sources/UI/components/recording Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests plans/README.md`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against the live code before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/033-establish-apple-motion-system.md
- **Category**: tech-debt
- **Planned at**: commit `546f869e`, 2026-07-10

## Why this matters

The new `apple-design` guidance calls out Dynamic Type, tracking, leading, and scaled metrics. Prisma mostly uses semantic fonts in text-heavy surfaces, but there are still fixed `system(size:)` clusters in navigation, onboarding, indicator, and compact controls. This plan creates a typography/scaled-metric policy and migrates the highest-impact usages without broad visual churn.

## Current state

- `AppDesignSystem.Layout` stores many fixed dimensions, including sidebar font size:

```text
AppDesignSystem.swift:262 public enum Layout {
AppDesignSystem.swift:286     public static let controlHeight: CGFloat = 34
AppDesignSystem.swift:288     public static let settingsTitleBarMaterialHeight: CGFloat = 56
AppDesignSystem.swift:360     public static let sidebarLabelFontSize: CGFloat = 13
```

- Sidebar labels use fixed font sizes:

```text
SettingsSidebarView.swift:112 .font(.system(size: 15, weight: .medium))
SettingsSidebarView.swift:117 .font(.system(size: AppDesignSystem.Layout.sidebarLabelFontSize, weight: .medium))
SettingsSidebarView.swift:127 .font(.system(size: 13, weight: .regular))
SettingsSidebarView.swift:133 .font(.system(size: AppDesignSystem.Layout.sidebarLabelFontSize, weight: .regular))
```

- Onboarding rows use fixed icon and status fonts:

```text
OnboardingPermissionRow.swift:29 .font(.system(size: 24))
OnboardingPermissionRow.swift:31 .frame(width: 40, height: 40)
OnboardingPermissionRow.swift:81 .font(.system(size: 13, weight: .medium))
OnboardingPermissionRow.swift:99 .font(.system(size: 13))
```

- The recording indicator uses fixed compact fonts for footer actions:

```text
FloatingRecordingIndicatorView.swift:803 .font(.system(size: 12, weight: .medium))
FloatingRecordingIndicatorView.swift:855 .font(.system(size: 12, weight: .semibold))
FloatingRecordingIndicatorView.swift:883 .font(.system(size: 11, weight: .semibold))
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Static scan | `rg -n "font\\(\\.system\\(size" Packages/MeetingAssistantCore/Sources/UI -g '*.swift'` | remaining matches are intentional and documented |
| Preview coverage | `make preview-check` | exit 0 |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'FloatingRecordingIndicatorWidthTests|SettingsSectionTests|SettingsSearchIndexTests'` | exit 0; all pass |
| Build | `make build-agent` | exit 0 |

## Suggested executor toolkit

- Use `apple-design` for Dynamic Type, tracking, and leading rules.
- Use `macos-app-engineering` for SwiftUI layout and previews.
- Use `accessibility-audit` if changing focus or VoiceOver labels.

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppDesignSystem.swift`
- New typography helper file under `components/design-system` if needed
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsSidebarView.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingPermissionRow.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/OnboardingStepIndicator.swift`
- `Packages/MeetingAssistantCore/Sources/UI/components/transcription/TranscriptionAudioPlayerView.swift`
- Compact recording indicator font helper functions in `FloatingRecordingIndicatorViewUtilities`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/FloatingRecordingIndicatorWidthTests.swift`
- `plans/README.md`

**Out of scope**:
- Do not migrate every fixed frame in the repo.
- Do not change localization strings.
- Do not change indicator width behavior except where tests are updated for scaled fonts.
- Do not import custom fonts.

## Git workflow

- Branch: `ui/036-typography-scaled-layout`
- Commit message: `refactor(ui): normalize typography and scaled layout`
- Keep migrations small and grouped by surface.

## Steps

### Step 1: Add typography tokens with semantic intent

Extend `AppDesignSystem` or create `AppTypography.swift` with named helpers for:

- sidebar icon
- sidebar label
- compact control label
- indicator caption
- onboarding status label
- monospaced timer font where fixed metrics are required

Prefer semantic SwiftUI text styles like `.font(.body)`, `.font(.caption)`, `.font(.headline)` and use fixed sizes only for non-text symbol fitting or width-measured timer text.

**Verify**: `make preview-check` -> exit 0.

### Step 2: Use `@ScaledMetric` for repeated icon/control dimensions

In onboarding and sidebar components, replace fixed icon/row dimensions with `@ScaledMetric` where the dimension is tied to text legibility.

Do not scale the recording indicator panel globally in this step; its width tests depend on deterministic compact geometry. Use measured font helpers there instead.

**Verify**: `make preview-check` -> exit 0.

### Step 3: Migrate sidebar and onboarding fixed fonts

Replace fixed `.system(size:)` in `SettingsSidebarView`, `OnboardingStepIndicator`, and `OnboardingPermissionRow` with typography helpers or semantic fonts.

Keep visual hierarchy similar:

- sidebar labels remain compact and scannable
- onboarding status remains secondary/supporting
- icons remain aligned

**Verify**: `rg -n "font\\(\\.system\\(size" Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsSidebarView.swift Packages/MeetingAssistantCore/Sources/UI/components/onboarding -g '*.swift'` -> no matches except justified symbol-only cases.

### Step 4: Audit compact recording indicator fonts

Move fixed recording-indicator font choices into named utilities. Keep deterministic width measurement for timer/status labels:

- `timerFont(for:)` can stay `NSFont.monospacedDigitSystemFont` because width measurement depends on it.
- Footer/action label fonts should move to a named helper and be documented as compact overlay typography.
- Update width tests only if helper names change, not visual behavior.

**Verify**: `swift test --package-path Packages/MeetingAssistantCore --filter FloatingRecordingIndicatorWidthTests` -> exit 0.

### Step 5: Document intentional fixed typography leftovers

Run:

```bash
rg -n "font\\(\\.system\\(size" Packages/MeetingAssistantCore/Sources/UI -g '*.swift'
```

For remaining matches, either migrate them or add a short code comment only when the fixed size is truly required for icon geometry, measured overlay width, or monospaced technical display.

Do not leave arbitrary fixed body text sizes.

**Verify**: the `rg` output contains only intentional compact/symbol cases.

### Step 6: Validate and update the plan ledger

Update `plans/README.md` row 036 from `TODO` to `DONE`.

Run:

```bash
make preview-check
swift test --package-path Packages/MeetingAssistantCore --filter 'FloatingRecordingIndicatorWidthTests|SettingsSectionTests|SettingsSearchIndexTests'
make build-agent
```

## Test plan

- Existing width tests protect indicator measured text behavior.
- Settings section/search tests guard sidebar routing if labels/icons are touched.
- Preview coverage catches basic layout compile failures.
- Manual PR notes should mention Dynamic Type preview checks for onboarding and sidebar.

## Done criteria

- [ ] Typography helpers exist for core UI text roles.
- [ ] Sidebar/onboarding fixed text font sizes are migrated or justified.
- [ ] Recording indicator measured fonts remain deterministic and tested.
- [ ] Remaining `.font(.system(size:` matches are intentional and documented.
- [ ] `make preview-check` exits 0.
- [ ] Focused tests exit 0.
- [ ] `make build-agent` exits 0.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back if:

- Dynamic Type scaling breaks indicator width tests in a way that requires a broader indicator layout redesign.
- More than 8 source files need migration to make the scan clean.
- A semantic font migration causes visible clipping that cannot be fixed with local scaled metrics.

## Maintenance notes

This is the baseline for future typography work. Reviewers should ask for semantic text styles and `@ScaledMetric` in new UI unless the component is a compact overlay whose size must be measured exactly.
