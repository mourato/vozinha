# Plan 057: Reduce recurring agent context through an active ledger and routed skill references

> **Executor instructions**: Follow this plan step by step. This is a guidance-
> only refactor: preserve every hard constraint and behavior. Run every
> verification command before moving on. If a STOP condition occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 58ca8a84..HEAD -- plans/README.md plans/archive .agents/skills/apple-design .agents/skills/thermo-nuclear-code-quality-review .agents/skills/macos-app-engineering .agents/skills/delivery-workflow .agents/SKILLS_INDEX.md .agents/skills/SKILLS_TAXONOMY.md .agents/docs/skill-routing.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Lane**: Fast, but guidance-check is mandatory
- **Depends on**: none
- **Category**: docs / dx
- **Planned at**: commit `58ca8a84`, 2026-07-12

## Why this matters

Agents reading the canonical plan ledger currently ingest 5,844 words even
though almost every plan is complete. Frequently triggered skills also require
full reads of material unrelated to the current subdomain. Progressive
disclosure should keep triggers, hard constraints, routing, and decision tables
in each `SKILL.md`, while moving deep domain guidance into references that are
loaded only when the request needs them. This reduces input tokens without
removing project knowledge.

## Current state

Measured at commit `58ca8a84`:

| File | Lines | Words | Observation |
|---|---:|---:|---|
| `plans/README.md` | 314 | 5,844 | Only plan 040 was TODO before plans 055-060 were added |
| `.agents/skills/apple-design/SKILL.md` | 439 | 4,339 | Gesture, motion, material and typography details are always loaded together |
| `.agents/skills/thermo-nuclear-code-quality-review/SKILL.md` | 263 | 2,441 | Review policy and deep category guidance share one file |
| `.agents/skills/macos-app-engineering/SKILL.md` | 218 | 1,616 | Core routing and detailed UI implementation guidance share one file |
| `.agents/skills/delivery-workflow/SKILL.md` | 238 | 1,399 | Lane contract, command catalog, Git examples and troubleshooting share one file |

- `plans/README.md:167-224` contains the status table; historical audit scopes
  occupy most of the preceding file.
- `plans/README.md:124-128` already says reusable knowledge belongs in skills
  and stale/duplicated material should be removed.
- Repository routing is centralized in `.agents/docs/skill-routing.md`; preserve
  canonical ownership and do not create replacement skills.
- Official GPT-5.6 guidance reports that leaner prompts/tool descriptions can
  reduce tokens materially, but directs users to validate on representative
  tasks. Treat the reduction as a hypothesis to measure, not a guaranteed rate:
  https://developers.openai.com/api/docs/guides/latest-model#favor-leaner-prompts

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Guidance | `make guidance-check` | exit 0 |
| Link/path check | `rg -n "references/|plans/archive" .agents/skills plans/README.md` | all referenced paths exist |
| Size report | `wc -l -w plans/README.md .agents/skills/{apple-design,thermo-nuclear-code-quality-review,macos-app-engineering,delivery-workflow}/SKILL.md` | core files are smaller than baseline |
| Diff hygiene | `git diff --check` | exit 0 |
| Scope preview | `make scope-check-agent ARGS="--dry-run --base main"` | guidance-only strategy, exit 0 |

## Suggested executor toolkit

- Use `project-standards` for guidance ownership and validation.
- Use the affected skill itself while splitting it, so its hard constraints are
  not accidentally lost.
- Do not use `code-quality` to rewrite tone broadly; this is structural routing.

## Scope

**In scope**:

- `plans/README.md`
- `plans/archive/` (create dated historical index files)
- `.agents/skills/apple-design/`
- `.agents/skills/thermo-nuclear-code-quality-review/`
- `.agents/skills/macos-app-engineering/`
- `.agents/skills/delivery-workflow/`
- `.agents/SKILLS_INDEX.md`
- `.agents/skills/SKILLS_TAXONOMY.md`
- `.agents/docs/skill-routing.md`

**Out of scope**:

- App source, tests, scripts, Makefile behavior, changing risk lanes, deleting
  specialist skills, or weakening any hard constraint.
- Moving project-specific guidance into global `~/.codex/AGENTS.md`.
- Creating summary files that duplicate rather than relocate the original text.

## Git workflow

- Branch: `docs/057-agent-guidance-progressive-disclosure`
- Commit: `docs(agents): reduce recurring guidance context`
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Make the ledger active-first

Move completed historical audit scopes, completed status rows, long dependency
notes for finished chains, and considered/rejected history into dated files
under `plans/archive/`. Keep `plans/README.md` as the canonical active ledger
containing:

- next monotonic plan number;
- TODO/IN PROGRESS/BLOCKED plans and their live dependencies;
- recently completed plans only when needed to explain an active dependency;
- status-value contract and execution rules;
- links to archives.

Do not renumber any plan. Preserve searchable history verbatim in the archive
except for fixing broken links introduced by the move.

**Verify**: every `plans/NNN-*.md` appears either in the active index or a linked
archive; active TODO dependencies resolve; `plans/README.md` is materially below
the 5,844-word baseline.

### Step 2: Split the largest skill first and establish the pattern

Start with `apple-design`. Keep in `SKILL.md`:

- frontmatter and trigger description;
- role/scope boundaries;
- non-negotiable accessibility/platform rules;
- compact decision/routing table mapping task types to references;
- required validation/handoff contract.

Move detailed gesture physics, animation recipes, material/depth guidance,
typography/scaling guidance, and long examples into narrowly named files under
`references/`. The core must explicitly say which reference to read for which
task. Do not make a required safety rule conditional on reading a reference.

**Verify**: compare every original heading against either the core or one routed
reference; no section disappears; `make guidance-check` passes.

### Step 3: Apply the proven pattern to review, macOS, and delivery

Split only material with a clean trigger:

- Thermo: keep severity, semaforo, blocking rules, finding contract and privacy
  in core; route category checklists and extended examples.
- macOS app engineering: keep ownership/boundaries/platform constraints in core;
  route Settings, previews, lifecycle/AppKit bridge, and detailed SwiftUI recipes.
- delivery workflow: keep risk/lanes/evidence and canonical final commands in
  core; route Git/PR examples, troubleshooting, and command reference.

Update indexes/routing only where paths or descriptions change. Avoid a target
line count that would force awkward fragmentation; the success criterion is
that a routine task loads only relevant instructions while all hard rules remain
unconditional.

**Verify**: guidance validation passes, reference links exist, and a manual
heading inventory shows zero lost constraints.

### Step 4: Measure before declaring success

Using the controlled manifest under `/Users/usuario/.codex/evals/tasks.jsonl`,
run the same read/plan/diff tasks before and after this guidance refactor once
Plan 058's evaluator is available. Until then, record only static word-count
reduction; do not claim token savings from word count alone.

**Verify**: the plan handoff reports old/new word counts and either controlled
token/cost results or explicitly says measurement is deferred to Plan 058.

## Test plan

- `make guidance-check` after each skill split.
- Verify every Markdown link/path with targeted `rg` plus file existence checks.
- Compare original vs new heading inventory.
- Confirm all active plan rows and dependencies remain in the root ledger.
- Run controlled token evaluation after Plan 058; static size is not a quality
  acceptance test.

## Done criteria

- [ ] Root ledger contains active work first and links complete archives.
- [ ] Plan numbering/history is preserved without duplication.
- [ ] Each affected skill core retains triggers, hard constraints, routing, validation, and handoff rules.
- [ ] Detailed references are loaded by explicit task-specific routes.
- [ ] No project constraint moved to global guidance.
- [ ] `make guidance-check` and `git diff --check` pass.
- [ ] Old/new sizes are reported; token/cost claims require controlled evidence.
- [ ] `plans/README.md` marks plan 057 `DONE`.

## STOP conditions

- A hard safety/privacy/platform rule would become conditional on loading a reference.
- Moving history would break monotonic numbering or active dependencies.
- The executor cannot map every original heading to a destination.
- The only way to reduce size is deleting unique project knowledge.

## Maintenance notes

New detailed examples should go into the narrowest existing reference. Keep the
core file stable and small; expand it only for unconditional constraints or new
routing decisions.

