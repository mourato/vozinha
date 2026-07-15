# Build and Test Reference

This document provides comprehensive CLI and workflow reference for building, testing, and validating changes in Prisma.

## Quick Navigation

Choose commands by lane:

- Canonical Fast/Full/auto merge gate: `make validate-agent ARGS="--lane auto"`
- Workflow fixture gate: `make workflow-test`
- Optional comprehensive validation: `make preflight`

Agent default loop: preview with `make validate-agent ARGS="--lane auto --dry-run --base main"` when needed, run the smallest changed-path check, stage the completed slice, record final evidence with `make validate-agent ARGS="--lane auto --staged --base main --agent"`, let the staged pre-commit hook enforce Swift lint/format, then let pre-push validate the exact committed range received from Git. Compatible PASS evidence is reused across staging and commit when base/head trees, gate inputs, toolchain, lane, and runner match. Do not run tests before every commit by default; use targeted tests and the lane runner for final evidence.

## Primary Build/Test Commands

### Quick start
```bash
make setup
make build
```

### Core workflow commands
```bash
make build-test         # Run build + test in sequence (fast default locally)
make build-test-strict  # Run build + test in strict xcode mode
make build              # Debug build only
make test               # Fast local dev suite
make test-full          # Broad swift-test suite
make test-smoke         # Curated smoke suite
make test-perf          # Isolated performance suite
make test-sensitive     # Isolated sensitive subsystem suite
make test-appkit        # Isolated AppKit lifecycle suite
make test-parity        # Xcode parity run
make scope-check        # Scoped validation with smart targeted mapping + escalation
make scope-check ARGS="--committed --base <base> --head <head>"  # Committed range only
make scope-check ARGS="--committed --empty-base --head <head>"  # Full tree from empty base
make workflow-test      # Deterministic validation workflow fixtures (no Xcode)
make test-ci-strict     # Xcode test run without retry/fallback
make preflight          # Build + Test + Lint + Benchmark (full validation)
make preflight-fast     # Lint + Build + Test (skips benchmark, faster feedback)
make ci-release-parity  # Sparkle release build/archive parity gate (local)
make deliverable-gate   # build-test + lint + ci-release-parity
make run                # Run app in debug mode
make format             # Auto-format with SwiftFormat
make lint               # Run SwiftLint checks
```

### Release and distribution
```bash
make build-release      # Optimized release build
make dmg                # Create DMG installer (auto-detect self-signed identity by exact name)
make setup-self-signed-cert # Bootstrap local self-signed code-signing cert
make ci-release-parity-self-signed DOWNLOAD_URL_PREFIX=... RELEASE_TAG=... # Signed Sparkle parity (archive + appcast)
```

DMG signing mode selection:

```bash
# Auto mode (default via Makefile target): self-signed only if MA_RELEASE_CODE_SIGN_IDENTITY exists
make dmg

# Force ad-hoc mode
MA_RELEASE_SIGNING_MODE=adhoc make dmg

# Force self-signed mode (fails fast if identity is missing)
MA_RELEASE_SIGNING_MODE=self-signed make dmg
```

### Agent-optimized commands (compact output, better for CI/agents)
```bash
make build-test         # Build + test with concise progress
make build-agent        # Debug build only (agent-friendly diagnostics)
make test-agent         # Tests only (machine-readable output)
make scope-check-agent  # Scoped validation in compact agent mode
make test-ci-strict     # Strict xcodebuild run (no fallback/retry)
make lint-agent         # Lint with compact reporting
make lint-strict-agent  # Strict lint with compact reporting
make preflight-agent    # Full validation (agent-optimized)
make preflight-agent-fast # Fast validation (agent-optimized)
```

## Preflight Execution Order Policy

**Default (full verification):**
```
build → test → lint → summary-benchmark
```

**Strict lint gate:**
```bash
make lint-strict-agent
# Strict aliases fail on SwiftLint/SwiftFormat errors while keeping advisory warnings visible.
```

**Fast mode (local feedback only):**
```bash
make preflight-fast         # lint → build → test (skips benchmark)
make preflight-agent-fast   # Agent-optimized fast mode
```

## Direct xcodebuild (when needed)

Use `xcodebuild-safe.sh` to avoid SwiftPM transitive-module resolution instability:

```bash
./scripts/xcodebuild-safe.sh
# Equivalent explicit form:
# xcodebuild -project MeetingAssistant.xcodeproj \
#   -scheme MeetingAssistant \
#   -configuration Debug \
#   -destination 'platform=macOS' build
```

**⛔ NEVER** use bare `xcodebuild build` in this repo.

## Test Workflows

### Run all tests
```bash
make test
make test-agent          # Agent-focused, compact output
make test-full
make test-smoke
make test-perf
make test-sensitive
make test-appkit
make test-parity
make test-verbose        # Detailed output
make test-ci-strict      # Strict xcodebuild parity mode
```

## Test Suite Selection Matrix

| Suite/Command | Best use case | Typical use |
| --- | --- | --- |
| `make test-smoke` | Quick iteration confidence | Inner loop |
| `make test` | Fast local dev suite | Inner loop |
| `make test-full` | Broad swift-test confidence | Pre-gate validation |
| `make test-sensitive` | Audio/concurrency/persistence focus | High-risk subsystem checks |
| `make test-appkit` | Overlay lifecycle coverage | AppKit-specific changes |
| `make test-parity` | Xcode parity diagnostics | Build-system parity checks |
| `make scope-check` | Smart scoped validation + escalation | Iteration feedback |
| `make validate-agent` | Fingerprinted Fast/Full/auto evidence | Merge gate |
| `make preflight` | Build + test + lint + benchmark | Optional comprehensive pass |

### Run specific tests
```bash
./scripts/run-tests.sh --suite dev --file RecordingViewModelTests
./scripts/run-tests.sh --suite dev --test testInitialState
./scripts/run-tests.sh --verbose
./scripts/run-tests.sh --agent
```

### Scoped iteration workflow (faster feedback)

Use this sequence while implementing, then keep lane merge gates at the end:

```bash
# Canonical smart command for iteration (auto-maps tests, escalates when needed)
make scope-check
make validate-agent ARGS="--lane auto"  # Canonical working-tree evidence
make validate-agent ARGS="--lane auto --staged --base main --agent"  # Final staged evidence
make validate-agent ARGS="--lane auto --committed --base <base> --head <head> --agent"  # Exact push range
make validate-agent ARGS="--lane auto --committed --empty-base --head <head> --agent"  # Exact first-push tree range

# Fastest confidence pass
make test-smoke

# 1) Targeted tests for changed behavior
./scripts/run-tests.sh --suite dev --file <TestFile>
./scripts/run-tests.sh --suite dev --test <testName>

# 2) Narrow compile confidence
make build-agent

# 3) Scope-specific checks (only when relevant)
make preview-check
make arch-check
```

For agent planning, preview the decision without running checks:

```bash
make validate-agent ARGS="--lane auto --dry-run --base main"
```

Escalate early to `make build-test` when touching build/test/release infrastructure, cross-module/public APIs, or high-risk paths (audio, persistence, concurrency, security), or when scoped checks are flaky/inconclusive.

Useful options for the script:

```bash
./scripts/scope-check.sh --dry-run
./scripts/scope-check.sh --max-targeted 12
./scripts/scope-check.sh --base main
./scripts/scope-check.sh --no-build
```

### CI-style local checks
```bash
make ci-test             # XCTest output compatible with CI systems
make ci-build            # Includes arch-check
make ci-release-parity   # Mirrors sparkle-release build/archive gate locally
```

### Deliverable gate (recommended before push/release)
```bash
make deliverable-gate
```
This command keeps fast local iteration while adding the release parity guard (`build-test + lint + ci-release-parity`).

## Git Hooks Setup

Configure local Git hooks to use the tracked repository hooks:

```bash
git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/pre-commit scripts/hooks/pre-push scripts/hooks/first-commit-version-bump.sh
find scripts/hooks -maxdepth 1 -type f ! -perm -u+x -print
```

The `find` command must print nothing. If it prints paths, those hook files are not executable yet.

## Script Support Surface

Only scripts explicitly referenced by `Makefile`, `README.md`, `AGENTS.md`, or `.agents` skills/docs are treated as supported developer surface. Other scripts are ad hoc and may be removed during cleanup cycles.

## Linting and Formatting

### Check without fixing
```bash
make lint                # SwiftLint check
./scripts/lint.sh        # Direct lint script
```

### Auto-fix
```bash
make format              # SwiftFormat with auto-fix
./scripts/lint-fix.sh    # Combined lint + format fixes
```

### Specialized checks
```bash
make arch-check          # Architecture boundary/access-control validation
make preview-check       # SwiftUI preview coverage validation
```

## Agent Artifacts and Logging

Agents automatically capture build/test output and diagnostics.

**Log directory:**
- Default: `/tmp/ma-agent/`
- Override: `MA_AGENT_LOG_DIR=/custom/path make build-agent`
- Each invocation creates an immutable `run-*` directory below that root. Nested
  commands inherit `MA_AGENT_RUN_DIR`, so concurrent worktrees cannot truncate
  one another's logs or result files.

**Log contents** (deterministic summary lines):
- `AGENT_STEP` — task milestone
- `AGENT_STATUS` — pass/fail status
- `AGENT_DURATION_SEC` — execution time
- `AGENT_LOG` — path to full log file
- `AGENT_ERROR_COUNT` — number of errors
- `AGENT_SUMMARY` — human-readable summary
- `AGENT_RESULT_JSON` — structured result

Agent result files use `schemaVersion: 2` and contain the step status, duration,
error count, executed command summaries, and validation decision. They contain
log paths and metadata only; full logs remain on disk and prompts, transcripts,
file contents, and secrets are never embedded in the JSON.

`validate-agent` adds a content-addressed fingerprint covering the requested and
selected lane, base/head trees, validation content representation, gate inputs,
external gate inputs (including `Packages/MeetingAssistantCore/Package.resolved`
when present), toolchain identities, and runner schema. Committed mode materializes
`HEAD_REF` in a temporary detached worktree before selecting or running the gate;
if external inputs differ between the original checkout and materialized tree,
reuse and PASS-cache writes are disabled for that run. Staged and committed modes
exclude unrelated unstaged/untracked state. Only exact `PASS` evidence with
existing child results and matching fingerprints can be reused. Use
`--no-reuse` after flaky or inconclusive behavior; dry-run output is never proof.

On failure, scripts print compact excerpts to terminal while keeping full logs on disk.

## Minimum Verification Gates

**Before push/merge (mandatory):**
- ✓ Canonical lane: `make validate-agent ARGS="--lane auto"`
- ✓ Guidance changes (`AGENTS.md`, `.agents/`, command docs): `make guidance-check`

**Recommended before merge:**
- ✓ `make preflight` — full validation
- ✓ `make lint-strict` — code quality checks
- ✓ `make ci-release-parity` — Sparkle release build/archive parity

**Pre-release:**
- ✓ `make preflight` + full validation
- ✓ `make build-release` + DMG creation
- ✓ Manual smoke test on target macOS versions

## Common Workflows

| Goal | Command |
|------|---------|
| Local development loop | `make build && make run` |
| Before committing | Staged SwiftFormat/SwiftLint pre-commit hook; run `make lint-fix` when it fails |
| Before push/release (recommended) | pre-push exact committed range; `make deliverable-gate` for high confidence |
| Pre-merge validation | `make preflight` |
| Fast local feedback | `make preflight-fast` |
| Smart scoped iteration | `make scope-check` |
| Agent-based pre-merge | `make preflight-agent` |
| Release preparation | `make lint && make build-test && make build-release && make dmg` |
| CI-style check | `make ci-build` |
| Profile performance | `make profile-report` |

## Troubleshooting

**"unstable SwiftPM transitive-module resolution" errors:**
- Use `./scripts/xcodebuild-safe.sh` instead of bare `xcodebuild build`
- Clear build cache: `rm -rf build/`

**Tests fail intermittently:**
- Run tests in isolation: `./scripts/run-tests.sh --suite dev --file SpecificTestFile`
- Check for concurrency/timing issues in test code

**Linter or formatter issues:**
- Verify `.swiftlint.yml` and `.swiftformat` exist and are valid
- Run `make lint-fix` to auto-correct most issues

## References

- SwiftLint config: `.swiftlint.yml`
- SwiftFormat config: `.swiftformat`
- Build scripts: `scripts/` (e.g., `build-release.sh`, `preflight.sh`, `scope-check.sh`)
- Makefile targets: `Makefile` (root)
