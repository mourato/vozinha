# Plan 060: Evaluate a lean code profile and a Fast-lane implementer before enabling either

> **Executor instructions**: This is a controlled global experiment, not a
> blanket configuration reduction. Execute after Plans 058 and 059. Change one
> variable at a time, preserve rollback copies, and enable a candidate only if
> quality acceptance remains non-inferior. Do not uninstall plugins.
>
> **Global drift check (run first)**: `shasum -a 256 /Users/usuario/.codex/config.toml /Users/usuario/.codex/agents/implementer.toml /Users/usuario/.codex/{fast,deep,research,design}.config.toml`
> Reconcile any mismatch before testing.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/058-build-global-agent-efficiency-evaluator.md, plans/059-tune-global-agent-routing.md
- **Category**: perf / dx
- **Planned at**: Prisma commit `58ca8a84`, 2026-07-12; global files are not currently in a Git worktree

## Why this matters

The base configuration globally enables artifact, site, visualization, and
browser plugins even during Swift/code-only work, while the standard implementer
always uses one medium-effort configuration. A lean profile may reduce recurring
tool/skill context, and a low-effort Fast implementer may reduce latency for
one-file mechanical changes. Both benefits are plausible but unproven because
plugin loading can be deferred and cheaper execution can create rework. This
plan measures each candidate independently and rejects it unless the saving is
real.

## Current state

- `/Users/usuario/.codex/config.toml:110-132` globally enables documents,
  spreadsheets, presentations, PDF, template creator, sites, visualize, and
  browser plugins.
- Base DeepWiki, grep.app, Figma, and computer-use MCPs are disabled; research
  and design profiles/agents opt into their relevant MCPs. Preserve this good
  least-surface pattern.
- `/Users/usuario/.codex/agents/implementer.toml:3-5` uses one model at medium
  effort with workspace-write and requires an explicitly isolated worktree.
- `/Users/usuario/.codex/fast.config.toml` uses low effort and disables
  multi-agent, but it is a session profile rather than a writing role.
- Official Codex/OpenAI guidance supports lower effort for latency-sensitive
  work, but requires representative evaluations before trading quality for cost:
  https://developers.openai.com/api/docs/guides/reasoning#reasoning-effort

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Plugin baseline | `codex plugin list` | installed/enabled state captured without mutation |
| MCP baseline | `codex mcp list` | resolved base/profile servers captured |
| Config health | `codex doctor --summary` | configuration healthy |
| Controlled eval | Plan 058 evaluator, same tasks and three repetitions | acceptance/cost/latency attributed |
| Worktree guard | run Fast implementer probe in disposable worktree | refuses non-worktree; writes only inside worktree |

## Suggested executor toolkit

- Use `agent-efficiency-eval` for comparison.
- Use `agent-ops` for routing boundaries.
- Use `plugin-creator` only if profile-level plugin enablement cannot express a
  reusable lean surface; do not create a plugin merely to toggle plugins.

## Scope

**In scope**:

- A new `/Users/usuario/.codex/lean.config.toml` profile if supported and measured
- `/Users/usuario/.codex/config.toml` plugin enablement only after evidence
- `/Users/usuario/.codex/agents/implementer-fast.toml` only after its experiment passes
- `/Users/usuario/.codex/agents/README.md`
- Privacy-safe evaluator manifests/reports
- `plans/README.md` status only

**Out of scope**:

- Uninstalling plugins, changing research/design MCP access, weakening sandbox
  or isolated-worktree enforcement, using Fast implementer for Medium/High risk,
  or changing multiple model/effort/tool variables in one comparison.
- Treating startup/tool-count reduction as success if task acceptance regresses.

## Execution workflow

- One dedicated global configuration task and one writer.
- Preserve exact baseline and rollback copies.
- Run experiments sequentially: lean surface first, Fast implementer second.

## Steps

### Step 1: Measure the current base tool surface

Capture resolved plugin/MCP/tool/skill metadata counts and startup latency for
code-only tasks without reading private app data. Run the six-task manifest with
the current base profile.

**Verify**: baseline report includes acceptance, API-equivalent cost, wall time,
input-token/cache breakdown, and tool-surface metadata.

### Step 2: Create a reversible lean code profile

Create `lean.config.toml` that disables only artifact/site/visual/browser plugins
irrelevant to code-only tasks. Keep them installed. Do not alter research/design
profiles or global defaults yet.

Run the same code-only tasks with only the profile changed. If profile layering
cannot override plugin enablement safely, stop; do not edit plugin manifests.

Promote lean enablement to the code-task default only when:

- acceptance/rework is non-inferior;
- required skills/tools remain discoverable for code tasks;
- median input tokens or startup/wall time improves by at least 10%;
- artifact/browser tasks still work under their explicit profile or normal
  enabled configuration.

Otherwise retain it as an optional/rejected experiment and record why.

**Verify**: code tasks and one artifact/browser smoke task select the intended
surfaces without reinstalling anything.

### Step 3: Test a Fast-lane implementer with one variable changed

Create an experimental `implementer-fast.toml` by copying the current
implementer's safety and worktree instructions exactly. First change only
reasoning effort from medium to low; keep the model constant so the result is
attributable. Test only Low/Fast tasks: docs/comments, localization, or one-file
mechanical refactors with deterministic acceptance.

Require:

- 100% acceptance across the chosen Fast fixtures;
- no increase in rework or scope violations;
- isolated-worktree refusal still works;
- at least 10% median cost or latency improvement.

Only after that isolated effort test may a second model experiment be proposed.
Do not silently route Medium/High tasks to this role.

**Verify**: a non-worktree probe is blocked; three repetitions of each Fast task
pass; one ambiguity fixture escalates to the normal implementer rather than
guessing.

### Step 4: Update routing only for successful candidates

If the lean profile passes, document how code tasks select it and how artifact,
research, and design tasks opt into their surfaces. If Fast implementer passes,
register it in `agents/README.md` and `agent-ops` routing without putting model
IDs in the skill.

If either fails, delete/disable the candidate and record a REJECTED result in the
evaluation report. A failed experiment is a valid completion outcome.

**Verify**: `codex doctor --summary`, `codex plugin list`, `codex mcp list`, and
the controlled report agree with the final enabled state.

## Test plan

- Baseline vs lean profile, same model/effort/tasks.
- Current implementer medium vs experimental low, same model/tasks.
- Three repetitions per task.
- Negative tests: artifact/browser task under lean route, non-worktree write,
  ambiguous Fast task, and Medium/High task routing.

## Done criteria

- [ ] Plugin/tool baseline is measured before changes.
- [ ] Lean profile changes only plugin/tool surface and remains reversible.
- [ ] Fast implementer first changes only reasoning effort.
- [ ] Both experiments use equal tasks/repetitions and quality acceptance.
- [ ] No plugin is uninstalled.
- [ ] Research/design surfaces and isolated-worktree enforcement remain intact.
- [ ] Only candidates meeting non-inferiority plus the 10% improvement threshold are enabled.
- [ ] Failed candidates are explicitly rejected rather than left half-enabled.
- [ ] `codex doctor --summary` remains healthy.
- [ ] `plans/README.md` marks plan 060 `DONE` or records the measured rejected outcome.

## STOP conditions

- Plugin loading/tool attribution cannot be measured separately from model changes.
- Profile layering cannot disable plugins without editing installed manifests.
- Fast implementer writes outside an isolated worktree or handles ambiguous scope by guessing.
- Any candidate regresses acceptance, rework, privacy, or required tool availability.
- Global writes lack an approved staged/rollback workflow.

## Maintenance notes

Keep optional surfaces installed and select them by task. Re-evaluate after major
Codex/plugin/model releases because lazy loading and context costs can change.

