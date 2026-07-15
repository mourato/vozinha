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
| Medium | One-subsystem feature/bugfix, one-package API, UI state logic | Full |
| High | Audio, concurrency, persistence, security, infrastructure, broad or large delta | Full |

When uncertain, choose the higher lane. During iteration use targeted tests,
`make build-agent`, and relevant scope checks. Final merge evidence is owned by
`make validate-agent`:

```bash
make validate-agent ARGS="--lane auto"
make validate-agent ARGS="--lane auto --dry-run --base main"
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Auto selects the lane before expensive work. Full executes strict lint then
build-test once. `make preflight` and `make deliverable-gate` remain explicit
release/high-confidence flows, not duplicate mandatory merge gates.

## Agent validation loop

1. Prefer `make validate-agent ARGS="--lane auto --dry-run --base main"` **at most once** when the gate choice is unclear.
2. During iteration, run only the smallest changed-path check (`make build-agent`, focused tests, `make preview-check`, `make guidance-check`, etc.). Do **not** run Full `build-test` on every slice.
3. Before commit, run **one** `make validate-agent ARGS="--lane auto --staged --base main --agent"` when evidence is needed; otherwise rely on the staged pre-commit lint/format hook for Swift formatting.
4. Do **not** re-run the Full merge gate solely because a push is coming — the pre-push hook runs `validate-agent --committed` on the exact range and reuses compatible PASS fingerprints.
5. `make scope-check` / `scope-check-agent` are the **engine/preview** used internally by `validate-agent` and for ad-hoc changed-path mapping. Agents should treat `validate-agent` as the remembered command; do not run both "for safety".
6. `SKIP_LINT=1` / `SKIP_TESTS=1` remain emergency bypasses only.

## Delegation and effort policy

- Keep simple, serial, and bounded work in the root session. Delegate only broad work with independently verifiable tracks.
- Start with one read-only explorer when delegation is justified; add children only for distinct questions, and keep at most one writing child in an isolated worktree.
- **Default to `implementer-fast`** when all hold: Low risk / Fast lane, deterministic fully specified work, isolated git worktree, and scope matches the allowlist below. Otherwise use the normal implementer.
- **Fast allowlist** (plan 060 measured candidate): docs/comments-only edits; localization key add/remove/symmetry with no behavior change; guidance-only `.agents` / `AGENTS.md` edits; constrained single-module non-functional refactor with an explicit file list.
- **Refuse / escalate to normal implementer** for Medium/High risk, ambiguous acceptance criteria, public API or behavior changes, exploratory design, multi-skill invention, or plans/users marked Full.
- **Lean-code remains opt-in and is not a default** (plan 060).
- Model identifiers and global effort defaults belong to Codex config or custom agent files, not this skill.

## Evidence contract

Every handoff, commit, or PR reports risk/lane, `reuse -> extend -> create`,
files/subsystem, commands/results, escalation rationale, baseline failures,
and review outcome. A dry-run is planning evidence only. Reuse is valid only
for an exact fingerprinted PASS; use `--no-reuse` after flaky/inconclusive
behavior. Agent artifacts are immutable run trees with metadata only.

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
