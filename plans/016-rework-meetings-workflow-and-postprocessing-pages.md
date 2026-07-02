# Plan 016: Rework Meetings workflow and post-processing pages

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving on. If a STOP condition occurs, stop and report.
>
> **Drift check (run first)**: `git diff --stat 50320ecc..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/Models/MeetingSettingsNavigationState.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/MeetingSettingsViewModel.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore/ComputedProperties.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/MeetingSettingsNavigationStateTests.swift Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppSettingsStorePromptManagementTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `50320ecc`, 2026-07-02

## Why this matters

Meetings currently exposes monitored apps/sites and export as standalone groups, while Meeting Prompts sits as a large inline section. The requested structure puts workflow choices in one Workflow group and moves dense configuration into drill-down pages. It also adds an explicit meeting post-processing switch without creating a second persisted truth.

## Current state

- `MeetingSettingsTab.swift` is 542 lines and already close to the 600-line repo guidance boundary.
- `MeetingSettingsNavigationState.swift` supports only `.root` and `.monitoringTargets`.
- `MeetingSettingsTab.swift` lines 133-141 render `Monitored apps and sites` as its own group.
- `MeetingSettingsTab.swift` lines 143-157 render the Workflow group with only two toggles.
- `MeetingSettingsTab.swift` lines 203-292 render Export inline as its own group.
- `MeetingSettingsTab.swift` lines 294-347 render Meeting Prompts inline as its own group.
- `MeetingSettingsTab.swift` lines 358-375 render Meeting Intelligence Model with Q&A toggle and model selection.
- Existing settings state uses `selectedPromptId == AppSettingsStore.noPostProcessingPromptId` as the meeting post-processing disabled sentinel.

Relevant excerpts:

```swift
// MeetingSettingsNavigationState.swift:3-6
public enum MeetingSettingsNavigationRoute: Hashable, Equatable {
    case root
    case monitoringTargets
}
```

```swift
// ComputedProperties.swift:76-90
var selectedPrompt: PostProcessingPrompt? {
    guard let id = selectedPromptId, id != Self.noPostProcessingPromptId else { return nil }
    return meetingAvailablePrompts.first { $0.id == id }
}

var isMeetingPostProcessingDisabled: Bool {
    selectedPromptId == Self.noPostProcessingPromptId
}
```

```swift
// MeetingSettingsTab.swift:358-375
private var meetingIntelligenceSection: some View {
    DSGroup("settings.enhancements.meeting_intelligence_model".localized, icon: "bubble.left.and.bubble.right.fill") {
        VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
            DSToggleRow(
                "transcription.qa.title".localized,
                description: "settings.enhancements.qa_enabled_desc".localized,
                isOn: $meetingViewModel.settings.meetingQnAEnabled
            )

            Divider()

            EnhancementsModelSelectionControl(
                target: .meeting,
                viewModel: aiSettingsViewModel,
                settings: settings
            )
        }
    }
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Navigation tests | `./scripts/run-tests.sh --suite dev --file MeetingSettingsNavigationStateTests` | exit 0 |
| Prompt/settings tests | `./scripts/run-tests.sh --suite dev --file AppSettingsStorePromptManagementTests` | exit 0 |
| Build | `make build-agent` | exit 0 |
| SwiftUI previews | `make preview-check` | exit 0 |
| Full lane gate | `make build-test` | exit 0 |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Models/MeetingSettingsNavigationState.swift`
- `Packages/MeetingAssistantCore/Sources/UI/ViewModels/MeetingSettingsViewModel.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/MeetingSettingsNavigationStateTests.swift`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/AppSettingsStorePromptManagementTests.swift`

**Out of scope**:
- Changing transcription provider selection.
- Changing the post-processing pipeline internals.
- Changing export file format or export safety policy behavior.
- Adding a new persisted meeting post-processing flag unless the existing sentinel cannot satisfy the requirement.
- Renaming old source files unless needed to keep `MeetingSettingsTab.swift` below the maintainability threshold.

## Git workflow

- Branch: `advisor/016-meetings-workflow-pages`
- Commit style: Conventional Commits, e.g. `refactor(settings): rework meetings workflow pages`
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Expand Meetings navigation routes

In `MeetingSettingsNavigationState`, add routes:

```swift
case monitoringTargets
case meetingPrompts
case export
```

Keep the model simple: one current route and one forward route is enough because these are root-level drill-downs. Update tests so back/forward behavior works for all three routes, not just monitoring targets.

**Verify**: `./scripts/run-tests.sh --suite dev --file MeetingSettingsNavigationStateTests` -> all tests pass.

### Step 2: Add a meeting post-processing toggle by reusing the sentinel

Do not add a second persisted key. Use the existing disabled state:

- On/off state is `!settings.isMeetingPostProcessingDisabled`.
- Turning off sets `settings.meetingTypeAutoDetectEnabled = false` and `settings.selectedPromptId = AppSettingsStore.noPostProcessingPromptId`.
- Turning on clears only the sentinel state. Recommended: if `selectedPromptId == AppSettingsStore.noPostProcessingPromptId`, set `selectedPromptId = nil`; do not force a specific prompt.

Put this behavior in `MeetingSettingsViewModel`, for example:

```swift
public var isMeetingPostProcessingEnabled: Bool {
    !settings.isMeetingPostProcessingDisabled
}

public func setMeetingPostProcessingEnabled(_ isEnabled: Bool) { ... }
```

Use a custom `Binding` in `MeetingSettingsTab` to connect this to `DSToggleRow`.

**Verify**: `./scripts/run-tests.sh --suite dev --file AppSettingsStorePromptManagementTests` -> add or update tests proving the sentinel still disables prompt resolution and clearing it restores default prompt resolution.

### Step 3: Move Meeting Prompts into its own drill-down page

In `MeetingSettingsTab.body`, route `.meetingPrompts` to a new private page property.

Move the existing prompt controls from lines 294-347 into that page:

- Summary output language picker.
- Meeting type auto-detect toggle.
- New prompt button.
- Prompt rows.

Remove `noPostProcessingRow()` from the prompts list once the new toggle exists, to avoid two separate controls for the same state.

Disable the drill-down access when meeting post-processing is off:

- The row in Meeting Intelligence Model should be visibly disabled.
- The `.meetingPrompts` page should also disable its content if reached via stale navigation.
- Do not delete or mutate existing prompts when post-processing is off.

**Verify**: `rg -n 'noPostProcessingRow|recording_indicator.prompt.none' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift` -> no matches unless a reviewer explicitly accepts keeping a compatibility-only helper.

### Step 4: Rebuild the Meeting Intelligence Model group

Inside `meetingIntelligenceSection`, order controls as:

1. Toggle/switch to enable meeting post-processing, default on through sentinel absence.
2. `EnhancementsModelSelectionControl(target: .meeting, ...)`.
3. Drill-down row for Meeting Prompts, disabled when post-processing is off.

Keep Q&A if product still wants it here, but avoid burying the requested post-processing toggle. If keeping Q&A creates four rows, place it after model selection and before Meeting Prompts, separated by dividers.

Do not use `settings.postProcessingEnabled` for this toggle: it is a broader setting and can affect other enhancement flows.

**Verify**: `rg -n 'postProcessingEnabled' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/MeetingSettingsViewModel.swift` -> no new dependency on the global flag for the meeting-only toggle.

### Step 5: Move Monitoring and Export drill-down rows into Workflow

Remove the standalone Monitoring group and the standalone Export group from the root page.

In the existing `Workflow` group, render one `VStack` in this order:

1. Auto-start recording toggle.
2. Drill-down row: Monitored apps and sites.
3. Merge audio toggle.
4. Drill-down row: Export.

Use dividers between rows. The monitoring row opens `.monitoringTargets`; the export row opens `.export`.

Route `.export` to a new private export page containing the existing export controls from lines 203-292.

**Verify**: `rg -n 'settings.meetings.monitoring_access.title|settings.meetings.export\"' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift` -> each title should appear only in the new intended location, not as standalone root `DSGroup` headings.

### Step 6: Keep file size healthy

After moving prompt and export pages, check file length:

`wc -l Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift`

If it exceeds 600 lines, split before merge using the repo's colocation convention:

- Create folder `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab/` only if the project already supports this move cleanly, or add uniquely named sibling files such as `MeetingSettingsPromptsPage.swift` and `MeetingSettingsExportPage.swift`.
- Do not use `MeetingSettingsTab+Prompts.swift` filenames.
- Keep helper methods with the page that owns them.

**Verify**: `find Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs -name '*+*.swift' -print` -> no new `+` split files.

### Step 7: Localize new rows and toggle copy

Add localized keys in English and Portuguese for:

- Meeting post-processing toggle title/description.
- Meeting prompts drill-down title/subtitle/hint if existing keys are insufficient.
- Export drill-down subtitle/hint.

Reuse existing keys where appropriate:

- `settings.meetings.monitoring_access.button`
- `settings.meetings.monitoring_access.desc`
- `settings.meetings.export`
- `settings.meetings.prompts`

**Verify**: `rg -n 'Meeting Prompts|Monitored apps|Export|post-processing|Post-processing' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift` -> no hardcoded visible strings.

### Step 8: Run the thermo-nuclear code quality review

Review only this Meetings diff with the `thermo-nuclear-code-quality-review` bar:

- No duplicate state for meeting post-processing.
- No scattered checks for `noPostProcessingPromptId`; keep sentinel handling in the view model.
- No standalone root Monitoring or Export group remains.
- No random route-specific `if` branches in `SettingsPage`.
- No source file crosses the 600-line repo guidance without decomposition; no file crosses 1k lines.
- Dense page bodies should move behind focused private views/helpers rather than making `mainPage` harder to scan.
- The implementation should delete the old inline prompt/export complexity from the root, not just wrap it in more conditionals.

Record the review outcome in the PR notes or final agent output using semaforo language: critical/medium/minor or "no structural blockers found."

**Verify**: `git diff --stat -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/Models/MeetingSettingsNavigationState.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/MeetingSettingsViewModel.swift` -> diff is focused and does not touch runtime post-processing internals.

## Test plan

- Update `MeetingSettingsNavigationStateTests` for `.monitoringTargets`, `.meetingPrompts`, and `.export` back/forward behavior.
- Update `AppSettingsStorePromptManagementTests` or add focused `MeetingSettingsViewModelTests` if one exists:
  - default meeting post-processing is on when `selectedPromptId` is nil.
  - turning off selects `AppSettingsStore.noPostProcessingPromptId`.
  - turning on clears only that sentinel.
  - existing meeting prompts remain stored when toggled off.
- Run `make preview-check` because the settings layout changes.
- Run Full lane gates: `make build-test` and `make lint`.

## Done criteria

- [ ] Meeting Intelligence Model includes a meeting post-processing toggle.
- [ ] The toggle defaults on for fresh/default settings through absence of the disabled sentinel.
- [ ] Meeting Prompts is a drill-down under Meeting Intelligence Model.
- [ ] Meeting Prompts access is disabled when the toggle is off.
- [ ] Monitored apps and sites is a Workflow drill-down between Auto-start and Merge audio.
- [ ] Export is a Workflow drill-down with its own page.
- [ ] No user-facing strings are hardcoded.
- [ ] `MeetingSettingsTab.swift` stays at or below 600 lines, or is decomposed using repo-approved filenames.
- [ ] `./scripts/run-tests.sh --suite dev --file MeetingSettingsNavigationStateTests` exits 0.
- [ ] Prompt/settings focused tests exit 0.
- [ ] `make preview-check` exits 0.
- [ ] `make build-test` exits 0.
- [ ] `make lint` exits 0.
- [ ] Thermo-nuclear review outcome is recorded.

## STOP conditions

Stop and report if:

- The existing sentinel no longer controls meeting post-processing in live code.
- The change requires modifying post-processing runtime services to satisfy a settings-only toggle.
- Export behavior changes beyond moving its settings page.
- Navigation needs nested pages under `.meetingPrompts` or `.export`; this plan assumes root-level drill-downs only.
- Full lane gates fail twice for reasons tied to this diff.

## Maintenance notes

Reviewers should reject any implementation that adds a new persisted `meetingPostProcessingEnabled` while still keeping `selectedPromptId == noPostProcessingPromptId`; that creates two truths for one setting. The clean shape is to make the switch a clearer UI for the existing sentinel and move dense controls out of the root page.
