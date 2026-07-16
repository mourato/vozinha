# Plan 105: Prune dead agent context and make guidance drift fail closed

> **Executor instructions**: Execute last, after plans 102-104 are DONE. This is
> a mechanical cleanup with a large file count. Follow the inventories and
> exclusions literally; never delete an active skill or a TODO plan. Use
> `git mv` for historical plan moves. If status or ownership is ambiguous, STOP
> and report. Update this plan's row in the new slim `plans/README.md`.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat fa93d031..HEAD -- \
>   .agents/skills \
>   .agents/docs/skill-routing.md \
>   .agents/SKILLS_INDEX.md \
>   scripts/validate-agent-guidance.py \
>   scripts/tests \
>   Makefile \
>   plans
> ```
>
> Plans 102-104 are expected drift. Confirm they are DONE in the live ledger.
> STOP if any other TODO/IN PROGRESS plan or newly active skill appears.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/104-centralize-agent-routing-ownership.md`
- **Category**: tech-debt
- **Planned at**: commit `fa93d031`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — validator changes must land with cleanup and fixtures
- **Reviewer required**: `yes` — broad deletion/moves and validation infrastructure require exact inventory review
- **Rationale**: The plan touches `scripts/` and more than eight files, even though product behavior is unchanged.
- **Escalate when**: Any proposed deletion is referenced by an active skill, any historical plan is not conclusively complete, or recursive validation exposes broad unrelated debt.

## Why this matters

The project has invested in progressive disclosure, but two versioned skill
trees with no `SKILL.md` still contain 2,340 unreachable lines. The guidance
validator does not inspect nested references or reject such orphan trees, so it
passes while dead material remains. The root plans directory also contains 104
Markdown files and roughly 20,000 lines although the live ledger has only one
pre-existing TODO plan. Finally, the router and build reference repeat catalogs
and mutually contradictory validation sequences.

This plan removes dead skill content, strengthens the checker so it cannot
return, moves completed plans out of the root hot path without losing Git
history, and leaves one compact active ledger.

## Current state

### Orphan skill trees

The following tracked directories have references but no `SKILL.md` and no
incoming references from active guidance:

```text
.agents/skills/swiftui-animation/
  references/animations.md                         288 lines
  references/metal-shaders.md                    1,449 lines
  references/motion-guidelines.md                   65 lines
  references/transitions.md                        378 lines

.agents/skills/swiftui-performance-audit/
  references/demystify-swiftui-performance-wwdc23.md       46 lines
  references/optimizing-swiftui-performance-instruments.md 29 lines
  references/understanding-hangs-in-your-app.md             33 lines
  references/understanding-improving-swiftui-performance.md 52 lines
```

Total: 2,340 tracked lines. `rg` found no reference from outside those trees.
Do not treat an empty, untracked local directory as repository content.

### Validator blind spots

`scripts/validate-agent-guidance.py:11-15` uses only:

```python
MARKDOWN_FILES = [
    ROOT / "AGENTS.md",
    *sorted((ROOT / ".agents" / "docs").glob("*.md")),
    *sorted((ROOT / ".agents" / "skills").glob("*/SKILL.md")),
]
```

`validate_skill_catalog` and the final directory loop include only directories
that already contain `SKILL.md`. Nested `references/**/*.md`, `assets/**/*.md`,
and tracked orphan directories are invisible.

`INLINE_PATH_RE` does not recognize inline paths beginning with `references/`
or `assets/`. Consequently these ambiguous pointers pass:

- `.agents/docs/skill-routing.md:81` — `references/swiftui-review.md`
- `.agents/skills/apple-design/SKILL.md:25` — `references/swiftui-review.md`

The intended file is
`.agents/skills/macos-app-engineering/references/swiftui-review.md`.

### Duplicate hot-path catalogs and command recipe

- `.agents/SKILLS_INDEX.md` is the skill catalog.
- `.agents/docs/skill-routing.md:268-289` repeats a second “Skill Files and
  Direct Access” table with incomplete entries.
- `.agents/docs/build-and-test.md:13-24` says not to stack gates, while
  `:168-176` presents scope-check plus working, staged, committed, and
  empty-base validation as one sequence.

### Plan corpus

At planning time:

```text
find plans -type f -name '*.md' | wc -l       -> 104
wc -l plans/*.md                              -> 19,866 root-level lines
rg '\| TODO \|' plans/README.md               -> one pre-existing TODO (083)
rg '\| DONE' plans/README.md                   -> 47 recent DONE rows
```

`plans/README.md:78-80` already declares plans 001-061 completed or archived.
Rows 062-082 and 084-101 are also DONE. Plans 102-104 must be DONE before this
plan starts. Plan 083 remains active unless the live ledger says otherwise.

## Target structure

```text
plans/
  README.md                         # active/current batch only
  083-...md                         # keep if still TODO/IN PROGRESS
  102-...md                         # current remediation batch
  103-...md
  104-...md
  105-...md
  archive/
    2026-07-12-plan-ledger-history.md
    2026-07-16-plan-ledger-history.md # old full README preserved verbatim
    completed/
      001-...md through 082-...md
      084-...md through 101-...md
```

If 083 is DONE when executing, keep it in root for this cleanup batch; do not
expand the move set based on a runtime status change. Keep 102-105 in root as
the current audit batch.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Baseline guidance | `make guidance-check` | passes before edits |
| Orphan inventory | `for d in .agents/skills/*; do [ -d "$d" ] && [ ! -f "$d/SKILL.md" ] && git ls-files "$d/**"; done` | lists only the two known tracked trees |
| Incoming refs | `rg -n "swiftui-animation|swiftui-performance-audit|metal-shaders|understanding-improving-swiftui-performance" AGENTS.md .agents --glob '!skills/swiftui-animation/**' --glob '!skills/swiftui-performance-audit/**'` | no matches |
| Guidance fixtures | `make workflow-test` | `WORKFLOW_TEST_STATUS=PASS` |
| Guidance validation | `make guidance-check` | `Guidance validation passed.` |
| Root plan count | `find plans -maxdepth 1 -type f -name '*.md' | wc -l` | at most 6 (`README`, 083, 102-105) |
| Diff hygiene | `git diff --check` | no output |
| Full lane | `make validate-agent ARGS="--lane full --no-reuse --agent"` | `AGENT_STATUS=PASS` |

## Suggested executor toolkit

- Use `project-standards` for guidance ownership and deletion policy.
- Use `delivery-workflow` for the Full infrastructure lane.
- Use `improve` only to preserve active-plan/index semantics; do not generate new plans.
- Prefer `git mv` and `apply_patch`; do not rewrite Git history.

## Scope

**In scope**:

- Delete tracked files only under `.agents/skills/swiftui-animation/`
- Delete tracked files only under `.agents/skills/swiftui-performance-audit/`
- `scripts/validate-agent-guidance.py`
- `scripts/tests/guidance-validation-test.sh` (create)
- `scripts/tests/workflow-test.sh` only to invoke the new fixture suite
- `.agents/skills/apple-design/SKILL.md` only to fix the SwiftUI review pointer
- `.agents/docs/skill-routing.md`
- `.agents/SKILLS_INDEX.md` only if plan 104's canonical catalog needs a link adjustment
- `.agents/docs/build-and-test.md`
- `plans/README.md`
- `plans/archive/2026-07-16-plan-ledger-history.md` (create by moving the old README)
- `plans/archive/completed/` (create and move the exact completed files)
- Root plan files 001-082 and 084-101, move-only
- `plans/083-*.md` and `plans/102-105-*.md`, status/link adjustments only when necessary

**Out of scope**:

- Any product source or tests
- Any active skill directory containing `SKILL.md`, except the one-line apple-design pointer
- Rewriting substantive skill guidance or historical plan content
- Deleting Git history or squashing historical commits
- Moving plan 083 or plans 102-105 out of root
- Changing risk, hook, or routing semantics delivered by plans 102-104
- Scanning `.agents/reports/**` as agent guidance
- Adding a generic Markdown linter or external dependency

## Git workflow

- Work in an explicitly isolated worktree.
- Suggested branch: `chore/105-prune-agent-operational-context`
- Suggested commits:
  1. `fix(guidance): validate nested and orphaned skill content`
  2. `chore(skills): remove unreachable SwiftUI reference trees`
  3. `chore(plans): archive completed implementation plans`
  4. `docs(workflow): remove duplicate catalogs and gate recipes`
- Preserve renames with `git mv`; do not push or open a PR unless requested.

## Steps

### Step 1: Capture and verify the deletion/move inventory

Run all inventory commands before editing:

```bash
make guidance-check
for d in .agents/skills/*; do
  if [ -d "$d" ] && [ ! -f "$d/SKILL.md" ]; then
    git ls-files "$d/**"
  fi
done
rg -n "swiftui-animation|swiftui-performance-audit|metal-shaders|understanding-improving-swiftui-performance" \
  AGENTS.md .agents \
  --glob '!skills/swiftui-animation/**' \
  --glob '!skills/swiftui-performance-audit/**'
rg '\| (TODO|IN PROGRESS|BLOCKED|REJECTED)' plans/README.md
```

Expected:

- baseline guidance passes;
- tracked orphan output contains exactly the eight listed reference files;
- incoming-reference search has no matches;
- active-status output identifies 083 plus plans 102-105 according to live state.

Save command results in the implementation handoff, not a new repository report.

### Step 2: Add negative fixtures for the guidance validator

Create `scripts/tests/guidance-validation-test.sh` following the temporary
fixture style of existing scripts tests. It must create isolated minimal repos
or directory trees under `mktemp`, copy the validator, and clean up on EXIT.

Cover these cases:

1. Valid skill with `SKILL.md` plus valid nested reference → PASS.
2. Tracked/content-bearing skill directory without `SKILL.md` → FAIL with the
   directory name.
3. Broken Markdown link in `references/nested.md` → FAIL with file and target.
4. Broken inline `` `references/missing.md` `` in `SKILL.md` → FAIL.
5. Valid inline `references/existing.md` → PASS.
6. Hidden/unexpected child rules for active skill directories still fail.
7. A local empty directory without tracked/content files does not create a
   false failure.

Invoke the new script from `scripts/tests/workflow-test.sh` near the other
standalone fixture suites. It must print
`GUIDANCE_VALIDATION_TEST_STATUS=PASS`.

Write the failing tests first; confirm at least cases 2-4 fail against the old
validator for the intended reason.

**Verify**: running the new script before Step 3 must exit non-zero or report
the expected old-validator failures; after Step 3 it must pass.

### Step 3: Make guidance validation recursive and fail closed

Edit `scripts/validate-agent-guidance.py` with these bounded changes:

1. Build the Markdown set from:
   - `AGENTS.md`;
   - recursive `.agents/docs/**/*.md`;
   - recursive `.agents/skills/**/*.md` including `SKILL.md`, `references`, and
     Markdown assets.
2. Apply path-reference and Make-target validation to every file in that set.
3. Apply required-section, duplicate-heading, and placeholder checks only to
   `SKILL.md`; do not require skill sections in references/assets.
4. Extend inline path recognition to relative `references/` and `assets/` paths.
5. Inspect every immediate `.agents/skills/*` directory. If it contains any
   non-hidden repository content but lacks `SKILL.md`, emit a clear error.
   Ignore a truly empty local directory.
6. Preserve global-skill catalog handling and current allowed skill children.
7. Keep deterministic sorted, deduplicated errors.

Do not use Git history or network access. If deciding “repository content” via
`git ls-files` makes fixtures fragile, define it as any non-hidden descendant;
then remove any empty local directory during setup rather than weakening the
repository rule.

**Verify**:

```bash
python3 scripts/validate-agent-guidance.py
./scripts/tests/guidance-validation-test.sh
```

At this intermediate point, the live validator may fail only on the two known
orphan trees and the two ambiguous SwiftUI review pointers. Any broader set is
a STOP condition until classified.

### Step 4: Remove the unreachable trees and fix live references

After Step 1 proves no incoming references, delete exactly the eight tracked
orphan files and their now-empty directories. Do not migrate their generic
content into active skills; active Apple/macos guidance already owns these
domains through progressive disclosure.

Fix the two ambiguous SwiftUI review pointers to their actual relative paths:

- From `.agents/skills/apple-design/SKILL.md` use
  `../macos-app-engineering/references/swiftui-review.md`.
- From `.agents/docs/skill-routing.md` use
  `../skills/macos-app-engineering/references/swiftui-review.md` or a normal
  Markdown link resolving from `.agents/docs`.

**Verify**:

```bash
make guidance-check
./scripts/tests/guidance-validation-test.sh
```

Expected: both pass; `git ls-files` returns nothing for both deleted trees.

### Step 5: Remove duplicate catalogs and contradictory gate sequence

In `.agents/docs/skill-routing.md`, delete the repeated “Skill Files and Direct
Access” table. Replace it with one sentence linking to
`../SKILLS_INDEX.md` as the canonical catalog. Keep problem-specific routing.

In `.agents/docs/build-and-test.md`, replace lines 168-176 with mutually
exclusive choices:

- iteration: targeted test/build/scope check as needed;
- final local evidence: one clean-tree `validate-agent --lane auto`;
- exact committed evidence: one committed invocation when specifically needed;
- pre-push: owns exact pushed-range execution/reuse after plan 102.

Do not present all commands as a sequence. Preserve useful syntax examples in
an “alternatives” block if needed.

**Verify**:

```bash
make guidance-check
rg -n "Skill Files and Direct Access" .agents/docs/skill-routing.md
```

Expected: guidance passes; the duplicate heading has no match.

### Step 6: Archive completed plans without losing history

First move the old ledger intact:

```bash
git mv plans/README.md plans/archive/2026-07-16-plan-ledger-history.md
mkdir -p plans/archive/completed
```

Then move, with `git mv`, exactly:

- every root plan numbered 001 through 082;
- every root plan numbered 084 through 101.

Do not move 083 or 102-105. Include both legacy files beginning with `003-`.
Do not modify moved plan contents.

Create a new compact `plans/README.md` containing:

1. execution rules in at most 15 lines;
2. an active/current table for 083 and 102-105, preserving live statuses;
3. dependency order `102 -> 103 -> 104 -> 105`, with 083 independent;
4. links to both dated ledger archives and `archive/completed/`;
5. next available plan number `106`;
6. a short rejected/decided section only for still-relevant operational
   decisions; historical detail stays in the archived ledger.

Do not copy the 200-line completed dependency narrative into the new README.

**Verify**:

```bash
find plans -maxdepth 1 -type f -name '*.md' -print | sort
find plans/archive/completed -maxdepth 1 -type f -name '*.md' | wc -l
test -f plans/archive/2026-07-16-plan-ledger-history.md
rg '\| (TODO|IN PROGRESS|BLOCKED)' plans/README.md
```

Expected: root contains only README plus 083 and 102-105; historical ledger
exists; active statuses match the pre-move inventory.

### Step 7: Run the full infrastructure validation once

```bash
bash -n scripts/tests/guidance-validation-test.sh scripts/tests/workflow-test.sh
python3 -m py_compile scripts/validate-agent-guidance.py
make guidance-check
make workflow-test
git diff --check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Expected: all exit 0; workflow includes
`GUIDANCE_VALIDATION_TEST_STATUS=PASS`; final aggregate reports
`AGENT_STATUS=PASS`.

Inspect:

```bash
git status --short
git diff --stat
git diff --summary
```

Expected: product files untouched; historical plans appear as renames where Git
can detect them; only the exact orphan trees are deleted.

## Test plan

- New fixture suite: `scripts/tests/guidance-validation-test.sh`.
- Use temporary directories and deterministic local files only.
- Cover valid recursion, orphan rejection, broken nested link, broken inline
  reference, valid inline reference, active-skill child rules, and empty-dir behavior.
- Existing `make workflow-test` remains the single infrastructure fixture gate.
- `make guidance-check` validates the cleaned real repository.

## Done criteria

- [ ] The two orphan skill trees and exactly their eight tracked files are gone.
- [ ] Recursive nested references/assets are validated.
- [ ] Content-bearing skill directories without `SKILL.md` fail guidance validation.
- [ ] Inline `references/` and `assets/` paths are checked.
- [ ] New negative fixtures pass and are invoked by `make workflow-test`.
- [ ] The duplicate router catalog is removed.
- [ ] Build/test docs no longer present four validation modes as one sequence.
- [ ] Completed plans 001-082 and 084-101 are under `plans/archive/completed/`.
- [ ] The old ledger is preserved verbatim at the dated archive path.
- [ ] Root `plans/README.md` is compact and contains only active/current work.
- [ ] Guidance, workflow, diff, and one Full validation pass.
- [ ] No product file or active skill content outside the explicit pointer fix changed.
- [ ] Plan 105 row is updated in the new ledger.

## STOP conditions

Stop and report if:

- Any orphan file has an incoming reference outside its own tree.
- Any root plan in the move set is TODO, IN PROGRESS, BLOCKED, or otherwise active.
- Plan 083 or plans 102-105 would be moved by the mechanical command.
- Recursive validation reveals more than ten unrelated baseline errors or any
  error whose correct owner is unclear.
- An active skill directory lacks `SKILL.md` unexpectedly.
- Passing fixtures would require weakening path, catalog, or directory checks.
- The plan move would rewrite history rather than create normal Git renames.
- A required validation fails twice after a focused correction.

## Maintenance notes

- Keep `plans/README.md` active-only; move completed batches on a dated cleanup,
  not after every single plan.
- Git history and dated ledgers are the recovery path. Do not restore completed
  files to root merely for search convenience.
- Any new skill directory must start with `SKILL.md`; references/assets are
  subordinate and recursively checked.
- `SKILLS_INDEX.md` is the catalog; `skill-routing.md` maps problems, not files.
- Reviewers should treat unexplained growth in root plans or orphan skill
  references as operational context regression.
