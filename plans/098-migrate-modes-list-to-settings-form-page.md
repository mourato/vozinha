# Plan 098: Migrate Modes list into SettingsFormPage

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
> git diff --stat 58783893..HEAD -- \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/DictationSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormSectionHeader.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSectionHeader.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsInlineList.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsScrollableContent.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsPreviewEvidenceCatalog.swift \
>   Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings \
>   Packages/MeetingAssistantCore/Sources/Common/Resources/pt.lproj/Localizable.strings \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSearchIndexKeys.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSearchIndexTests.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/DictationStylesSettingsViewModelTests.swift \
>   Packages/MeetingAssistantCore/Tests/MeetingAssistantCoreTests/SettingsSubpageNavigationStateTests.swift \
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
- **Depends on**: plans/079-establish-single-form-settings-surface.md (DONE), plans/082-retire-form-islands-and-normalize-specialized-settings-surfaces.md (DONE)
- **Category**: migration
- **Planned at**: commit `58783893`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — must confirm Form chrome parity without regressing Modes selection / side-panel open behavior
- **Rationale**: One-subsystem Settings UI migration with interaction-preserving constraints; Medium risk triggers Full lane. Not Fast-allowlisted (behavior/layout change, not docs-only).
- **Escalate when**:
  - Native Form nesting / scroll ownership breaks and fixing it requires changing `SettingsFormPage` or `SettingsSidePanel`
  - Selection, double-click, Delete key, focus, or side-panel open cannot be preserved inside Form without inventing a new list primitive
  - Diff exceeds ~6 Swift source files beyond the in-scope list
  - Product asks to retire the trailing editor drawer (that is Option E — out of scope)

## Why this matters

Primary Settings tabs (Activity, Dictation, Meetings, Assistant, Integrations)
share one visual contract: `SettingsFormPage` with a first-group header of
`SettingsFormSectionHeader` + `.caption` description. Modes is the outlier —
its list page still uses `SettingsScrollableContent` + `SettingsSectionHeader`
and a second “Modes” title row. Migrating the **list** into `SettingsFormPage`
aligns Modes with the Form engineering direction without abandoning the
intentional trailing side-panel editor shell.

## Current state

### Architecture (keep this split)

```
ModesSettingsTab          ← side panel + DictationStyleRoute navigation (KEEP)
└── StylesSettingsTab     ← list page (MIGRATE SHELL ONLY)
    └── SettingsScrollableContent   ← REPLACE with SettingsFormPage
        ├── SettingsSectionHeader   ← REPLACE with Form page header
        └── HStack(Label Modes + Add) + SettingsInlineList
```

### Modes shell (do not redesign)

`ModesSettingsTab` hosts `StylesSettingsTab` and `.settingsSidePanel { … }`.
Editor routes stay on the drawer. Do not convert the editor to a sheet.

```19:45:Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift
    public var body: some View {
        listColumn
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .settingsSidePanel(
                isPresented: navigationState.currentRoute != nil,
                onDismiss: dismissEditor,
            ) {
                if let route = navigationState.currentRoute {
                    routeContent(for: route)
                        .id(route)
                }
            }
    }

    private var listColumn: some View {
        StylesSettingsTab(
            viewModel: viewModel,
            aiSettingsViewModel: aiSettingsViewModel,
            focusedStyle: $focusedStyle,
            accessibilityFocusedStyle: $accessibilityFocusedStyle,
            onOpenEditor: { styleID in
                viewModel.prepareEditor(for: styleID)
                focusedStyle = nil
                accessibilityFocusedStyle = nil
                openRoute(.editor(styleID: styleID))
            },
        )
    }
```

### Modes list today (replace this shell)

```27:56:Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift
    public var body: some View {
        SettingsScrollableContent {
            pageContent
        }
        .onDeleteCommand(perform: deleteSelectedStyle)
    }

    @ViewBuilder
    private var pageContent: some View {
        SettingsSectionHeader(
            title: "settings.section.rules_per_app".localized,
            description: "settings.styles.description".localized,
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("settings.styles.title".localized, systemImage: "paintpalette")
                    .font(.headline)
                Spacer()
                Button("settings.styles.add".localized, systemImage: "plus") {
                    onOpenEditor?(nil)
                }
                .buttonStyle(.bordered)
                .stylesAddFocus(
                    focusedStyle: focusedStyle,
                    accessibilityFocusedStyle: accessibilityFocusedStyle,
                )
            }
            stylesList
        }
    }
```

Divergences vs other primary tabs:

| Aspect | Dictation / Meetings / … | Modes list today |
|---|---|---|
| Shell | `SettingsFormPage` | `SettingsScrollableContent` |
| Header | `SettingsFormSectionHeader` + `.caption` | `SettingsSectionHeader` (`.headline` / `.subheadline`) |
| Title key | `settings.section.<tab>` | `settings.section.rules_per_app` (legacy) |
| Titling | One page title | Page header **and** inner `settings.styles.title` Label |
| Add action | N/A or section accessory | Separate HStack next to second title |

Row interaction (must preserve): single-click select, double-click open editor,
edit/remove buttons, context menu, `.onDeleteCommand`, focus /
accessibility focus helpers. Keep `SettingsInlineList` + `styleRow` logic;
do not rewrite row chrome unless Form layout forces a minimal padding tweak.

### Exemplars to copy (do not invent a third pattern)

**Page header** — match Dictation:

```29:35:Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/DictationSettingsTab.swift
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 4) {
                SettingsFormSectionHeader(title: "settings.section.dictation".localized, icon: "mic.fill")
                Text("settings.dictation.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
```

**Collection inside Form** — match Vocabulary (already embeds `SettingsInlineList`
inside one `Section`):

```25:67:Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 8) {
                ...
                SettingsFormSectionHeader(title: "settings.section.vocabulary".localized, icon: "text.book.closed")
                if showsHeader {
                    Text("settings.vocabulary.description".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } content: {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ...
                    SettingsInlineList(
                        items: viewModel.rules,
                        emptyText: "settings.vocabulary.empty".localized,
                        containerStyle: .plain,
                    ) { rule in
                        row(for: rule)
                    }
                    HStack {
                        Spacer()
                        Button { ... } label: {
                            Label("settings.vocabulary.add_rule".localized, systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                SettingsFormSectionHeader(title: "settings.vocabulary.replacement_rules".localized, icon: "arrow.2.squarepath")
            }
        }
```

**Header accessory API** (already supports trailing Add):

```4:40:Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormSectionHeader.swift
public struct SettingsFormSectionHeader<Accessory: View>: View {
    ...
    public init(
        title: String,
        icon: String? = nil,
        @ViewBuilder accessory: () -> Accessory,
    )
```

### Localization facts

| Key | en value | Role after this plan |
|---|---|---|
| `settings.section.modes` | Modes | **Use** as page title |
| `settings.styles.description` | Define reusable modes… | **Use** as page caption |
| `settings.styles.add` | Add Mode | **Use** as Add button |
| `settings.styles.title` | Modes | **Stop using in list UI** (duplicate of page title). Keep in strings + `SettingsSearchIndexKeys` + search tests — search still routes this key to `.modes` |
| `settings.section.rules_per_app` | Modes | **Stop using in list UI**. Keep key for search alias (`SettingsSearchRouteManifest` / index). Do not delete unless a separate localization cleanup is requested |

### Repo conventions that apply

- Reuse → extend → create: reuse `SettingsFormPage` + `SettingsFormSectionHeader` +
  `SettingsInlineList`. Do **not** create `SettingsPageHeader`, new list
  containers, or a Modes-specific Form wrapper.
- One scroll owner: `SettingsFormPage` owns the Form scroll. Do not wrap
  `SettingsFormPage` in `SettingsScrollableContent`, and do not nest a second
  page-level `Form`.
- User-facing strings: `"key".localized` only.
- Boolean control rule is irrelevant here (no new toggles).
- Side panel width/drawer UX is owned by existing Modes plans (078/074); leave it.
- Files prefer ≤600 lines; `StylesSettingsTab.swift` is already under that — keep it.

### Prior plan context (do not reopen)

Plan 082 intentionally retained Modes list as a specialized scroll surface. This
plan **supersedes that exception for the Modes list page only**. Activity
history, metrics dashboards, and other `SettingsScrollableContent` callers stay
scroll-owned. Do not “fix” those as part of this work.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift check | See executor instructions above | Empty or understood diffs only |
| Focused VM / nav / search tests (canonical filter — use this exact string in every step) | `swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStylesSettingsViewModelTests|SettingsSubpageNavigationStateTests|SettingsSearchIndexTests|AppSettingsDictationStylesTests|LocalizationKeyIntegrityTests'` | exit 0 |
| Preview declaration gate | `make preview-check` | exit 0 (Modes/Styles previews still declared) |
| Build | `make build-agent` | exit 0 |
| Lint (if iterating without commit) | `make lint-agent` | exit 0 |
| Lane classify (optional, once) | `make validate-agent ARGS="--lane auto --dry-run --base main"` | reports Medium/Full or Full |
| Merge gate before handoff | After Step 3.5 commit, on a clean tree: `make validate-agent ARGS="--lane auto --base main --agent"` | PASS |

## Suggested executor toolkit

- Read and follow `.agents/skills/macos-app-engineering/SKILL.md` (Settings Form
  patterns; reuse existing containers).
- Read `.agents/skills/localization/SKILL.md` only if you add/remove keys
  (default path: **no key deletion**).
- Do **not** invoke `frontend-skill` (web). Do not redesign motion (apple-design)
  unless Reduce Motion behavior regresses — then STOP.

## Scope

**In scope** (the only files you should modify):

- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift` — primary migration
- `Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift` — only if required for compile/preview wiring after the list shell change (prefer zero edits)
- `plans/README.md` — status row for 098 only (next number already 099)

**Out of scope** (do NOT touch, even though they look related):

- `DictationStyleEditorDetailView.swift`, `DictationStylePromptEditorView.swift`,
  `ModeEditorDrawer.swift`, `SettingsSidePanel.swift` — drawer/editor UX
- `DictationStylesSettingsViewModel` persistence / matching / triggers
- Activity, History, Metrics, Transcriptions scroll pages
- `SettingsFormPage.swift` / `SettingsFormSectionHeader.swift` API changes
  (reuse as-is; STOP if API is insufficient)
- Deleting `SettingsSectionHeader.swift` (still used by Activity/History)
- Removing localization keys or search-index entries for
  `settings.styles.title` / `settings.section.rules_per_app`
- Retiring the side panel in favor of sheets (Option E)
- Capability toggles on Modes
- New shared `SettingsPageHeader` abstraction (Option B — separate plan if desired)
- AGENTS.md / skill docs updates (unless validate/guidance fails because of a
  stale Modes exception claim — then only the minimal factual fix)

## Git workflow

- Branch: `advisor/098-modes-form-list` (or `refactor/098-modes-form-list`)
- Commits: Conventional Commits, e.g.
  - `refactor(settings): migrate Modes list to SettingsFormPage`
- Do NOT push or open a PR unless the operator asks.
- Do not amend unless the operator’s commit rules allow it.

## Target composition (load-bearing)

Replace `StylesSettingsTab.body` / `pageContent` with this shape (preserve
existing helpers: `stylesList`, `styleRow`, focus extensions, delete command):

```swift
public var body: some View {
    SettingsFormPage {
        VStack(alignment: .leading, spacing: 4) {
            SettingsFormSectionHeader(
                title: "settings.section.modes".localized,
                icon: "paintpalette",
            ) {
                Button("settings.styles.add".localized, systemImage: "plus") {
                    onOpenEditor?(nil)
                }
                .buttonStyle(.bordered)
                .stylesAddFocus(
                    focusedStyle: focusedStyle,
                    accessibilityFocusedStyle: accessibilityFocusedStyle,
                )
            }

            Text("settings.styles.description".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    } content: {
        Section {
            stylesList
        }
    }
    .onDeleteCommand(perform: deleteSelectedStyle)
}
```

Hard requirements for this shape:

1. **One page title** — `settings.section.modes` only. Remove
   `SettingsSectionHeader` and the inner `Label("settings.styles.title", …)`.
2. **Add Mode** stays available without a second “Modes” headline — place it as
   the `SettingsFormSectionHeader` accessory (preferred). If Form layout clips
   the bordered button in the page header, fallback: move Add to the bottom of
   the `Section` content `HStack { Spacer(); Button… }` exactly like Vocabulary
   — still no second Modes title.
3. **Keep** `SettingsInlineList(..., containerStyle: .plain)` and existing row
   builders. Do not switch to `SettingsListGroup` in this plan.
4. **Empty state** continues to show `settings.styles.empty` (via current
   `stylesList` / `SettingsInlineList` behavior).
5. **Do not** introduce a section header titled `settings.styles.title` — that
   recreates the duplicate Modes label this migration removes.
6. Spacing for the page header `VStack` is **4** (Dictation-style, no capability
   toggle). Do not use spacing 8 unless you also add a capability toggle (you must not).

## Steps

### Step 0: Drift check and baseline

Run the drift check from the executor instructions. Read the live
`StylesSettingsTab.swift` and confirm it still matches the excerpts above.

Run baseline focused tests once so regressions are attributable (same
canonical filter as Step 3 / Done criteria):

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStylesSettingsViewModelTests|SettingsSubpageNavigationStateTests|SettingsSearchIndexTests|AppSettingsDictationStylesTests|LocalizationKeyIntegrityTests'
```

**Verify**: exit 0 (or document known baseline failures and STOP if Modes-related tests already fail).

### Step 1: Swap the page shell to SettingsFormPage

In `StylesSettingsTab.swift`:

1. Replace `SettingsScrollableContent { pageContent }` with `SettingsFormPage`
   using the **Target composition** above.
2. Delete `pageContent` if it becomes unused, or inline it into `body`.
3. Remove all uses of `SettingsSectionHeader` from this file.
4. Remove the duplicate title `Label("settings.styles.title".localized, systemImage: "paintpalette")`.
5. Keep `.onDeleteCommand(perform: deleteSelectedStyle)`.
6. Keep `stylesList` / `styleRow` / menus / focus helpers intact.
7. Leave `#Preview` / `StylesSettingsPreview` in place (update only if the
   initializer signature changes — it should not).

**Verify**:

```bash
make build-agent
```

→ exit 0

```bash
rg -n 'SettingsScrollableContent|SettingsSectionHeader|settings\.section\.rules_per_app|settings\.styles\.title' \
  Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift
```

→ **no** matches for `SettingsScrollableContent`, `SettingsSectionHeader`, or
`settings.section.rules_per_app`.
→ **no** UI use of `settings.styles.title` in this file (search-index files may still reference it elsewhere).

### Step 2: Confirm Modes shell still owns the drawer

Open `ModesSettingsTab.swift`. Prefer **zero edits**. Confirm `listColumn` still
embeds `StylesSettingsTab` and `.settingsSidePanel` is unchanged.

Manually reason through (and note in the commit body / handoff):

- Add Mode → `onOpenEditor?(nil)` → `prepareEditor` + `.editor(styleID: nil)`
- Double-click / Edit → `onOpenEditor?(style.id)` → side panel presents
- Cancel/Save still close via existing drawer callbacks

**Verify**:

```bash
make build-agent
make preview-check
```

→ exit 0; Modes previews remain declared on `ModesSettingsTab.swift` and Styles
preview remains on `StylesSettingsTab.swift`.

### Step 3: Focused tests + interaction checklist

Run the canonical filter from the Commands table:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStylesSettingsViewModelTests|SettingsSubpageNavigationStateTests|SettingsSearchIndexTests|AppSettingsDictationStylesTests|LocalizationKeyIntegrityTests'
```

**Verify**: exit 0

Manual interaction checklist (preview or local app — required for handoff;
not substituted by `rg`/tests alone):

- [ ] Modes page shows Form-style header: accent `paintpalette` + “Modes” + caption
- [ ] No second “Modes” / styles title row above the list
- [ ] Add Mode visible and opens create editor in the trailing panel
- [ ] Single-click selects a row; selection chrome still visible
- [ ] Double-click opens editor for that mode
- [ ] Row edit button and context menu Edit/Remove still work
- [ ] Delete key removes the selected mode (same as before)
- [ ] Narrow preview (~620) and accessibility preview still compose without
      nested scroll fighting the side panel

Allowed Form-layout tweaks before STOP (and only these):

1. Move Add from page-header accessory to Vocabulary-style section footer
   `HStack { Spacer(); Button… }` if the bordered button clips in the header.
2. Adjust horizontal/vertical padding on the existing row container by at most
   ±8 pt if Form section insets make selection chrome look broken.

If a checklist item still fails after trying those two tweaks once each, STOP
and report. Do not invent new components or change the drawer.

### Step 3.5: Commit

With working tree containing only in-scope changes, commit:

```bash
git add \
  Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift \
  Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/ModesSettingsTab.swift \
  plans/README.md
git commit -m "$(cat <<'EOF'
refactor(settings): migrate Modes list to SettingsFormPage

EOF
)"
```

Only stage `ModesSettingsTab.swift` if you actually edited it. If the operator
has not authorized commits yet, STOP after Step 3 and hand off the diff instead
of inventing a commit policy — but prefer committing when this plan is the
execution authority and the operator asked to implement the plan.

**Verify**: `git status` shows clean tree (or only unrelated pre-existing
worktree files that were already dirty before you started — do not touch those).

### Step 4: Validate and update ledger

On the clean committed tree:

```bash
make validate-agent ARGS="--lane auto --base main --agent"
```

**Verify**: PASS (expect Full for Medium UI migration).

Update `plans/README.md`:

1. Set plan 098 status to `DONE` (use `IN PROGRESS` while implementing, then `DONE`).
2. Confirm the “next available plan number” line already says **099** — do **not**
   bump it further. (The ledger was advanced to 099 when this plan was authored.)
3. Confirm the dependency note for 098 already exists (Modes list Form-owned;
   drawer remains specialized). Only add a note if it is missing.

If ledger status was not updated in the same commit as the Swift change, make a
follow-up commit: `docs(plans): mark 098 done`.

**Verify**:

```bash
rg -n '098|next available plan number' plans/README.md
git status
```

→ 098 listed DONE; next number remains 099; no unexpected untracked files outside scope.

## Test plan

- **No new XCTest suite required** if existing ViewModel / navigation / search
  tests pass and the interaction checklist is completed. Modes list UI is
  SwiftUI-heavy; ViewModel tests already cover CRUD.
- Do **not** delete `SettingsSearchIndexTests` coverage for
  `settings.styles.title` — that key remains a search alias even if unused in
  the list chrome.
- If you accidentally remove a localization key, restore it; this plan does not
  authorize key deletion.
- Pattern for any *optional* characterization test (only if reviewer asks): model
  after `SettingsSubpageNavigationStateTests` — assert route open/close still
  works; do not snapshot SwiftUI.

Verification:

```bash
swift test --package-path Packages/MeetingAssistantCore --filter 'DictationStylesSettingsViewModelTests|SettingsSubpageNavigationStateTests|SettingsSearchIndexTests|AppSettingsDictationStylesTests|LocalizationKeyIntegrityTests'
```

→ all pass.

## Done criteria

ALL must hold. Split so a weaker executor does not mark DONE from automated
gates alone.

### Automated gates (commands)

- [ ] `rg -n 'SettingsScrollableContent|SettingsSectionHeader|settings\.section\.rules_per_app|settings\.styles\.title' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift` → no matches
- [ ] `rg -n 'SettingsFormPage|settings\.section\.modes|settings\.styles\.description|settings\.styles\.add' Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/StylesSettingsTab.swift` → all four patterns match
- [ ] Canonical focused tests exit 0
- [ ] `make preview-check` exits 0
- [ ] `make build-agent` exits 0
- [ ] `make validate-agent ARGS="--lane auto --base main --agent"` PASS on clean tree
- [ ] `git diff --name-only` / `git status` show no out-of-scope product files
- [ ] `plans/README.md`: 098 is DONE; next available plan number remains 099

### Manual handoff checklist (preview / local app)

- [ ] Form-style page header: accent `paintpalette` + Modes + caption
- [ ] No second Modes / styles title row
- [ ] Add Mode present (header accessory **or** Vocabulary-style footer)
- [ ] Select / double-click / edit / context menu / Delete key still work
- [ ] Side panel still opens for create and edit; cancel/save still dismiss
- [ ] Narrow + accessibility Modes previews still compose without nested-scroll fight

## STOP conditions

Stop and report back (do not improvise) if:

- Drift check shows in-scope files no longer match the Current state excerpts.
- Nesting `SettingsInlineList` inside `SettingsFormPage` creates a double-scroll
  or broken hit-testing that cannot be fixed without changing
  `SettingsFormPage`, `SettingsInlineList`, or `SettingsSidePanel`.
- Selection / double-click / Delete / focus / side-panel open regress after the
  two allowed Form-layout tweaks in Step 3 (Add footer move; ±8 pt padding).
- You believe the section must use `SettingsListGroup` or a new component to
  look correct — report; do not invent it in this plan.
- Operator/product asks to replace the drawer with sheets mid-flight.
- Any verification command fails twice after one corrective edit aimed at that
  failure (do not thrash).
- Localization integrity fails because of an unintended key deletion.

## Maintenance notes

- Future Modes work should treat the **list** as a Form page and the **editor**
  as a specialized side panel. Do not reintroduce `SettingsScrollableContent` on
  the list without an ADR/plan exception.
- Reviewers should scrutinize: duplicate titles creeping back, accidental drawer
  redesign, and Form nested inside scroll (forbidden).
- Deferred follow-ups (explicitly not this plan):
  - Option B shared `SettingsPageHeader` extraction across all tabs
  - Removing obsolete `settings.section.rules_per_app` / `settings.styles.title`
    after search aliases are cleaned up
  - Migrating editor drawer chrome (already Form inside drawer)
  - Visual evidence catalog expansion for Modes Form states (plan 083 still TODO)
