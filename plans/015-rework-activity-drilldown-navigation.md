# Plan 015: Rework Activity into drill-down navigation

> **Executor instructions**: Follow this plan step by step. Run every verification command before moving on. If a STOP condition occurs, stop and report.
>
> **Drift check (run first)**: `git diff --stat 50320ecc..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardSettingsTab.swift Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ActivitySettingsNavigationStateTests.swift`
> If any in-scope file changed since this plan was written, compare the "Current state" excerpts against live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `50320ecc`, 2026-07-02

## Why this matters

The Activity tab currently starts with a segmented control, which makes the consolidated settings shell feel like two old tabs placed inside one page. The requested design is a single Activity root page with drill-down rows: Recording History, Model Performance, and More Insights. This matches the Dictation tab pattern and makes Activity read as one navigation group instead of nested tab chrome.

## Current state

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift` owns the Activity root and currently renders a segmented `Picker`.
- `Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift` tracks `activeRoute` as `.dashboard` or `.history`.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardSettingsTab.swift` already supports `.moreInsights` and `.performance` subroutes.
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/DictationSettingsTab.swift` lines 75-96 show the desired grouped drill-down pattern with one `DSGroup`, stacked `SettingsDrillDownButtonRow`, and dividers.

Relevant excerpts:

```swift
// ActivitySettingsTab.swift:31-47
private var header: some View {
    HStack {
        Picker("", selection: $navigationState.activeRoute) {
            Text("settings.section.metrics".localized)
                .tag(ActivitySettingsRoute.dashboard)
            Text("settings.section.history".localized)
                .tag(ActivitySettingsRoute.history)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 260)
        .padding(.leading, 24)

        Spacer()
    }
    .padding(.vertical, 12)
}
```

```swift
// MetricsDashboardSettingsTab.swift:6-10
public enum MetricsDashboardRoute: Hashable {
    case moreInsights
    case performance
    case performanceRecording(UUID)
    case eventDetail(MeetingCalendarEventSnapshot)
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Targeted tests | `./scripts/run-tests.sh --suite dev --file ActivitySettingsNavigationStateTests` | exit 0, all tests pass |
| Build | `make build-agent` | exit 0 |
| SwiftUI previews | `make preview-check` | exit 0 |
| Full lane gate | `make build-test` | exit 0 |
| Full lane lint | `make lint` | exit 0 |

## Scope

**In scope**:
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift`
- `Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings`
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/ActivitySettingsNavigationStateTests.swift`

**Out of scope**:
- Reworking metrics chart content.
- Moving Activity outside Settings.
- Changing persisted transcription/history behavior.
- Creating a second navigation framework.

## Git workflow

- Branch: `advisor/015-activity-drilldowns`
- Commit style: Conventional Commits, e.g. `refactor(settings): rework activity drilldowns`
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Replace the segmented root with one drill-down group

In `ActivitySettingsTab`, remove `header` and the top `VStack` wrapper that exists only to host the segmented control. Make `body` switch on the route directly:

- Root route: render `SettingsScrollableContent` with `SettingsSectionHeader(title: "settings.section.activity".localized, description: <new localized key>)`.
- Add one `DSGroup` containing exactly three rows in this order:
  1. `Recording History`
  2. `Model Performance`
  3. `More Insights`
- Use `SettingsDrillDownButtonRow`, not `NavigationLink`, matching `DictationSettingsTab`.
- Put dividers between rows, not separate `DSGroup` containers.

Open targets:

- Recording History opens the transcription history page.
- Model Performance opens `MetricsDashboardSettingsTab` with `metricsNavigationState.open(.performance)`.
- More Insights opens `MetricsDashboardSettingsTab` with `metricsNavigationState.open(.moreInsights)`.

**Verify**: `./scripts/run-tests.sh --suite dev --file ActivitySettingsNavigationStateTests` -> existing tests may fail until Step 2, but there should be no syntax-only failure unrelated to route model changes.

### Step 2: Update Activity navigation state for a root route

In `ActivitySettingsNavigationState`, change the model so the root page is representable without pretending Dashboard is selected.

Recommended shape:

```swift
public enum ActivitySettingsRoute: Hashable, Sendable {
    case root
    case history
    case modelPerformance
    case moreInsights
}
```

Default `activeRoute` should be `.root`.

Navigation behavior:

- `isShowingHistoryList` stays true only for `.history` with transcription route `.list`.
- `canGoBack` is true for `.history`, `.modelPerformance`, and `.moreInsights`; for `.modelPerformance` and `.moreInsights`, also include nested dashboard navigation when deeper pages like `performanceRecording` are open.
- `goBack()` from `.history`, `.modelPerformance`, or `.moreInsights` returns to `.root` when no nested route consumes back first.
- `goForward()` should preserve one forward route when backing from a top-level Activity drill-down. Keep it simple; do not implement a general stack unless the existing tests require it.
- `apply(.history)` must still support menu/deep-link history requests from `NavigationService.openActivityHistory()`.

**Verify**: `./scripts/run-tests.sh --suite dev --file ActivitySettingsNavigationStateTests` -> update tests so root is default, history deep-link still works, and model performance/more insights back behavior is covered.

### Step 3: Localize only new visible text

Add localized keys for:

- Activity root description.
- Recording History row title and optional subtitle/hint.
- Model Performance row subtitle/hint if existing keys do not fit.
- More Insights row subtitle/hint if existing keys do not fit.

Reuse existing keys where natural:

- `metrics.performance.link.title`
- `metrics.more_insights.title`
- `settings.section.history` only if "Recording History" is not already localized elsewhere; otherwise add `settings.activity.recording_history.title`.

Do not hardcode user-facing strings.

**Verify**: `rg -n 'Recording History|Model Performance|More Insights|Dashboard / History|Dashboard|History' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift` -> no hardcoded visible strings in the Swift file.

### Step 4: Run the thermo-nuclear code quality review

Before finalizing, review only the Activity diff with the `thermo-nuclear-code-quality-review` bar:

- No second navigation abstraction.
- No separate `DSGroup` per drill-down row.
- No ad-hoc special cases in `SettingsPage`.
- No duplicated dashboard/history body code.
- `ActivitySettingsTab.swift` must stay small and direct; if it grows above 200 lines, decompose before merge.
- Prefer deleting the segmented-control concept entirely over hiding it.

Record the review outcome in the PR notes or final agent output using semaforo language: critical/medium/minor or "no structural blockers found."

**Verify**: `git diff --stat -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/Models/ActivitySettingsNavigationState.swift` -> diff is focused and does not touch unrelated tabs.

## Test plan

- Update `ActivitySettingsNavigationStateTests`:
  - default state is root and cannot go back.
  - `apply(.history)` opens history and preserves history-list search visibility behavior.
  - model performance and more insights routes can go back to root.
  - nested performance recording back behavior still delegates to `metricsNavigationState` before returning root.
- Run `make preview-check` because this changes a SwiftUI settings tab.
- Run Full lane gates: `make build-test` and `make lint`.

## Done criteria

- [ ] Activity tab has no segmented control.
- [ ] Activity root shows one grouped drill-down list in this order: Recording History, Model Performance, More Insights.
- [ ] Existing menu/deep-link history navigation still opens Recording History.
- [ ] User-facing strings are localized in English and Portuguese.
- [ ] `./scripts/run-tests.sh --suite dev --file ActivitySettingsNavigationStateTests` exits 0.
- [ ] `make preview-check` exits 0.
- [ ] `make build-test` exits 0.
- [ ] `make lint` exits 0.
- [ ] Thermo-nuclear review outcome is recorded.

## STOP conditions

Stop and report if:

- `ActivitySettingsTab.swift` no longer resembles the excerpts above due to a newer implementation.
- The change requires modifying `SettingsPage` beyond preserving existing history deep-link behavior.
- A general-purpose navigation stack becomes necessary; that is larger than this plan.
- Full lane gates fail twice for reasons tied to this diff.

## Maintenance notes

Reviewers should focus on whether this deletes chrome, not merely restyles it. The target is one Activity page with clear drill-down rows. Do not accept a version that keeps Dashboard as an invisible default tab or creates one group per row.
