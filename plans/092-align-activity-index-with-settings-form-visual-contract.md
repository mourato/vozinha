# Plan 092: Align Activity index groups with the Settings Form visual contract

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
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardPages.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardComponents.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboardSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/design-system/DSGroup.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift \
>   plans/082-retire-form-islands-and-normalize-specialized-settings-surfaces.md \
>   plans/README.md
> ```
>
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (conceptually follows completed 079–082; does not require 090/091)
- **Category**: tech-debt
- **Planned at**: commit `cfb72f45`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent of 090/091 content, but only one writer
  may run at a time under repo policy
- **Reviewer required**: `yes` — must confirm Activity remains analytics-capable
  and does not lose calendar/heatmap behavior while matching Form chrome
- **Rationale**: Touches Activity shell composition and visual contract; Full
  because Settings surface regressions are easy to miss without route checks
- **Escalate when**: Heatmap, calendar linking, or performance drill-downs need
  data-model changes, or more than eight source files require non-mechanical edits

## Why this matters

After plans 079–082, scalar Settings pages use one native grouped `Form`
(`SettingsFormPage`). Activity’s index still uses `SettingsScrollableContent` +
`DSGroup` / `SettingsListGroup` cards. Those custom surfaces read as a different
background system (material card fills, and Upcoming Events nests a second
inline background inside the group — “card-in-card”). Users comparing Activity
to Dictation/Meetings correctly see mismatched group chrome. This plan brings
the Activity **index** page onto the Form visual contract without turning the
heatmap or calendar actions into scalar toggles.

## Current state

### Activity index composition today

`MetricsDashboardPages.swift` `ActivityDashboardRootPage` (and the related
`MetricsDashboardIndexPage`) wrap content in `SettingsScrollableContent` and
stack:

1. `MetricsDashboardActivitySection` → `DSGroup` + heatmap
   (`MetricsDashboardComponents.swift`)
2. `ActivityDashboardDrillDownSection` → `SettingsListGroup` with three
   drill-down rows (Recording History, Model Performance, More Insights)
3. `MetricsDashboardUpcomingEventsSection` → `DSGroup` containing
   `UpcomingCalendarEventRow`s that each apply
   `settingsInlineBackground(intensity: .regular)` — nested card inside card

Plan 082 intentionally kept Activity as a specialized non-Form surface so
analytics would not be forced into scalar rows. That decision preserved
behavior, but left visual drift versus the migrated Form pages. This plan
**revises only the index chrome**, not analytics semantics.

### Target visual contract

Match Dictation/Meetings:

- One page-level `SettingsFormPage` (single scroll owner, `.formStyle(.grouped)`)
- One native `Section` per group (Transcription Activity / Activity links /
  Upcoming Events)
- No nested `DSCard`/`settingsInlineBackground` “card-in-card” for event rows
- Heatmap and event actions remain composed **content inside** Sections
  (allowed by 080/082 for non-scalar blocks)

### Reuse → extend → create

- Reuse `SettingsFormPage`, `SettingsFormSectionHeader`, and existing
  drill-down row components that already work inside Form (`SettingsListDrillDownButtonRow`
  / `SettingsDrillDownButtonRow` — keep whichever the Meetings Form pages use).
- Extend Activity section view builders so they can render as Form `Section`
  content without their own outer `DSGroup` card when hosted by Form.
- Do **not** create a second Activity-only container primitive.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory containers | `rg -n "DSGroup|SettingsListGroup|SettingsFormPage|SettingsScrollableContent" Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MetricsDashboard*.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ActivitySettingsTab.swift --glob '*.swift'` | Shows pre/post container choices |
| Navigation tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'ActivitySettingsNavigationStateTests\|MetricsDashboardNavigationTests\|MetricsDashboardViewModelTests'` | exit 0 |
| Previews | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Lint | `make lint-agent` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | PASS |

## Suggested executor toolkit

- `macos-app-engineering` Settings Form patterns
- Compare visually to `DictationSettingsTab` / `MeetingSettingsTab` Form sections
- Keep calendar/heatmap logic untouched; only hosting chrome changes

## Scope

**In scope**:

- Activity index hosting:
  - `MetricsDashboardPages.swift` (`ActivityDashboardRootPage`, and
    `MetricsDashboardIndexPage` if it remains a parallel entry)
  - `MetricsDashboardComponents.swift` (Activity / Upcoming Events section
    wrappers and `UpcomingCalendarEventRow` nested background)
  - `ActivitySettingsTab.swift` / `MetricsDashboardSettingsTab.swift` only if
    needed to wire the Form host
- Previews for touched views
- `plans/README.md` status row
- A short note in this plan’s completion / ledger dependency notes that plan
  082’s “Activity stays specialized” exception is narrowed for the **index
  page chrome** only

**Out of scope**:

- More Insights charts layout redesign
- Performance workspace / leaderboard redesign
- Recording History list migration
- Boolean switch/checkbox pass (plan 090)
- Meeting Transcription Divider (plan 091)
- Changing calendar permission, link/ignore, or heatmap data pipelines
- Token redesign of global `DSGroup` defaults for every non-Activity caller

## Git workflow

- Branch: `refactor/092-activity-form-visual-contract`
- Commits (atomic):
  1. `refactor(settings): host Activity index in SettingsFormPage`
  2. `fix(settings): flatten Upcoming Events nested card backgrounds`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Inventory and choose the host

Confirm which root view the sidebar Activity tab presents
(`ActivitySettingsTab` → `ActivityDashboardRootPage` vs metrics index). The
user-facing Activity tab with Transcription Activity / Activity / Upcoming
Events is the required host.

**Verify**: `rg -n "ActivityDashboardRootPage|MetricsDashboardIndexPage|ActivitySettingsTab" Packages/MeetingAssistantCore/Sources/UI/pages/settings --glob '*.swift'` maps the live entry point.

### Step 2: Host the Activity index in `SettingsFormPage`

Replace the index page’s `SettingsScrollableContent { ... }` shell with
`SettingsFormPage` using the existing hero title/description as the Form
header (same localized keys as today).

Convert the three groups into native `Section`s:

1. **Transcription Activity** — header via `SettingsFormSectionHeader`; body =
   heatmap content currently inside `MetricsDashboardActivitySection` **without**
   an outer `DSGroup` card.
2. **Activity** — header + the three drill-down rows as native Form rows
   (no `SettingsListGroup` card wrapper).
3. **Upcoming Events** — header + event list/empty/permission states **without**
   an outer `DSGroup` card.

Keep load-error callouts as a Section or top content block that does not add a
second scroll view.

Refactor section helpers as needed so they expose “content only” builders for
Form hosting. Prefer parameter/flag or content extraction over duplicating the
heatmap.

**Verify**: Activity index has exactly one vertical scroll owner; `rg` shows
`SettingsFormPage` on the index and no page-level `SettingsScrollableContent`
for that index.

### Step 3: Remove Upcoming Events card-in-card

In `UpcomingCalendarEventRow`, remove the nested
`.background(AppDesignSystem.Colors.settingsInlineBackground(...))` + clip
treatment that creates white cards inside the gray group. Event rows should
read as Form rows (padding + native separators), with actions still available.

Keep linked/recording button states and accessibility labels.

**Verify**: no `settingsInlineBackground` on `UpcomingCalendarEventRow`; event
actions still compile.

### Step 4: Preserve specialized child routes

More Insights, Performance, Event Detail, and History must remain on their
existing hosts (`SettingsScrollableContent` / specialized layouts) unless a
child is already Form-based. Do not force chart grids into scalar Form rows.

**Verify**: `ActivitySettingsNavigationStateTests` and
`MetricsDashboardNavigationTests` pass; drill-downs still open.

### Step 5: Validate

Run preview-check, focused tests, build, lint, Full validate-agent. Update
ledger; in dependency notes, record that 082’s Activity exception is narrowed
to analytics **child** surfaces, while the Activity index now uses Form chrome.

**Verify**: Full gate PASS.

## Test plan

- Existing navigation/view-model tests above must pass.
- Add or extend a lightweight navigation/hosting assertion only if current
  tests do not cover Activity root → History / More Insights / Performance.
- Manual visual check vs Dictation: section fill, corner rhythm, and absence of
  nested event cards.
- Pattern reference for Form host: `DictationSettingsTab.swift` /
  `MeetingSettingsTab.swift`.

## Done criteria

- [ ] Activity index uses `SettingsFormPage` with native `Section`s for the three
      user-visible groups
- [ ] No outer `DSGroup`/`SettingsListGroup` card wrappers on those three index
      groups
- [ ] Upcoming event rows no longer nest a second card background
- [ ] Heatmap, calendar permission/empty/link/ignore behavior unchanged
- [ ] Child analytics routes still specialized and reachable
- [ ] Focused tests + preview-check + build + lint + Full validate-agent PASS
- [ ] No files outside Scope modified
- [ ] `plans/README.md` updated

## STOP conditions

- Heatmap cannot be hosted inside a Form Section without breaking scrolling or
  width — stop and report rather than inventing a hybrid dual-scroll layout.
- Calendar event actions regress (link/ignore/open detail).
- Fix seems to require retinting global `DSGroup` for the whole app.
- Scope expands into More Insights chart redesign or boolean-control work.

## Maintenance notes

- Plan 082 remains correct that analytics charts/history are not scalar
  settings; only the Activity **index chrome** joins the Form contract here.
- Reviewers should reject reintroducing `DSGroup` wrappers around Form Sections
  on Activity index.
- If VoiceInk later shows a different Activity shell, update this plan’s target
  with screenshots before changing chart layout.
