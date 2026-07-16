# Delivery Workflow — task reference

Git mechanics, scoped validation, hooks, and release flows. Role, lanes, and the agent validation loop live in `../SKILL.md`.

## Verification by lane

### Fast lane (Low risk)

- During iteration: targeted tests and smallest changed-path checks.
- End of task when Swift touched: fail-closed lint on the delta (`make lint-strict-agent` or equivalent).
- End of task when behavior changed: one `make validate-agent ARGS="--lane auto --base main --agent"` (or `--committed`) on a clean tree.
- Commit: pre-commit applies staged SwiftFormat/SwiftLint autofix and re-stages.
- Push: pre-push runs or reuses canonical auto validation for the exact committed range.

### Full lane (Medium/High risk)

- During development, run the smallest changed-path checks — not Full on every slice.
- End of task: strict lint + affected-module or Full validation as lane requires.
- Prefer one clean-tree `make validate-agent ARGS="--lane auto --base main --agent"` (or `--committed`) when you need local Full evidence.
- Reserve direct `make build-test` / `--no-reuse` for milestones or after flaky reuse.
- Push: when auto=Full, pre-push runs mandatory `validate-agent --lane full --committed`; do not stack duplicate Full runs.

`make preflight` is optional and does not replace lane technical validation gates.

### Evidence contract

Every handoff, commit, or PR must state: risk/lane, reusable-block decision, files inspected, commands and results, escalation rationale, known baseline failures, and review outcome.

A dry-run is planning evidence only. Fast/Full evidence must include the final `make validate-agent` aggregate. That aggregate proves technical checks only; thermo-nuclear semaforo review remains separate when required.

## Scoped validation

Iteration order:

1. Targeted tests: `./scripts/run-tests.sh --suite dev --file <TestFile>` or `--test <testName>`.
2. Narrow build: `make build-agent` or `make build`.
3. Scope checks: `make preview-check`, `make arch-check`, or `make guidance-check`.
4. Full suite: `make build-test` when lane or escalation requires it.

Canonical final technical evidence: `make validate-agent`. Use `make scope-check` only as an ad-hoc changed-path preview engine — not as a duplicate gate.

Escalate to `make build-test` when infrastructure, cross-module/public API, audio/persistence/concurrency/security paths, large deltas, or flaky scoped checks demand it.

## Practical command set

```bash
# Core gates
make validate-agent ARGS="--lane auto"
make build-test
make lint
make preflight
make deliverable-gate

# Compact agent mode
make build-agent
make test-agent
make lint-agent
make scope-check-agent
make validate-agent ARGS="--lane auto --agent"
make workflow-test
make preflight-agent

# Scope-specific
make preview-check
make arch-check
make guidance-check

# Targeted tests
./scripts/run-tests.sh --suite dev --file <TestFile>
./scripts/run-tests.sh --suite dev --test <testName>
./scripts/run-tests.sh --agent
```

### Compact-mode notes

- Each agent invocation creates an immutable run directory below `${MA_AGENT_LOG_DIR:-/tmp/ma-agent}`.
- Scripts emit deterministic `AGENT_*` summary lines; `*.result.json` uses schema version 2 with metadata only — no prompts, transcripts, or secrets.
- `make workflow-test` runs deterministic fixtures without Xcode.
- `make validate-agent` is the canonical final lane runner with content-addressed PASS fingerprints; reuse fails closed on mismatch. Use `--no-reuse` after flaky behavior.

### Agent delivery sequence

1. Iteration: smallest changed-path check only (no Full/`build-test` per slice).
2. End of task: strict lint when Swift changed; affected-module
   `validate-agent --lane auto` when behavior changed.
3. Commit: pre-commit applies staged SwiftFormat/SwiftLint autofix and re-stages;
   `SKIP_LINT=1` is emergency only.
4. Optional local evidence (Full/infra or unclear lane): one
   `make validate-agent ARGS="--lane auto --base main --agent"` on a clean tree,
   or `--committed --base <base> --head HEAD`. Skip dry-run/staged stacking.
5. Push: pre-push validates or reuses the exact committed range. Fast uses
   `validate-agent --lane auto --committed`; Full uses mandatory
   `validate-agent --lane full --committed`. A clean working-tree PASS with the
   same base/head trees can still be reused.
6. Guidance-only: use `make guidance-check` during iteration; the Fast pushed
   range records that command without running product tests.
7. `make preflight-agent` / `make deliverable-gate` for release or high-confidence only.

Tests are not run before every commit by default. `scope-check` is not a second
technical gate — do not run it alongside `validate-agent` “for safety”.
`MA_RUST_AUDIO_KERNELS_BUILD=off` is not a routine push workaround.

## Git workflow

- Preserve unrelated worktree changes.
- Use Conventional Commits: `<type>(<optional-scope>): <summary>`.
- Keep commits atomic; do not commit knowingly broken code.
- Use PRs for non-trivial work unless the user explicitly chooses direct local merge.
- Prefer `gh --body-file` for multiline GitHub content; avoid destructive commands without explicit authorization.

```bash
git status --short
git diff --stat
git add <files>
SKIP_DAILY_VERSION_BUMP=1 git commit -m "<type>(<scope>): <summary>"
git push origin <branch>
```

PR descriptions: summary, scope/risk, validation results, review findings, baseline failures. Never include secrets or full transcripts.

## Hook and troubleshooting

- Install hooks: `git config core.hooksPath scripts/hooks` or `make setup`.
- `pre-commit`: applies staged SwiftFormat write + SwiftLint `--fix`, re-stages, then fails closed on residual lint; no tests.
- `pre-push`: resolves auto lane via `scope-check --dry-run`, then validates or reuses the exact range. **Fast** uses `validate-agent --lane auto --committed`; **Full** uses mandatory `validate-agent --lane full --committed`. Compatible PASS fingerprints avoid duplicate execution.
- Rust audio staging is required in `auto`/`on` modes. Do not treat
  `MA_RUST_AUDIO_KERNELS_BUILD=off` as a routine push workaround; use it only
  as an emergency bypass when Rust tooling is unavailable.
- Ambient `CARGO_TARGET_DIR` no longer breaks staging: the stage script pins
  `--target-dir` to the crate-local `Native/AudioKernelsRust/target`.
- On failure, inspect the printed `AGENT_RESULT_JSON` path. Set
  `PUSH_CHECK_VERBOSE=1` for full validation logs. If logs mention
  `[rust-audio] expected artifact not found`, rerun
  `scripts/stage-rust-audio-kernels.sh` locally before retrying.
- Emergency bypasses (`SKIP_LINT=1`, `SKIP_TESTS=1`) should be rare with immediate remediation.
- Missing tools: `brew install swiftlint swiftformat`.

## Preflight and deliverable-gate

- `make preflight`: build + test + lint + benchmark (optional comprehensive validation).
- `make preflight-fast`: lint + build + test (skips benchmark).
- `make deliverable-gate`: build-test + lint + ci-release-parity for release confidence.
- These do not replace mandatory Fast/Full technical validation gates.
