---
name: delivery-workflow
description: Use for Prisma risk classification, Fast/Full lane selection, validation commands, sequencing, Git delivery, review gates, and evidence reporting.
---

# Delivery Workflow

## Role

Own Prisma delivery from risk classification through validation, review,
commit, integration, and evidence handoff.

## Scope Boundary

Use this skill for workflow and gate decisions. Use `testing-xctest` for test
structure, `thermo-nuclear-code-quality-review` for review findings, and the
named subsystem skill for implementation-specific rules.

## When to Use

Trigger for risk classification, lane selection, validation sequencing, Git
delivery, review gates, or evidence reporting.

## Risk and lanes

| Risk | Triggers | Lane |
|---|---|---|
| Low | Docs/comments, localization, constrained non-functional refactor | Fast |
| Medium | One-subsystem feature/bug fix, one-package API, UI state logic | Full |
| High | Audio, concurrency, persistence, security, cross-module architecture, build/release infrastructure, 300+ added lines, or more than 8 production source files | Full |

Automatic committed-range classification is conservative: production Swift is Full because scripts cannot prove a semantic Low/non-functional change.

When uncertain, choose the higher lane. During iteration use targeted tests,
`make build-agent`, and the smallest changed-path check. Final technical
evidence is owned by end-of-task `make validate-agent` during development — not
by pre-push:

```bash
make validate-agent ARGS="--lane auto --base main --agent"
make validate-agent ARGS="--lane auto --committed --base main --head HEAD --agent"
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Auto selects the lane before expensive work. Full executes strict lint then
build-test once. Pre-push does **not** run build or test validation; it only
acknowledges the push range. `make preflight` and `make deliverable-gate`
remain explicit release/high-confidence flows, not duplicate technical gates.
Validation evidence proves checks only; required review remains separate.

## Agent validation loop

| Phase | Required when | Action |
|---|---|---|
| During task | Behavior/Swift changed | Targeted unit tests for the slice |
| End of task/plan | Any `.swift` touched | Fail-closed lint on the delta (`make lint-strict-agent` or equivalent scoped strict check) |
| End of task/plan | Behavior changed | `make validate-agent ARGS="--lane auto --base main --agent"` on a clean tree (or `--committed` after commit) — Fast scoped path, not optional |
| Escalate to Full | Auto/Full triggers | `make validate-agent ARGS="--lane full ..."` during development before push |
| Guidance-only | No Swift / no scripts | `make guidance-check` during development |

Vocabulary:

- **Targeted tests** = per-file/`--test` during the slice
- **Auto Fast** = scoped test-only, guidance, localization, or non-code validation
- **Full suite** = Full lane `build-test` (Xcode), not merely `make test-full`

Default for Low/Fast (including guidance-only and allowlisted `implementer-fast`):

1. During iteration, run only the smallest changed-path check (`make guidance-check`,
   focused tests, `make build-agent`, `make preview-check`, etc.). Do **not** run
   Full `build-test`, dry-run, or staged validate on every slice.
2. End of task: run strict lint when Swift changed; run affected-module
   `validate-agent --lane auto` when behavior changed (escalate to Full when
   required).
3. Commit. Pre-commit applies staged SwiftFormat/SwiftLint autofix and re-stages.
4. Push. Pre-push does not re-run build/test; development already owns that
   evidence.

Use a heavier local gate only when needed:

- **Lane unclear (Medium/High or mixed files):** at most one
  `make validate-agent ARGS="--lane auto --dry-run --base main"`.
- **Need Full / infra evidence:** one
  `make validate-agent ARGS="--lane auto --base main --agent"` on a **clean**
  tree (or `--committed --base <base> --head HEAD`) before push — do not also
  stack staged + working-tree Full runs.
- **Guidance-only** (`.agents` / `AGENTS.md` / docs, no `scripts/` or product
  Swift): use `make guidance-check` during iteration; do not expect pre-push
  to record product tests.
- `make scope-check` is an internal engine — do not run it “for safety” alongside
  `validate-agent`.
- `SKIP_LINT=1` / `SKIP_TESTS=1` / `MA_RUST_AUDIO_KERNELS_BUILD=off` are emergency
  bypasses only (`SKIP_TESTS` no longer affects pre-push because pre-push does
  not run tests).

## Agent execution constraints

- **Low/Fast eligibility** requires deterministic, fully specified scope.
- **Fast eligibility allowlist**: docs/comments-only edits; localization key
  add/remove/symmetry with no behavior change; guidance-only `.agents` /
  `AGENTS.md` edits; constrained single-module non-functional refactors with an
  explicit file list.
- Medium/High risk, ambiguity, public API or behavior changes, exploratory
  design, multi-skill invention, and plans/users marked Full are not
  Fast-eligible.
- Every writer must use an explicitly isolated worktree, with at most one
  writer active.
- Global `agent-ops` consumes these facts and owns root-vs-child delegation and
  custom-agent profile selection.
- Model identifiers, reasoning effort, sandbox, and MCP configuration belong
  to custom agent files or global config, not project skills.

## Evidence contract

Every handoff, commit, or PR reports risk/lane, `reuse -> extend -> create`,
files/subsystem, commands/results, escalation rationale, baseline failures,
and review outcome. A dry-run is planning evidence only. Reuse is valid only
for an exact fingerprinted PASS; use `--no-reuse` after flaky/inconclusive
behavior. Technical PASS is not merge approval. Agent artifacts are immutable
run trees with metadata only.

## Delivery rules

- Preserve unrelated worktree changes and use Conventional Commits.
- Keep commits atomic; do not commit knowingly broken code.
- Full-lane Critical/Medium review findings block merge.
- Do not weaken risk thresholds, privacy rules, isolated worktree policy, or
  release gates to make a check pass.
- Run `make workflow-test` when validation infrastructure changes and
  `make guidance-check` when guidance changes.

## Routed references

Read [delivery details](references/delivery-workflow-details.md) only for the
task-specific material below:

| Request | Reference sections |
|---|---|
| Git branches, commits, PRs, and merge examples | Git workflow |
| Command catalog and scoped-check mechanics | Scoped validation and practical commands |
| Troubleshooting, hooks, and artifact details | Hook/troubleshooting and compact-mode notes |
| Release/high-confidence flows | Preflight and deliverable-gate guidance |

## Related Skills

- Global `thermo-nuclear-code-quality-review`
- `../testing-xctest/SKILL.md`

## References

- [Detailed delivery guidance](references/delivery-workflow-details.md)
