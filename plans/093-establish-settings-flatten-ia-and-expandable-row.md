# Plan 093: Establish Settings flatten IA contract and ExpandableSettingsRow

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
> git diff --stat bb6fbf79..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift \
>   .agents/skills/macos-app-engineering/references/macos-app-engineering-details.md \
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
- **Depends on**: none (logically after DONE 079–082 Form surface work)
- **Category**: direction
- **Planned at**: commit `bb6fbf79`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — shared UI primitive + guidance contract used by 094–097
- **Reviewer required**: `yes` — this becomes the navigation contract for Settings flatten
- **Rationale**: New public settings component and skill guidance; not deterministic Low/Fast
- **Escalate when**: Primitive requires AppKit introspection, or product rejects expandable
  disclosure in favor of sheets-only

## Why this matters

Settings today mixes three navigation models: sidebar section selection, global
toolbar back/forward for Activity/Meetings/System, and a Modes-only trailing
drawer. Plans 015/016/018 intentionally *created* drill-down subpages. B2
(aggressive flatten) reverses that hierarchy: keep one Form page per sidebar
section wherever possible, disclose infrequent options inline, and use sheets or
the existing side panel for heavy editors — matching VoiceInk `v2.0-beta.2`
(`ExpandableSettingsRow` + side panels, no toolbar history).

This plan locks the IA and ships the missing disclosure primitive. Plans
094–097 migrate sections and retire chrome.

## Target IA (locked for 094–097)

| Sidebar section | After B2 |
|---|---|
| Dictation / Assistant / Integrations | Unchanged single Form page |
| Modes | Unchanged list + `settingsSidePanel` drawer |
| Meetings | **Single** Form page; export / prompts / monitoring disclosed inline; keep existing sheets |
| System | **Single** Form page for General + permissions + protected apps; Models / Dictionary / Audio remain the only System child destinations temporarily (095), then lose toolbar dependence (097) |
| Activity | Root Form stays; Event Detail / More Insights / Model Performance become sheets; **History** remains the only Activity sub-destination (list + conversation), with search and back chrome local to that surface |

**Hard rules (do not violate in later plans):**

1. One vertical scroll owner per page — prefer `SettingsFormPage` for scalar pages
   (plan 079).
2. Do **not** mechanically force History lists, Modes grids, monitored-app lists,
   provider catalogs, dictionary rules, permission status blocks, or chart
   dashboards into scalar Form rows (plan 082 exception preserved for *content
   type*; only *navigation* flattens).
3. Do **not** apply Modes drawer 400 pt width to root pages.
4. Immediate-effect booleans stay `.toggleStyle(.switch)` (plan 090).
5. Preserve `SettingsDestination` / `NavigationService` deep links; remap
   destinations rather than deleting legacy section IDs.
6. User-facing strings use `"key".localized`; remove orphaned keys when copy dies.

## Current state

- `SettingsFormPage.swift` — one grouped Form per page; exemplar for scalar surfaces.
- `SettingsListDrillDownButtonRow` (`SettingsListGroup.swift:108-139`) — chevron
  button that **navigates away**; B2 needs a sibling that **expands in place**.
- No `ExpandableSettingsRow` / `DisclosureGroup` under `Packages/`.
- VoiceInk beta reference (inspiration only, GPL — do not copy):
  `refs/benchmark/beingpax-v2.0-beta.2` → `ExpandableSettingsRow` pattern inside
  grouped Form; Prisma path `../VoiceInk/` when consulting.
- `macos-app-engineering-details.md` Settings section documents drill-down rows
  but not expandable disclosure.

```108:139:Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift
public struct SettingsListDrillDownButtonRow: View {
    // ...
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SettingsTitleWithPopover(...)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                // ...
            }
        }
    }
}
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSectionTests\|SettingsFormLayoutPolicyTests'` | exit 0 |
| Preview gate | `make preview-check` | exit 0 (or document baseline failures) |
| Guidance | `make guidance-check` | exit 0 after skill doc edit |
| Build | `make build-agent` | exit 0 |

## Suggested executor toolkit

- Read `.agents/skills/macos-app-engineering/SKILL.md` and
  `references/macos-app-engineering-details.md` before editing Settings UI.
- Use `localization` skill if new user-visible strings are required (prefer
  reusing existing keys for Export / Monitoring titles).
- Consult VoiceInk beta locally only as behavioral reference; do not copy code.

## Scope

**In scope:**

- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsExpandableSection.swift` (create)
- `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift` (only if sharing label helpers)
- `Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/` — small layout/behavior test if pure logic is extracted; otherwise preview-only is OK
- `.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md` — document expandable vs drill-down
- `plans/README.md` — status + supersede note for B2 vs prior rejection

**Out of scope:**

- Migrating Meetings / System / Activity content (094–096)
- Removing toolbar chrome (097)
- Changing Modes drawer
- Rewriting `SettingsSearchRouteManifest` beyond documentation notes
- Any audio / persistence / Keychain changes

## Git workflow

- Branch: `advisor/093-settings-flatten-ia` (or repo convention)
- Commits: Conventional Commits, e.g. `feat(settings): add ExpandableSettingsRow for flatten IA`
- Do NOT push or open a PR unless the operator instructs it

## Steps

### Step 1: Document the flatten contract in macos-app-engineering details

Add a short subsection under Settings patterns:

- Prefer expandable disclosure / sheets / side panels over new drill-down
  subpages.
- `SettingsListDrillDownButtonRow` is reserved for the few remaining child
  destinations (History; System Models/Dictionary/Audio until later plans).
- `SettingsExpandableSection` (name may be `SettingsExpandableRow`) for
  infrequent options that stay on the same page.
- Cite VoiceInk beta as inspiration only.

**Verify**: `make guidance-check` → exit 0

### Step 2: Implement `SettingsExpandableSection`

Create a Form-friendly expandable control:

- Header row: title, optional subtitle/helper via `SettingsTitleWithPopover`,
  chevron that rotates when expanded.
- `Binding<Bool>` or internal `@State` for expansion (prefer `@Binding` so
  parents can deep-link expand later).
- When expanded, render `@ViewBuilder` children **in the same `Section`** (or as
  trailing content under a divider), animated with
  `SettingsMotion.sectionAnimation(reduceMotion:)`.
- Honor `@Environment(\.accessibilityReduceMotion)`.
- Accessibility: header is a button; expanded state announced; children remain
  individually accessible.
- At least one `#Preview` at 600 and 900 widths inside `SettingsFormPage`.

Match design tokens from `AppDesignSystem`; do not invent new colors.

**Verify**: `make build-agent` → exit 0; `#Preview` compiles

### Step 3: Canary usage (non-product)

Optional: add a `#Preview` only canary, or temporarily use the expandable in a
preview-only wrapper. Do **not** migrate Meetings/System yet.

**Verify**: `make preview-check` → exit 0 or known baseline only

### Step 4: Update plan ledger supersede note

In `plans/README.md`, under dependency notes / rejected findings, record that
B2 plans 093–097 **supersede** the blanket “do not fold subroutes” stance for
Meetings export/prompts/monitoring navigation and System permissions/protected
apps navigation, while **preserving** plan 082 content-type exceptions
(collections, charts, History list stay specialized surfaces).

**Verify**: `rg -n "093|B2|flatten" plans/README.md` shows the note

## Test plan

- If the expandable type extracts pure layout math, add a tiny XCTest modeled
  after `SettingsFormLayoutPolicyTests`.
- Otherwise rely on compile + preview + guidance-check.
- Manual: VoiceOver expands/collapses; Reduce Motion disables chevron spin.

**Verify**: focused filter command above → exit 0

## Done criteria

- [ ] `SettingsExpandableSection` (or agreed name) exists with preview
- [ ] macos-app-engineering details document expandable vs drill-down
- [ ] `make guidance-check` exits 0
- [ ] `make build-agent` exits 0
- [ ] No Meetings/System/Activity product migration in this diff
- [ ] `plans/README.md` status row → DONE; supersede note present

## STOP conditions

- Product decides expandable disclosure is forbidden (sheets-only) — stop and
  refresh 093–097.
- Implementing expandable requires wrapping every child in a nested `Form` —
  violates 079; stop.
- Drift in `SettingsFormPage` scroll/width ownership since `bb6fbf79`.

## Maintenance notes

- 094–096 must reuse this primitive; do not invent a second disclosure API.
- Reviewers: ensure chevron-right drill-downs are not blindly replaced where a
  true child destination remains (History, Models).
- Deferred: search-driven auto-expand of sections (nice-to-have after 097).
