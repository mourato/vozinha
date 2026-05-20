---
name: quality-assurance
description: This skill should be used when the user asks to "write tests", "create mocks", "define verification gates", or "run quality checks before merge".
---

# Quality Assurance Standards

## Role

Use this skill as the canonical owner for verification strategy and command selection in Prisma.

Core policy alignment:

- `AGENTS.md` and `../task-lifecycle/SKILL.md` own risk classification and lane policy.
- This skill translates those lanes into concrete validation commands.
- `Makefile` is the canonical command surface; if a skill/doc mentions a different target name, fix the doc rather than inventing aliases.
- When running checks via AI agents, prefer compact `*-agent` targets to reduce context volume while preserving failure diagnostics.

## Scope Boundaries

- Own command mapping, validation order, escalation triggers, and scope-based checks.
- Do not own risk classification, lane selection, Git workflow, or review output formatting.
- Delegate XCTest implementation details to `../testing-xctest/SKILL.md`.

## When to Use

Use this skill when the task requires any of the following:

- Choosing which validation commands to run for a given change
- Deciding between scoped validation and full gates
- Mapping Fast/Full lane policy to concrete repository commands
- Selecting extra checks such as preview, architecture, parity, or compact agent runs

## Verification by Lane

### Fast lane (Low risk)

Minimum expectation:

- Run staged lint/format checks (or equivalent lightweight checks).
- Run scoped checks first (targeted tests + relevant scope checks) when the change could affect behavior.
- Before push/merge, run `make scope-check`.

### Full lane (Medium/High risk)

Minimum expectation:

- During development, run scoped checks continuously (targeted tests + narrow build first).
- Reserve `make build-test` for milestone validation and mandatory merge gate.
- Before push/merge (hard gate):
  - `make build-test`
  - `make lint` (mandatory for all Full-lane changes)

`make preflight` remains optional and does not replace lane merge gates. Use it for final comprehensive local validation (release readiness, large rebases, or risk spikes).

## Scoped Validation Intelligence

Use this order during implementation to optimize feedback loop time:

1. Targeted tests (`./scripts/run-tests.sh --suite dev --file ...` / `--test ...`)
2. Narrow build confidence (`make build-agent` or `make build`)
3. Scope-specific checks (`make preview-check`, `make arch-check`)
4. Full suite gate (`make build-test`) when required by lane or escalation triggers

Canonical automation for this sequence: `make scope-check`.

Escalate immediately to full suite (`make build-test`) when:

- Build/release/test infrastructure changes (`Makefile`, `scripts/`, `.github/workflows`, `Package.swift`, project config)
- Cross-module/public API changes
- Audio/persistence/concurrency/security-sensitive paths
- Large change sets or low-confidence test mapping
- Scoped checks show flaky or inconsistent behavior

Escalation decision table:

| Trigger | Action | Command |
| --- | --- | --- |
| Build/release/test infrastructure changed | Immediate Full gate | `make build-test` |
| Cross-module/public API change | Immediate Full gate | `make build-test` |
| High-risk path (audio/persistence/concurrency/security) | Immediate Full gate | `make build-test` |
| Large delta or high churn | Immediate Full gate | `make build-test` |
| Low-confidence mapping | Immediate Full gate | `make build-test` |
| Scoped checks flaky/inconsistent | Escalate and stabilize | `make build-test` + targeted reruns |

## Scope-driven additional checks

Run these only when relevant to the changed scope:

- `make arch-check` for architecture boundary/access-control/import-rule changes.
- `make preview-check` when adding/changing SwiftUI views.
- `make guidance-check` when editing `AGENTS.md`, `.agents/`, or command/reference docs.
- `make test-verbose` or targeted `./scripts/run-tests.sh ...` commands when debugging flaky or scope-specific tests.
- Use `../testing-xctest/SKILL.md` when the task is about structuring or writing XCTest code rather than selecting verification gates.

## Practical command set

```bash
# Core
make build-test
make build-test-strict
make test-full
make test-smoke
make test-sensitive
make test-appkit
make lint
make preflight

# Isolated diagnostics
make build-agent
make test-agent
make scope-check

# Optional local parity diagnostics
make build
make test

# Optional, scope-based
make arch-check
make preview-check

# Compact AI-agent mode (machine-readable summary + log artifacts)
make build-test
make lint-agent
make preflight-agent
make scope-check-agent

# Targeted test workflows
./scripts/run-tests.sh --suite dev --file <TestFile>
./scripts/run-tests.sh --suite dev --test <testName>
./scripts/run-tests.sh --verbose
./scripts/run-tests.sh --agent
```

Lane-to-command matrix:

| Goal | Preferred command | Notes |
| --- | --- | --- |
| Fast lane merge gate | `make scope-check` | Smart scoped checks + automatic escalation |
| Full lane merge gate | `make build-test` + `make lint` | Mandatory pair |
| Fast iteration confidence | `make test-smoke` | Lowest-latency confidence pass |
| Broader local confidence | `make test-full` | Broad swift-test suite |
| Optional all-in-one validation | `make preflight` | Comprehensive, not a lane gate |

Compact-mode notes:

- Full logs are written under `${MA_AGENT_LOG_DIR:-/tmp/ma-agent}`.
- Scripts emit deterministic `AGENT_*` summary lines for pass/fail parsing.
- Use compact mode for iteration; keep lane merge gates unchanged (`make scope-check` for Fast, `make build-test` + `make lint` for Full).

## Related Skills

- `../task-lifecycle/SKILL.md`
- `../testing-xctest/SKILL.md`
- `../code-review/SKILL.md`

## Verification and Automation

- Install Git hooks with:
  - `git config core.hooksPath scripts/hooks`
  - `chmod +x scripts/hooks/pre-commit scripts/hooks/pre-push scripts/hooks/first-commit-version-bump.sh`
  - `find scripts/hooks -maxdepth 1 -type f ! -perm -u+x -print` (must print nothing).
- `pre-commit` is optimized for speed and can run lightweight staged checks.
- `pre-push` enforces scoped validation unless explicitly bypassed.

Emergency bypasses should be rare and followed by immediate remediation.

## Troubleshooting

### Tool missing

```bash
brew install swiftlint swiftformat
```

### Hook failures

- Read the hook output and run the suggested fix command.
- Re-run the failed check locally until green.

### Build/Test mismatch

- Prefer `make test-parity` for Xcode parity.
- Use targeted tests to isolate issues before running full suite again.

## References

- `AGENTS.md`
- `../task-lifecycle/SKILL.md`
- `Makefile`
- `scripts/lint.sh`
- `scripts/run-tests.sh`
