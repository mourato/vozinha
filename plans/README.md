# Implementation Plans

This is the active plan ledger. Historical audits, completed plan rows, review
notes, and rejected options remain in the [2026-07-12 ledger archive](archive/2026-07-12-plan-ledger-history.md).
Plan files are never renumbered; the next available plan number is 061.

## Execution rules

- Read the complete plan before implementation and honor its STOP conditions.
- Keep one objective per execution slice and preserve the repository's
  `reuse -> extend -> create` decision.
- Respect dependencies and execute plans in ledger order when a sequence is
  requested.
- Classify risk and run the lane required by the plan. Infrastructure,
  concurrency, persistence, security, audio, and broad changes use Full.
- Update the status row after implementation, review, and required validation.
- Use atomic Conventional Commits. Do not push or open a PR unless requested.
- Guidance-only plans must not modify product source.
- Global `~/.codex` plans require a dedicated configuration task, operator-
  approved rollback copies, privacy-safe artifacts, and explicit stop conditions.

Status values: `TODO` | `IN PROGRESS` | `DONE` | `BLOCKED` (with a one-line
reason) | `REJECTED` (with a one-line rationale).

## Active and recent plans

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| [040](040-migrate-ui-observation-boundaries.md) | Migrate UI state to Observation at stable boundaries | P1 | L | 039 | DONE |
| [055](055-harden-scoped-validation-artifacts.md) | Make scoped validation correct for committed diffs and safe under parallel agents | P1 | M | 032 | DONE |
| [056](056-create-canonical-lane-runner.md) | Provide one canonical lane runner with safe evidence reuse | P1 | L | 055 | DONE |
| [057](057-reduce-agent-guidance-context.md) | Reduce recurring agent context through an active ledger and routed skill references | P1 | M | - | DONE |
| [058](058-build-global-agent-efficiency-evaluator.md) | Build a global agent-efficiency evaluator with model-attributed cost | P1 | L | - | DONE (54 controlled runs; 100% segment attribution; API-equivalent estimates) |
| [059](059-tune-global-agent-routing.md) | Tune global routing and root reasoning from controlled cost-quality evidence | P1 | M | 058 | DONE (medium beat high on cost/latency; defaults remain unchanged) |
| [060](060-evaluate-lean-tools-fast-implementer.md) | Evaluate a lean code profile and a Fast-lane implementer before enabling either | P2 | M | 058, 059 | DONE (lean/Fast candidates measured; neither promoted globally) |

Plans 001–060 are completed or archived in the historical ledger. The archive preserves the original audit scope,
findings, dependency history, status table, committee notes, and rejected
options verbatim for searchability.

## Active dependency notes

- 040 remains a measured, boundary-by-boundary migration and must not become a
  repository-wide mechanical conversion.
- 055 established the base-aware diff snapshot and immutable run-tree contract.
- 056 owns final validation-evidence reuse; uncertainty must fail closed and
  execute a fresh gate.
- 057 may reduce static guidance size, but must not claim token/cost savings
  without the controlled evaluator from 058.
- 058 completed 54 controlled runs across six tasks and three scenarios; the
  privacy-safe reports remain under `~/.codex/evals/reports`.
- 059 supports medium root effort over high for this workload, but global
  defaults were deliberately not changed during measurement.
- 060 found lean and Fast candidates; keep lean opt-in until artifact/browser
  smoke coverage is added, and keep Fast limited to deterministic Fast-lane
  work in isolated worktrees.
