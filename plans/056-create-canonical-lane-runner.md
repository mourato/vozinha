# Plan 056: Provide one canonical lane runner with safe evidence reuse

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 58ca8a84..HEAD -- Makefile AGENTS.md scripts/validate-agent.sh scripts/scope-check.sh scripts/lib/agent-output.sh scripts/hooks/pre-push scripts/tests .agents/docs/build-and-test.md .agents/skills/delivery-workflow/SKILL.md plans/README.md`
> This plan depends on Plan 055. If Plan 055 is not DONE or its current excerpts
> no longer match, stop and reconcile before implementing this plan.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Lane**: Full — this changes build/test infrastructure and merge evidence
- **Depends on**: plans/055-harden-scoped-validation-artifacts.md
- **Category**: perf / dx / tests
- **Planned at**: commit `58ca8a84`, 2026-07-12

## Why this matters

Prisma's policy is clear about Fast and Full lanes, but evidence is currently
assembled from several overlapping commands. A conservative agent can run
staged lint, scope-check lint, build-test, strict lint, preflight, and
deliverable-gate in one delivery cycle. A single lane runner will execute the
required policy once, emit one aggregate result, and reuse a prior PASS only
when the source state, configuration, toolchain, base ref, lane, and command
implementation are identical.

## Current state

- `AGENTS.md:78-90` defines:
  - Fast: `make scope-check`.
  - Full: `make lint-strict` plus `make build-test`.
- `scripts/scope-check.sh:440-460` always runs ordinary lint and may then run
  `make build-test`.
- `scripts/hooks/pre-push:18-22` invokes scope-check again.
- `.agents/docs/build-and-test.md:265-295` separately recommends mandatory lane
  gates, optional preflight, deliverable-gate, and release workflows.
- `Makefile:177-206` exposes scope-check, lint, and strict-lint targets, but no
  command owns a complete `fast|full|auto` contract or a reusable evidence
  fingerprint.
- Plan 055 establishes immutable per-run artifacts and deterministic workflow
  fixtures. Reuse those blocks; do not introduce a second logging system.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Workflow tests | `make workflow-test` | exit 0 |
| Fast preview | `make validate-agent ARGS="--lane fast --base main --dry-run"` | prints only the Fast command graph and exits 0 |
| Full preview | `make validate-agent ARGS="--lane full --base main --dry-run"` | prints strict lint then build-test and exits 0 |
| Auto preview | `make validate-agent ARGS="--lane auto --base main --dry-run"` | prints selected lane plus reasons |
| Guidance | `make guidance-check` | exit 0 |
| Full gate | `make lint-strict-agent && make build-test` | pass or unrelated baseline classified |
| Diff hygiene | `git diff --check` | exit 0 |

## Suggested executor toolkit

- Use `delivery-workflow` as the policy authority.
- Use `thermo-nuclear-code-quality-review` before handoff.
- Do not invent a generic build cache; this plan caches validation evidence,
  not compiler artifacts.

## Scope

**In scope**:

- `scripts/validate-agent.sh` (create)
- `Makefile`
- `scripts/scope-check.sh` only for a machine-readable decision interface
- `scripts/lib/agent-output.sh` only to extend the established result schema
- `scripts/hooks/pre-push`
- `scripts/tests/`
- `AGENTS.md`
- `.agents/docs/build-and-test.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `plans/README.md`

**Out of scope**:

- Compiler/build artifact caching, remote cache services, CI redesign, release
  signing, changing Fast/Full risk triggers, or replacing targeted tests.
- Reusing a PASS when the working tree is dirty in a different way, an untracked
  file changed, toolchain/config changed, or a prior result lacks the expected
  schema/fingerprint.
- Treating dry-run output as validation evidence.

## Git workflow

- Branch: `feat/056-canonical-lane-runner`
- Suggested commits:
  1. `feat(workflow): add canonical lane validation runner`
  2. `test(workflow): verify validation fingerprints and reuse`
  3. `docs(workflow): make lane runner the command authority`
- Do not push or open a PR unless instructed.

## Steps

### Step 1: Define the runner contract

Create `scripts/validate-agent.sh` with:

- `--lane fast|full|auto` (required; defaulting is allowed only if documented);
- `--base REF`;
- `--dry-run`;
- `--no-reuse`;
- `--agent` compact output.

Required command graphs:

- Fast: the corrected scoped validation from Plan 055.
- Full: `make lint-strict-agent`, then `make build-test`.
- Auto: ask scope-check for a machine-readable lane decision; if any Full
  trigger exists, run Full, otherwise run Fast. Do not run the Fast command graph
  and then start Full after expensive work has already executed.

The aggregate result must state selected lane, reasons, commands, durations,
individual result paths, and overall status.

**Verify**: the three dry-run commands show mutually correct command graphs and
do not create a PASS result.

### Step 2: Add a content-addressed evidence fingerprint

Compute a deterministic fingerprint before running. It must include:

- requested/effective lane and base ref commit;
- `HEAD` and a content representation of staged, unstaged, and untracked inputs;
- hashes of `Makefile`, validation scripts, mapping config, lint/format config,
  `Package.swift`, project configuration, and other files that determine the gate;
- relevant toolchain identities (`swift --version`, Xcode version, SwiftLint and
  SwiftFormat versions when used);
- runner/result schema version.

Store successful aggregate evidence in the immutable run tree established by
Plan 055 and a content-addressed lookup index. Reuse only `PASS`; never reuse
WARN/FAIL/incomplete. Validate that every referenced child result still exists
and matches the fingerprint. `--no-reuse` must force execution.

**Verify**: an unchanged fixture run reuses the prior PASS; changing source,
untracked content, a config hash, base ref, lane, or toolchain fixture forces a
new run.

### Step 3: Make the runner the delivery authority

Add `make validate-agent` and update pre-push to call the auto lane in compact
mode. Synchronize `AGENTS.md`, delivery skill, and build/test reference so:

- iteration still uses targeted checks directly;
- final Fast/Full evidence uses `validate-agent`;
- preflight and deliverable-gate remain explicit release/high-confidence flows,
  not extra mandatory merge gates;
- a cache hit is valid evidence only when the fingerprint is printed in the
  handoff;
- `--no-reuse` is required after flaky/inconclusive behavior.

Remove contradictory examples that tell agents to run several equivalent final
gates. Keep Makefile as command authority.

**Verify**: guidance search yields one canonical merge command and clearly
separate release commands; `make guidance-check` passes.

### Step 4: Test fail-closed behavior and review

Extend workflow fixtures to cover missing/corrupt result JSON, missing child
logs, changed toolchain/config, FAIL/WARN evidence, dirty/untracked changes,
explicit no-reuse, and dry-run. All uncertainty must execute a fresh gate rather
than return a cache hit.

Run the Full lane directly once after implementation, because the new runner
cannot validate itself solely through cached evidence. Complete thermo review
and fix Critical/Medium findings.

**Verify**: `make workflow-test`, `make guidance-check`, `git diff --check`,
`make lint-strict-agent`, and `make build-test` satisfy expected results.

## Test plan

- Extend Plan 055's disposable fixture suite; do not create a second framework.
- Test each lane and each invalidation input.
- Test that dry-run never writes PASS evidence.
- Test that corrupt or partial evidence fails closed.
- Run one real uncached Full gate with `--no-reuse` before handoff.

## Done criteria

- [ ] One command owns Fast, Full, and auto final validation.
- [ ] Auto selects the lane before executing expensive commands.
- [ ] Full runs strict lint and build-test exactly once each.
- [ ] PASS reuse requires an exact content/config/toolchain/schema fingerprint.
- [ ] FAIL, WARN, missing, corrupt, or mismatched evidence is never reused.
- [ ] Dry-run is never recorded as proof.
- [ ] Pre-push uses the compact auto runner.
- [ ] Guidance distinguishes merge evidence from release/high-confidence gates.
- [ ] Workflow tests and one uncached Full gate pass.
- [ ] Thermo review has no unresolved Critical/Medium findings.
- [ ] `plans/README.md` marks plan 056 `DONE`.

## STOP conditions

- A fingerprint cannot represent untracked contents without persisting source
  content in the result artifact.
- Reuse would rely only on timestamps, branch names, or `HEAD`.
- Auto lane selection requires running the expensive Fast graph first.
- A cache hit could hide a flaky or explicitly inconclusive prior run.
- The change would weaken Full-lane or release validation.

## Maintenance notes

Any new merge gate must become a fingerprint input and an aggregate child
command. Bump the schema version whenever fingerprint semantics change; old
evidence must then fail closed.

