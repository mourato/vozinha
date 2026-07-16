# Plan 104: Make `agent-ops` the single owner of delegation and profile selection

> **Executor instructions**: Execute after plans 102 and 103 are DONE. This is a
> deterministic guidance change, not a redesign of the agents. Read every
> in-scope document before editing, apply the ownership table below literally,
> and stop if the global `agent-ops` contract no longer matches the excerpt.
> Update this plan's row in `plans/README.md` when complete.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat fa93d031..HEAD -- \
>   AGENTS.md \
>   .agents/SKILLS_INDEX.md \
>   .agents/docs/skill-routing.md \
>   .agents/skills/delivery-workflow/SKILL.md \
>   .agents/skills/project-standards/SKILL.md \
>   plans/README.md
> ```
>
> Changes from plans 102/103 to delivery wording are expected. STOP only if
> ownership or routing semantics changed incompatibly.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: `plans/103-align-auto-lane-with-risk-policy.md`
- **Category**: tech-debt
- **Planned at**: commit `fa93d031`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `no` — all files describe one ownership contract
- **Reviewer required**: `yes` — contradictory routing must not survive in another wording
- **Rationale**: Guidance-only and deterministic, but it changes operational routing and should not rely on the disputed Fast default while fixing it.
- **Escalate when**: The change would modify global agent TOML/model settings, create/delete an agent, or alter product delivery gates.

## Why this matters

The global `agent-ops` skill says small deterministic work stays in the root and
`implementer-fast` is an explicit opt-in. Prisma's local guidance says
allowlisted Low/Fast work defaults to `implementer-fast`. The same task can
therefore be routed differently depending on which document the orchestrator
loads. This plan establishes one owner: `agent-ops` decides whether to delegate
and which custom profile to use; Prisma supplies only risk/lane eligibility and
repository-specific safety constraints.

## Current state

### Global owner already exists

`/Users/usuario/.codex/skills/agent-ops/SKILL.md:14-28,41-47` defines:

```text
- root-only for simple search, explanation, bounded review, and small deterministic work
- delegate only broad independently parallelizable work
- choose the narrowest custom agent by role
- implementer-fast is explicit opt-in for deterministic Low/Fast work
- project AGENTS policy takes precedence
```

Do not edit this global skill in this plan. It is the target ownership contract.

### Local documents reopen the decision

- `AGENTS.md:65` says allowlisted Low/Fast work defaults to `implementer-fast`.
- `.agents/skills/delivery-workflow/SKILL.md:92-100` contains a second delegation
  policy and makes the Fast agent default.
- `.agents/docs/skill-routing.md:24-37` contains another root/delegation/profile table.
- `.agents/SKILLS_INDEX.md` lists global `improve` and review skills but does not
  list `agent-ops`, even though project guidance relies on it.

## Target ownership contract

| Decision | Canonical owner | Prisma's allowed contribution |
|---|---|---|
| Root vs child delegation | global `agent-ops` | one-writer and isolated-worktree hard constraints |
| Explorer/diagnostician/implementer/reviewer selection | global `agent-ops` | specialist skill name and project risk facts |
| `implementer-fast` opt-in/profile choice | global `agent-ops` | whether scope qualifies as deterministic Low/Fast |
| Risk and Fast/Full lane | project `delivery-workflow` | full ownership |
| Validation commands and evidence | project `delivery-workflow` | full ownership |
| Domain implementation rules | named project skill | full ownership inside its boundary |
| Model, reasoning effort, sandbox, MCPs | custom agent/global config | no project-skill duplication |

The project may say a task is **eligible** for Fast. It must not say that an
eligible task is automatically delegated or select a profile by default.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Guidance validation | `make guidance-check` | `Guidance validation passed.` |
| Stale-default search | `rg -n "defaults? to .*implementer-fast|Default to .*implementer-fast|allowlisted .* defaults" AGENTS.md .agents` | no matches |
| Owner presence | `rg -n "agent-ops" AGENTS.md .agents/SKILLS_INDEX.md .agents/docs/skill-routing.md .agents/skills/{delivery-workflow,project-standards}/SKILL.md` | each named surface has an intentional pointer |
| Model leakage | `rg -n "gpt-[0-9]|model_reasoning_effort" AGENTS.md .agents` | no matches |
| Diff hygiene | `git diff --check` | no output |

## Suggested executor toolkit

- Use global `agent-ops` as the owner being referenced.
- Use `project-standards` for local guidance governance.
- Use `delivery-workflow` only to preserve risk/lane/validation content.

## Scope

**In scope**:

- `AGENTS.md`
- `.agents/SKILLS_INDEX.md`
- `.agents/docs/skill-routing.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/project-standards/SKILL.md`
- `plans/README.md`

**Out of scope**:

- `/Users/usuario/.codex/skills/agent-ops/SKILL.md`
- `/Users/usuario/.codex/agents/*.toml` and their model/reasoning settings
- Adding, removing, or renaming custom agents
- Risk matrix, validation commands, hook behavior, or script changes
- Domain skill boundaries unrelated to delegation
- Changing the one-writer or isolated-worktree rule

## Git workflow

- Work in an explicitly isolated worktree.
- Suggested branch: `docs/104-centralize-agent-routing`
- Suggested commit: `docs(agents): centralize routing ownership in agent-ops`
- Do not push or open a PR unless requested.

## Steps

### Step 1: Make `AGENTS.md` a constraint layer, not a second router

Replace the current Delegation paragraph with a compact contract:

```text
Global agent-ops owns root-vs-child delegation and custom-agent profile
selection. Prisma supplies risk/lane facts and requires at most one writing
agent in an explicitly isolated worktree. Simple/serial work remains eligible
for root execution; broad independent work may be delegated by agent-ops.
```

Keep the requirement that every implementation plan has an Execution profile
and is reclassified before execution. Remove the sentence that makes
`implementer-fast` a local default.

**Verify**: the stale-default `rg` command returns no matches in `AGENTS.md`.

### Step 2: Reduce `delivery-workflow` to eligibility and delivery facts

Rename `## Delegation and effort policy` to something like
`## Agent execution constraints` and retain only project-owned facts:

- Low/Fast eligibility requires deterministic, fully specified scope.
- The existing allowlist remains a qualification list, not a routing default.
- Medium/High, ambiguous, public-API, behavioral, exploratory, or multi-skill
  work is not Fast-eligible.
- Every writer must use an isolated worktree; one writer maximum.
- `agent-ops` selects root/child/profile after consuming these facts.
- Model identifiers stay outside project skills.

Delete root-vs-child recipes and “Default to implementer-fast”. Do not change
the lane matrix or validation ladder from plans 102/103.

**Verify**: `rg -n "Default to|root session|Start with one" .agents/skills/delivery-workflow/SKILL.md`
returns no routing recipe; necessary scope words elsewhere must be reviewed manually.

### Step 3: Turn `skill-routing.md` into a domain router

Replace the detailed Workflow Routing table with a short pointer:

- `agent-ops` owns orchestration and custom-agent selection;
- `delivery-workflow` owns Prisma risk/lane and validation;
- this document maps problem domains to project skills.

Keep the problem-specific routing sections. Do not repeat explorer,
implementer, reviewer, or `implementer-fast` recipes.

**Verify**:

```bash
rg -n "explorer|implementer-fast|Root session plus|Root plan plus" \
  .agents/docs/skill-routing.md
```

Expected: no matches in workflow recipes; domain examples that genuinely need
a specialist must not name a custom execution profile.

### Step 4: Register the global owner and document the split

Add `agent-ops` to `.agents/SKILLS_INDEX.md` as a global skill with trigger text
limited to workflow, routing, delegation, planning, effort, and validation
strategy. Do not duplicate its workflow.

In `project-standards`, extend the ownership split with one sentence:

```text
agent-ops owns orchestration/profile selection; delivery-workflow owns Prisma
risk, lanes, commands, and evidence; domain skills own implementation rules.
```

Remove or correct the stale `single-checkout feature-branch workflow defined in
AGENTS.md` statement. The valid hard rule is one writer in an isolated
worktree; the root checkout policy is not defined there.

**Verify**: owner-presence `rg` returns intentional references in all five surfaces.

### Step 5: Validate and inspect the final diff

```bash
make guidance-check
rg -n "defaults? to .*implementer-fast|Default to .*implementer-fast|allowlisted .* defaults" AGENTS.md .agents
rg -n "gpt-[0-9]|model_reasoning_effort" AGENTS.md .agents
git diff --check
git diff --stat
```

Expected:

- guidance passes;
- both negative `rg` commands return no matches;
- only six in-scope paths plus `plans/README.md` changed;
- no scripts or product files changed.

## Test plan

This is guidance-only. The test is structural and semantic:

- `make guidance-check` validates catalog, paths, and skill structure.
- Negative searches prove the local Fast default and model leakage are gone.
- Positive search proves `agent-ops` is discoverable from every routing surface.
- Reviewer reads the five changed guidance excerpts together and confirms the
  ownership table has exactly one owner per decision.

## Done criteria

- [ ] `agent-ops` is the sole owner of delegation and profile selection.
- [ ] Prisma guidance contains no automatic `implementer-fast` default.
- [ ] The Fast allowlist is eligibility data only.
- [ ] `delivery-workflow` still owns risk, lane, commands, and evidence.
- [ ] One-writer and isolated-worktree constraints remain explicit.
- [ ] `agent-ops` is indexed as a global skill.
- [ ] Stale single-checkout wording is removed or corrected.
- [ ] `make guidance-check` and `git diff --check` pass.
- [ ] No global config, scripts, or product files changed.
- [ ] Ledger row is updated.

## STOP conditions

Stop and report if:

- Global `agent-ops` no longer says `implementer-fast` is explicit opt-in.
- Resolving the conflict requires changing model IDs, agent TOMLs, or global config.
- Plans 102/103 left unresolved delivery wording that would be deleted by this plan.
- A project-specific safety constraint has no owner after the proposed deletion.
- `make guidance-check` fails twice after correcting local references.

## Maintenance notes

- Future project skills may state eligibility and constraints, but must not
  choose an agent profile.
- Future custom agents must be added to global config/agent files first, then
  referenced locally only when Prisma has a real constraint to add.
- Reviewers should reject new routing tables that duplicate `agent-ops` recipes.
