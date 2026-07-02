---
name: task-lifecycle
description: This skill should be used when the user asks to classify risk, select a Prisma execution lane, sequence implementation work, or enforce pre-merge workflow.
---

# Task Lifecycle

## Role

Use this skill as the lightweight router for Prisma task execution.

- Own risk classification and Fast/Full lane selection.
- Sequence the work: scope, reuse scan, implementation, verification, review, integration, cleanup.
- Delegate concrete commands and deep domain rules to the owning skills.

## Scope Boundaries

- This skill owns macro flow only.
- Use `../quality-assurance/SKILL.md` for validation commands and escalation.
- Use `../git-workflow/SKILL.md` for Git operations.
- Use `../code-review/SKILL.md` for findings format; review includes the mandatory `../thermo-nuclear-code-quality-review/SKILL.md` pass.

## When to Use

Use this skill when a task needs risk classification, lane selection, implementation sequencing, or pre-merge workflow coordination.

## Risk Classification

Classify before implementation:

| Risk | Use when | Lane |
|---|---|---|
| Low | Docs/comments only, localization updates, constrained non-functional refactor in one module | Fast |
| Medium | Feature/bugfix in one subsystem, UI state behavior, public API change in one package | Full |
| High | Audio, concurrency, persistence, security, cross-module architecture, build/release infra, large or broad deltas | Full |

When uncertain, choose the higher risk. High triggers override Medium.

## Lifecycle

1. Identify scope and likely owner skills.
2. Scan for reusable services, helpers, components, and patterns: `reuse -> extend -> create`.
3. Clarify material ambiguity; state minor assumptions.
4. Use `git-workflow` for branch/commit mechanics when the task needs a branch.
5. Implement in small slices.
6. Use `quality-assurance` for targeted checks, narrow builds, scope checks, and lane gates.
7. Before push/merge, use `code-review`; Full lane requires semaforo review plus the mandatory thermo structural pass.
8. Fix Critical/Medium review findings, re-run required gates, then integrate and clean up.

## Lane Gates

- Fast lane merge gate: `make scope-check`
- Full lane merge gate: `make build-test` + `make lint`
- `make preflight` is optional and does not replace the lane gate.

## Evidence To Report

Always report:

- risk level and lane,
- reusable-block decision,
- commands run and result,
- escalation rationale, if any,
- known baseline failures, if any.

## Related Skills

- `../quality-assurance/SKILL.md`
- `../git-workflow/SKILL.md`
- `../code-review/SKILL.md`
- `../thermo-nuclear-code-quality-review/SKILL.md`
