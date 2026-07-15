# Plan 083: Add route-wide visual evidence and truthful preview gates for Settings

> **Executor instructions**: Execute last, after Plans 079-082. This plan changes
> validation tooling, so it is Full lane even if individual preview edits look
> small. Never claim previews compile or render unless a command actually builds
> or renders them. Keep all preview data local and synthetic.

> **Drift check (run first)**:
>
> ```bash
> git diff --stat a9a86350..HEAD -- \
>   scripts/preview-check.sh \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings \
>   Packages/MeetingAssistantCore/Tests \
>   .agents/docs/build-and-test.md \
>   plans/README.md
> ```

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: `plans/079-establish-single-form-settings-surface.md`, `plans/080-migrate-primary-settings-journeys-to-form-sections.md`, `plans/081-migrate-system-settings-hierarchy-to-form-sections.md`, `plans/082-retire-form-islands-and-normalize-specialized-settings-surfaces.md`
- **Category**: tests
- **Planned at**: commit `a9a86350`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — route matrix and tooling semantics validate the combined final surface.
- **Reviewer required**: `yes` — tooling reviewer plus visual reviewer; thermo review clears all Critical/Medium findings.
- **Rationale**: Touches `scripts/` and broad Settings preview/test coverage; project policy mandates Full.
- **Escalate when**: A new snapshot dependency, CI image renderer, private preview API, or broad test-fixture migration is required.

## Why this matters

The width/background regression passed existing checks because
`scripts/preview-check.sh` only compares directories containing views with
directories containing at least one `#Preview`. One preview can therefore cover
every tab in the directory, and the script neither compiles nor renders it.
This plan makes the check truthful and adds a route/state matrix that exposes
misaligned Form sections before merge.

## Current state

- `scripts/preview-check.sh:12-31` reduces both view and preview paths to
  directories and checks directory-level presence only.
- `SettingsFormGroup.swift:51-64` had only a fixed 520 pt preview.
- `ModesSettingsTab.swift:138-147` is the best current matrix: normal, narrow,
  accessibility, dark, Reduce Motion, and Reduce Transparency.
- `SettingsScrollableContent.swift:115-130` has width/accessibility variants but
  demonstrates legacy `DSGroup`, not the new single-Form page contract.
- Existing route/view-model tests validate behavior but none measures the
  header/Section width relationship.

## Target evidence matrix

Cover every reachable surface, grouped by family:

| Family | Required routes/states |
|---|---|
| Activity | root, history empty/populated, performance, recording detail, more insights, event detail |
| Dictation | normal plus long labels/help and provider loading/error/configured |
| Modes | list, editor, prompt child; normal/narrow/accessibility and reduced effects |
| Meetings | root, monitoring apps/sites, export off/on/error, prompts disabled/enabled |
| Assistant | disabled/enabled, visual feedback variants |
| Integrations | empty/populated, editor, advanced script result without executing a script |
| System | root, models empty/configured/error, dictionary empty/populated, sound default/custom, permissions states, protected apps empty/populated |

For Form pages, inspect 600, 900, and 1200 pt content widths in light/dark and
one accessibility text size. Standard Section leading/trailing guides must
match; no centered island or custom white background may appear. Use synthetic
data only; no transcript, prompt, credential, identifier, network, Keychain,
hardware, model download, or script execution.

## Reuse -> extend -> create decision

- Reuse existing previews, test doubles, route state objects, Modes matrix, and
  `make build-agent`/Full gate.
- Extend `preview-check.sh` with fixture-backed, accurately named guarantees.
- Create the smallest Settings preview catalog/helper needed to avoid duplicate
  setup; do not create production view models or a screenshot dependency.
- If the repo cannot compile/render previews headlessly, document the manual
  visual step honestly and use the app build as the compilation gate.

## Scope

**In scope**: `scripts/preview-check.sh`; a fixture/test script for it under the
existing scripts test convention; settings previews and preview-only seams;
focused pure layout/route tests; `.agents/docs/build-and-test.md` only to state
the command's real guarantee; plan/ledger status.

**Out of scope**: production settings behavior/layout except a confirmed final
regression; third-party snapshot frameworks; CI service changes; real user data
or external services; rewriting all previews repository-wide in one step.

## Commands

```bash
make workflow-test
swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsFormLayoutPolicyTests|SettingsSectionTests|SettingsSearchIndexTests|ActivitySettingsNavigationStateTests|MeetingSettingsNavigationStateTests|SettingsSubpageNavigationStateTests'
make preview-check
make build-agent
make guidance-check
make lint-agent
git diff --check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Expected: fixture tests prove preview-check semantics; selected tests pass;
preview inventory/build/guidance/lint/diff checks exit 0; Full aggregate PASS.

## Git workflow

- Branch/worktree: `test/083-settings-form-visual-gates` in one isolated worktree.
- Use atomic Conventional Commits: preview-check fixtures/semantics, preview matrix, then guidance updates.
- Do not push, merge, or open a PR unless instructed; never commit machine-specific or privacy-sensitive images.

## Steps

### Step 1: Add regression fixtures for the current preview checker

Create isolated temporary fixtures that prove:

1. a view file without a preview fails even when a sibling in the same directory has one;
2. a view file with its own valid preview declaration passes;
3. excluded/generated files follow explicit documented rules;
4. the command never says "compiled" or "rendered" unless it performs that work.

**Verify**: the old implementation fails the new regression fixture; the test harness itself exits deterministically.

### Step 2: Harden and rename the guarantee

Change the script to the strongest affordable per-file/explicit-exemption
contract without forcing unrelated historical debt into this plan. If staged
adoption is required, scope it to Settings files and record the remaining debt
as an explicit mode, never as a false global PASS.

**Verify**: all fixtures pass and `make preview-check` output states exactly what was checked.

### Step 3: Build the Settings preview matrix

Add or update deterministic previews for every family/route/state in the table.
Factor preview-only fixtures where repeated setup is substantial. Use existing
audio/provider/settings test doubles and fixed sample strings.

**Verify**: `make preview-check` and `make build-agent` pass with no live side effects.

### Step 4: Perform and record visual acceptance

Render/inspect the matrix in Xcode or the supported local preview surface.
Record command/build version, macOS version, widths/states inspected, and PASS/
FAIL for: one scroll owner, full outer width, aligned guides, consistent native
background, visible labels, long-label wrapping, focus order, and disabled/
expanded states. Store only privacy-safe evidence in the existing validation
artifact location; do not commit machine-specific screenshots unless project
policy explicitly supports them.

### Step 5: Update command documentation and run the final gate

Update `.agents/docs/build-and-test.md` to distinguish preview declaration
coverage, app compilation, and manual/rendered visual inspection. Run guidance,
workflow fixtures, focused tests, build, lint, and the Full gate.

## Test plan

- Shell fixtures: sibling-preview false positive, per-file pass, explicit
  exclusion, and truthful command wording.
- Layout policy: 600/900/1200 pt fluid width cases.
- Route sentinels: Settings section/search plus Activity, Meetings, and Modes
  navigation histories.
- Visual matrix: every family/state in the table, with synthetic data and a
  recorded manual/rendered inspection checklist.

## Done criteria

- [ ] Directory-level false positive fixture fails before and passes after the script fix.
- [ ] `preview-check` makes no compile/render claim it cannot prove.
- [ ] Every reachable Settings route is represented in the family matrix.
- [ ] Form pages cover 600/900/1200 pt, light/dark, and accessibility text.
- [ ] Visual evidence confirms aligned full-width Sections and no centered islands.
- [ ] All previews use synthetic local data and trigger no external side effects.
- [ ] Workflow/focused/build/guidance/lint/Full gates pass.
- [ ] Required tooling, visual, and thermo reviews pass.

## STOP conditions

- Hardening requires unrelated repository-wide preview migration.
- Headless rendering requires a new external dependency or CI change.
- A preview touches hardware, network, Keychain, model download, scripts, or user data.
- A visual failure requires product behavior changes outside Plans 079-082.

## Maintenance notes

Future Settings changes must update the closest route/state preview and run the
real build plus the accurately scoped preview declaration check. Visual layout
claims always require rendered/manual evidence; text-grep coverage is not a
substitute.
