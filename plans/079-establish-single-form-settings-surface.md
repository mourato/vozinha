# Plan 079: Establish one full-width native Form surface per settings page

> **Executor instructions**: Read this plan completely before editing. Work in
> an isolated worktree. Run each verification before advancing. This plan
> establishes the reusable surface only; do not migrate every settings page.
> If a STOP condition occurs, report it instead of inventing another container.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat a9a86350..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormGroup.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSectionHeader.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsListGroup.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests \
>   plans/README.md
> ```
>
> If these files changed, compare the live implementation with the invariants
> below before proceeding. Any mismatch in scroll ownership or width ownership
> is a STOP condition until the plan is refreshed.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Status**: DONE
- **Planned at**: commit `a9a86350`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — the component API, scroll owner, width policy, and canary previews are one contract.
- **Reviewer required**: `yes` — this becomes the shared owner for every Settings page.
- **Rationale**: A public UI component and page-level scrolling behavior change; this is not deterministic styling-only work.
- **Escalate when**: More than one product page must be migrated to prove the component, AppKit introspection becomes necessary, or the solution requires a hard maximum width.

## Why this matters

The migration in `d2c45d00` introduced a separate scroll-disabled `Form` for
each group. Its title sits outside the `Form`, so the title and grouped body use
different inset rules; the actual `Form` also does not claim the available
width. This produces the centered/narrow islands visible in the supplied
screenshots. The target is one native grouped `Form` per page or editor, with
native `Section`s and one scroll owner.

## Locked reference and invariants

Use VoiceInk release `v2.0-beta.2`, pinned to commit
`ba32144fea4bc687b4f20e3bb03ec9719a401482`, as behavioral reference only:

- `VoiceInk/Views/Settings/SettingsView.swift:28-30,69-73,143-191,265-270`
- `VoiceInk/Modes/ModeConfigFormView.swift:128-143`
- <https://github.com/Beingpax/VoiceInk/blob/ba32144fea4bc687b4f20e3bb03ec9719a401482/VoiceInk/Views/Settings/SettingsView.swift>

VoiceInk is GPL-3.0 and Prisma is MIT. Do not copy code. Recreate only these
ideas with Prisma naming and design tokens:

- exactly one vertical scroll owner;
- a single `.formStyle(.grouped)` Form for scalar configuration content;
- groups represented by native `Section`s;
- `.scrollContentBackground(.hidden)` and full available width/height;
- no main-page maximum width and no fixed 400 pt width outside Modes;
- visible native labels for ordinary `Picker`, `Toggle`, and `LabeledContent` rows.

## Current state

- `SettingsScrollableContent.swift:27-52` owns an outer `ScrollView`, 20 pt
  horizontal gutters, and a minimum viewport-sized content stack.
- `SettingsFormGroup.swift:23-47` creates one inner `Form` per group, disables
  scrolling, fixes vertical size, and expands only the outer `VStack`.
- `SettingsListGroup.swift:66-100` uses a full-width `DSCard`, so mixed pages
  alternate native Form backgrounds and custom white/material cards.
- `DictationStyleEditorDetailView.swift:123-190` is the closest local exemplar:
  one grouped Form claims the editor body. Preserve its drawer-specific width.
- No XCTest references `SettingsFormGroup`, `SettingsScrollableContent`, or a
  settings width policy. The only `SettingsFormGroup` preview is fixed at 520 pt.

## Reuse -> extend -> create decision

1. Reuse `SettingsSectionHeader`, `SettingsContentSurface` gutter values,
   native `Form`/`Section`, semantic colors, and current localization.
2. Extend the settings component family with a page-level Form owner and a
   reusable Section header label that accepts title, optional SF Symbol, and
   optional trailing accessory.
3. Keep `SettingsScrollableContent` for data dashboards, lists, and composed
   non-Form pages; do not turn it into a second Form mode.
4. Keep `SettingsFormGroup` temporarily for buildable staged migration, but
   mark it transitional and remove it in Plan 082 after all callers migrate.
5. Do not create a custom layout engine, duplicate design tokens, or use AppKit
   introspection to fight native Form insets.

## Target component contract

Create narrowly named primitives under `components/settings/`:

- `SettingsFormPage`: owns the sole grouped `Form`, hidden scroll background,
  full width/height, page header presentation, and native scrolling.
- `SettingsFormSectionHeader`: renders the existing accent icon/title/accessory
  anatomy as a native Section header without its own card/background.
- `SettingsFormLayoutPolicy`: a small pure policy for available width, outer
  gutter, and fluid content width; it must not reproduce SwiftUI Form internals
  or introduce a maximum content width.

The page header must remain part of the scrolling content. It must align with
the page's section guide at 600, 900, and 1200 pt. If SwiftUI cannot express
that without an empty visible section or a second scroll owner, STOP with a
minimal preview and report the platform behavior.

## Scope

**In scope**:

- create `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormPage.swift`
- create `Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormSectionHeader.swift`
- create `SettingsFormLayoutPolicy.swift` and `SettingsFormLayoutPolicyTests.swift`
- update `SettingsFormGroup.swift` only for transition documentation/previews
- update `SettingsScrollableContent.swift` previews to show Form vs non-Form ownership
- `plans/README.md` status at final handoff

**Out of scope**:

- Product page migrations; those belong to Plans 080 and 081.
- `SettingsPage.swift` navigation/chrome, sidebar taxonomy, persistence, strings,
  control behavior, or VoiceInk source.
- Hard widths on the Form or Section, screenshot-test dependencies, or a second
  design-system card around native grouped sections.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Scope | `make scope-check-agent ARGS="--dry-run --base main"` | exit 0; Full if the live scope requires it |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsFormLayoutPolicyTests|SettingsSubpageNavigationStateTests'` | all selected tests pass |
| Preview inventory | `make preview-check` | exit 0; presence only, not rendering proof |
| Build | `make build-agent` | exit 0 |
| Lint | `make lint-agent` | no new errors in touched files |
| Diff hygiene | `git diff --check` | exit 0 |
| Final gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | aggregate PASS with strict lint and build-test children PASS |

## Git workflow

- Branch/worktree: `refactor/079-single-form-settings-surface` in an explicitly isolated worktree.
- Use atomic Conventional Commits, suggested message: `refactor(ui): establish settings form surface`.
- Preserve unrelated changes; do not push, merge, or open a PR unless instructed.

## Steps

### Step 1: Capture the current visual failure

Add deterministic previews at 600, 900, and 1200 pt showing a page header and
two sections with picker, toggle, drill-down, long label, and multiline help.
Include light, dark, and accessibility-size variants with no live services.

**Verify**: build the package/app and inspect all width variants. Record that
the old component shows unequal header/body guides before replacing it.

### Step 2: Implement the single-Form page owner

Make one `Form` own scrolling, grouped style, hidden background, and infinite
frame. Put each group in a native `Section`. Keep the content header in the same
scroll coordinate space. Standard controls must expose labels; individual
compact controls may retain bounded widths, but their Section cannot.

**Verify**: the preview hierarchy contains no `ScrollView` wrapping a `Form`,
no `.scrollDisabled(true)`, and no `.fixedSize` on the page Form.

### Step 3: Add deterministic layout policy coverage

Test 600/900/1200 pt inputs and exact outer gutter/content-width outputs. The
policy must always return available width minus declared outer gutters and must
never clamp to a maximum. Do not claim XCTest proves native Form's internal
layout; visual inspection remains required.

**Verify**: focused tests pass and contain named narrow/standard/wide cases.

### Step 4: Validate native behavior and accessibility

Check keyboard focus order, VoiceOver Section names, Dynamic Type wrapping,
dark appearance, and Reduce Transparency. Ensure no nested scroll bars and no
white custom card behind a native grouped section.

**Verify**: `make build-agent`, `make preview-check`, `git diff --check`, then
the final Full gate all pass.

## Test plan

- Add `SettingsFormLayoutPolicyTests` with narrow (600), standard (900), and
  wide (1200) cases, plus a non-positive-width defensive case.
- Add deterministic preview states for picker, toggle, drill-down, long label,
  multiline help, dark appearance, and accessibility text.
- Use `SettingsSubpageNavigationStateTests` only as a regression sentinel for
  the surrounding Settings component package; do not imply it tests layout.

## Done criteria

- [x] One preview matrix demonstrates narrow/standard/wide and accessibility.
- [x] The Form is the only vertical scroll owner.
- [x] Header and all standard Section bounds share leading/trailing guides.
- [x] No page-level maximum width exists.
- [x] `SettingsFormLayoutPolicyTests` exists and passes all width cases.
- [x] No product page behavior changed.
- [x] Full gate passes and a reviewer clears all Critical/Medium findings.

## STOP conditions

- The page header requires a visible empty Form card or a second scroll owner.
- Full width requires private AppKit APIs or introspection.
- A native Form cannot host the required custom rows accessibly.
- The change requires editing Settings navigation/chrome or product state.

## Maintenance notes

Plan 080 and Plan 081 must use these primitives rather than reproducing the
modifiers. Reviewers should reject any later `Form` nested in
`SettingsScrollableContent` or any standalone scroll-disabled Form per group.
