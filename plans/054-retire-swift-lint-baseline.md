# Plan 054: Retire the repository-wide Swift lint baseline and enable strict gating

> **Executor instructions:** Read this plan fully before implementation. Fix all Critical/Medium review findings before commit. Keep the change separate from delivery-hook work so strict lint becomes a deliberate, reviewable gate.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: 032
- **Category**: quality

## Why this matters

`STRICT_LINT=1 make lint-agent` currently fails on the existing repository-wide SwiftFormat and SwiftLint baseline. Plan 032 intentionally keeps strict lint out of the merge gate until those violations are retired. This plan removes the debt in focused batches, preserves behavior, and then enables strict aliases and guidance.

## Scope

**In scope**:

- Existing SwiftFormat and SwiftLint violations reported by `make lint-agent`.
- Focused tests or compile checks required by mechanical source edits.
- `Makefile`, `AGENTS.md`, `.agents/skills/delivery-workflow/SKILL.md`, and `.agents/docs/build-and-test.md` after the baseline is green.

**Out of scope**:

- Product behavior changes, broad redesigns, rule-budget changes, or disabling lint rules to hide violations.
- Making strict lint mandatory before the full baseline is green.

## Execution

1. Capture the baseline with `make lint-agent` and `STRICT_LINT=1 make lint-agent`; group fixes by rule and subsystem.
2. Apply the smallest mechanical fixes first. Use `make lint-fix` only after reviewing its diff; do not accept unrelated formatting churn.
3. Run targeted checks and `make build-agent` after each batch. Run `make lint-agent` and strict lint at milestones.
4. Run a thermo-nuclear review and fix all Critical/Medium findings.
5. When strict lint passes cleanly, add `lint-strict` and `lint-strict-agent` aliases and update the Full-lane guidance to use them.
6. Mark this row `DONE` only after `make lint`, strict lint, `make build-test`, `make guidance-check`, and `git diff --check` pass.

## Stop conditions

- A lint fix changes runtime behavior or requires a product decision.
- Autofix produces unrelated churn that cannot be isolated.
- A rule appears incorrect for the project; document the case and propose a reviewed `.swiftlint.yml`/SwiftFormat policy change instead of bypassing it silently.
