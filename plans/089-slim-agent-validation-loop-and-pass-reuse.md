# Plan 089: Slim the agent validation loop and align clean-tree PASS reuse

> **Executor instructions**: This plan is implemented in the same session that
> authored it. Prefer the live diff over re-deriving steps.
>
> **Drift check**: `git diff --stat cf494578..HEAD -- scripts/validate-agent.sh scripts/tests/workflow-test.sh AGENTS.md .agents/skills/delivery-workflow .agents/docs/build-and-test.md plans/README.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/087-fix-pre-push-reliability-and-agent-ops-followups.md
- **Category**: dx
- **Planned at**: commit `cf494578`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full` (touches `scripts/validate-agent.sh` + workflow fixtures)
- **Parallelizable**: `no`
- **Reviewer required**: `yes`
- **Rationale**: Fingerprint semantics affect pre-push reuse; guidance changes agent default cost.
- **Escalate when**: reuse across modes becomes fail-open for dirty trees.

## Why this matters

Plan 087 fixed Rust staging, false Package.resolved mismatch, in-place committed
validation, archive large-delta noise, and macos ref prune. Agents still stacked
dry-run + staged + Full + pre-push because guidance recommended those steps, and
a clean working-tree PASS still salted `workingState` into the fingerprint so
pre-push could not reuse it.

## Scope

- `scripts/validate-agent.sh` — omit `workingState` when the working tree is clean
- `scripts/tests/workflow-test.sh` — clean WT → committed reuse fixture
- `AGENTS.md`, `delivery-workflow` skill + details, `build-and-test.md` — lean loop
- `plans/README.md`

## Done criteria

- [x] Clean working-tree PASS with `--base` is reused by matching `--committed`
- [x] Guidance defaults to check → commit → push; dry-run/staged/Full not stacked
- [x] Guidance-only path prefers `guidance-check`
- [x] `make workflow-test` and `make guidance-check` PASS
- [x] Full validate when scripts changed (`make validate-agent ARGS="--lane full --no-reuse --agent"` PASS)
