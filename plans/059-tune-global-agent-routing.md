# Plan 059: Tune global routing and root reasoning from controlled cost-quality evidence

> **Executor instructions**: This plan changes global Codex policy under
> `/Users/usuario/.codex`. Execute only in a dedicated configuration task after
> Plan 058 is DONE. Run the full controlled matrix before changing defaults. If
> evidence is incomplete or quality regresses, keep the current default and
> record the rejected experiment.
>
> **Global drift check (run first)**:
> `shasum -a 256 /Users/usuario/.codex/AGENTS.md /Users/usuario/.codex/config.toml /Users/usuario/.codex/skills/agent-ops/SKILL.md /Users/usuario/.codex/{fast,deep,research,design}.config.toml /Users/usuario/.codex/agents/*.toml`
> Compare against the planned hashes in "Current state".

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/058-build-global-agent-efficiency-evaluator.md
- **Category**: dx
- **Planned at**: Prisma commit `58ca8a84`, 2026-07-12; global files are not currently in a Git worktree

## Why this matters

The global root session is intended to classify, route, and synthesize, yet it
defaults to high reasoning for every task. The controlled study also shows that
one routing strategy is not universally efficient: homogeneous orchestration
wins broad read/diagnose/plan work, while bounded diff review is cheaper and
faster with a single agent. Global policy should encode these workload-specific
decisions and change the root default only after medium vs high passes the same
quality bar.

## Current state

- `/Users/usuario/.codex/config.toml:2-3`:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
```

- `/Users/usuario/.codex/AGENTS.md` says the base session is an orchestrator,
  should use the lowest safe effort, automatically delegates broad independent
  work, and keeps only one writing implementation agent.
- `/Users/usuario/.codex/skills/agent-ops/SKILL.md:14-27` provides qualitative
  routing but no workload-specific measured thresholds or context/search budget.
- `/Users/usuario/.codex/config.toml:65-67` sets `max_threads = 4` and
  `max_depth = 1`; with root active, the runtime exposes at most three concurrent
  children. `/Users/usuario/.codex/agents/README.md:16` currently says "at most
  four concurrent children".
- `fast.config.toml` selects low effort with multi-agent disabled; `deep` selects
  high with multi-agent enabled; research/design select medium and task-specific
  MCPs. The four overlays repeat base-disabled MCP declarations.
- Plan 058 must first make the following study result quality/cost-attributed:
  - broad read/diagnose/plan: homogeneous orchestration was best in the initial sample;
  - bounded diff review: single agent was best;
  - small change: homogeneous was the best latency/token balance;
  - mixed orchestration did not establish an economic default.
- Planned hashes include:

```text
9bca8596acb18df240b7ac95cccb0c44a4a2a2daa8b325bc5c71597d8b3a441d  /Users/usuario/.codex/AGENTS.md
cd8d425d634a016480b92ab87b852cd53fb0f524f3fd2e44b50fd64c86a2ed5c  /Users/usuario/.codex/config.toml
f8ca4c7b3eafdc7073c17201301a8aa2e1a3e725bbb5bdc41d7f0ba020d3cded  /Users/usuario/.codex/skills/agent-ops/SKILL.md
9cc6ee38761ee2e40c61ccb04b2042894b63b3dd59a2f93f53e32ba30a8140dc  /Users/usuario/.codex/fast.config.toml
564f35723e064217ea637ecee8d8eb7a53064034410b0a816e4b92299a549290  /Users/usuario/.codex/deep.config.toml
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Config health | `codex doctor --summary` | configuration loads; unrelated TERM/sandbox notes classified |
| Profile smoke | run one no-op task with each `--profile fast|deep|research|design` | each profile resolves intended effort/MCP state |
| Controlled eval | invoke Plan 058's skill on root high vs medium and routing scenarios | equal task/repetition/acceptance coverage |
| Skill validation | run the skill-creator validator for `/Users/usuario/.codex/skills/agent-ops` if available | exit 0 |
| Privacy scan | `rg -n "prompt|transcript|secret|full logs" /Users/usuario/.codex/AGENTS.md /Users/usuario/.codex/skills/agent-ops/SKILL.md /Users/usuario/.codex/agents` | only prohibitions, no sensitive content |

## Suggested executor toolkit

- Use `agent-ops` as the workflow owner being refined.
- Use `agent-efficiency-eval` from Plan 058 for all decisions.
- Use `openai-docs` only to verify current supported model/effort settings.

## Scope

**In scope**:

- `/Users/usuario/.codex/AGENTS.md`
- `/Users/usuario/.codex/config.toml`
- `/Users/usuario/.codex/skills/agent-ops/SKILL.md`
- `/Users/usuario/.codex/agents/README.md`
- `/Users/usuario/.codex/{fast,deep,research,design}.config.toml`
- Existing custom agent TOML files only if measured role/effort corrections are required
- Privacy-safe Plan 058 reports
- `plans/README.md` status only

**Out of scope**:

- Plugin/tool enablement experiments and `implementer-fast` (Plan 060).
- Lowering strict reviewer reasoning or weakening repository Full/high-risk gates.
- Putting model identifiers in skills.
- Making mixed-model orchestration the default without a measured quality gain.
- Changing sandbox/trust policy; audit that separately as safety work.

## Execution workflow

- Use one dedicated global configuration writer and operator-approved rollback.
- Change one variable per controlled experiment.
- Do not modify Prisma source or repository skills in this global plan.

## Steps

### Step 1: Establish workload-specific routing budgets

Extend `agent-ops` without adding another general workflow skill. Encode:

- simple answer/search/explanation and bounded diff review: root-only or exactly
  one narrow reviewer; no parallel fan-out;
- broad read/diagnose/plan: two or three disjoint read-only children only when
  at least two workstreams can proceed independently and avoid duplicate reads;
- implementation: root-only planning when the path is already known, otherwise
  one explorer followed by one isolated implementer; reviewer required only by
  repository policy/risk or an explicit review request;
- small Fast-lane change: one writer; do not add research/review fan-out by default;
- unchanged failure: one retry, then pivot or report; no repeated identical calls;
- child handoff: findings/evidence/risks/next action only, no logs or file dumps.

Add an initial-context budget expressed as behavior, not a brittle universal
token number: start with targeted search and the smallest relevant files; expand
only when evidence is missing. Never prescribe reading an entire repo.

**Verify**: each of the six manifest tasks maps deterministically to root-only,
single specialist, or bounded homogeneous fan-out.

### Step 2: Compare root high vs medium

Using the same model, prompts, revision, worktrees, roles, and acceptance checks,
run at least three repetitions per task with root `high` and `medium`. Compare
per task class, not just aggregate totals.

Adopt medium as the global default only if:

- no task-class acceptance rate regresses;
- rework does not increase;
- required evidence remains complete;
- median API-equivalent cost or latency improves materially (target at least 10%
  in one without a material regression in the other).

Keep `deep` and strict reviewer high. If medium fails, preserve high and record
the experiment as rejected.

**Verify**: the evaluator produces a decision with attribution coverage and
confidence; config changes match that decision.

### Step 3: Align global wording and profiles

Update global guidance so the four-slot cap is described as root plus at most
three concurrent children. Keep `max_depth = 1`.

Remove redundant profile keys only after a real profile smoke test proves layer
inheritance. Fast must remain low + no multi-agent; deep high + multi-agent;
research/design retain their explicit MCP enables. Do not remove an explicit
disable if doing so changes the resolved surface.

Keep model IDs in custom agent/profile files, never in `agent-ops`.

**Verify**: all four profiles resolve as intended and `codex doctor --summary`
remains healthy.

### Step 4: Rerun the routing matrix

Compare the updated measured routing against the original single, mixed, and
homogeneous scenarios. Report per workload:

- acceptance and rework;
- total and cached/uncached tokens;
- API-equivalent cost with attribution coverage;
- wall-clock and summed-agent duration.

Do not claim a global winner when workload results disagree. Record explicit
route choices in `agent-ops` and the evaluator report.

**Verify**: every enabled routing rule is supported by the same task class in
the controlled report.

## Test plan

- Six task classes, at least three repetitions, same revision/worktree/prompt.
- Root high vs medium with all other variables fixed.
- Before/after routing with actual root/child model attribution.
- Negative cases: bounded diff must not fan out; serial task must not delegate;
  Full/high-risk repo policy still requires reviewer/gates where specified.

## Done criteria

- [ ] `agent-ops` has workload-specific delegation and context budgets.
- [ ] Bounded diff review no longer fans out by default.
- [ ] Broad homogeneous fan-out is limited to independent read-heavy work.
- [ ] Root medium/high decision is backed by controlled acceptance and cost evidence.
- [ ] Deep/reviewer quality settings remain protected.
- [ ] Four slots are documented as root plus at most three children.
- [ ] Profile boilerplate is removed only where inheritance is proven.
- [ ] Model identifiers remain outside skills.
- [ ] `codex doctor --summary` and profile smoke tests pass.
- [ ] `plans/README.md` marks plan 059 `DONE`.

## STOP conditions

- Plan 058 cannot attribute role/model usage or acceptance.
- Medium regresses acceptance, evidence completeness, or rework in any task class.
- Profile cleanup changes MCP/tool availability.
- A proposed rule conflicts with a repository's local AGENTS/skill policy.
- Global writes lack an approved staged/rollback workflow.

## Maintenance notes

Routing rules are empirical defaults, not permanent truths. Re-run the matrix
when models, Codex multi-agent behavior, or the task mix changes materially.

