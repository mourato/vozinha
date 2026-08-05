# Plan 120: Establish the Swift 6.2 agent baseline for vozinha

> **Executor instructions**: Read this plan completely. This is a high-risk,
> serial migration. Keep the product behavior unchanged, use an isolated branch
> or worktree, and update this plan's README row only after the full gate passes.
> Do not absorb unrelated changes from the existing dirty worktree.
>
> **Drift check (run first)**: `git diff --stat 3936c89b..HEAD --
> App Packages .swiftformat .swiftlint.yml Makefile scripts AGENTS.md
> .agents plans`

## Status

- Priority: P0
- Effort: L
- Risk: HIGH
- Depends on: Plan 119 and reconciliation of the currently dirty worktree
- Category: migration / tooling / concurrency
- Planned at: commit `3936c89b`, 2026-08-05

## Execution profile

- Recommended profile: `implementer`
- Risk/lane: High / Full
- Parallelizable: No. Compiler settings, concurrency fixes, lint policy, and
  agent gates must land as one coherent baseline.
- Reviewer required: Yes — review Swift 6.2 concurrency changes and the final
  build/lint/test gate.
- Rationale: This touches every owned Swift target and can change isolation
  diagnostics without changing product intent.
- Escalate when: a migration requires a data-format/API behavior change,
  broad `@unchecked Sendable` usage, or changes outside the bounded source and
  delivery surfaces below.

## Why it matters

Vozinha already has the strongest concurrency posture in this group: all owned
Xcode configurations declare Swift 6.2, complete strict concurrency, and an
explicit nonisolated default. Its remaining baseline drift is the formatter's
Swift 6.0 setting, a warning-oriented default lint command, and a fix script
that masks formatter/lint failures. The sibling projects provide a better
targeted-lint and compact agent workflow; this plan makes those strengths
portable without introducing another framework.

This is **not a configuration-only change**. Formatting will rewrite source
files mechanically, and Swift 6.2/strict-concurrency diagnostics may require
rewriting isolation annotations, `Sendable` boundaries, async call sites, and
tests. Those rewrites are explicitly in scope only to preserve existing
behavior and satisfy the new compiler/lint baseline.

## Current state

- `MeetingAssistant.xcodeproj/project.pbxproj` has four `SWIFT_VERSION = 6.2`
  entries and four `SWIFT_STRICT_CONCURRENCY = complete` entries, with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` in each configuration.
- `.swift-version` is `6.2`, but `.swiftformat` still passes
  `--swiftversion 6.0`.
- `.swiftlint.yml` covers `App` and `Packages`, excludes generated/build
  output, and already enables useful opt-in rules. It also disables several
  structural rules and allows a large file/function budget.
- `scripts/lint.sh` supports full and agent output, but the default path is
  warning-only (`STRICT_LINT=0`). `scripts/lint-fix.sh` uses `|| true`, which
  hides fix failures.
- `Makefile` already exposes `lint`, `lint-agent`, strict variants,
  `validate-agent`, `guidance-check`, and format commands. Extend this surface;
  do not create a second workflow.
- `AGENTS.md` names `make validate-agent` as the canonical gate and documents
  Swift 6.2/concurrency policy. Project-specific skill facts belong in the
  existing `.agents/` overlay/docs, not in the global skill checkout.
- The read-only formatter check is clean today (`0/526` files require
  formatting), so the expected formatter rewrite is caused by changing the
  declared formatter language version and must be reviewed for unintended
  churn.

## Commands and evidence

| Check | Command | Expected result |
|---|---|---|
| Toolchain | `swift --version && xcodebuild -version && swiftformat --version && swiftlint version` | Swift 6.2-compatible toolchain and the versions recorded in project docs/ADR |
| Language settings | `rg -n 'SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY|SWIFT_DEFAULT_ACTOR_ISOLATION' MeetingAssistant.xcodeproj/project.pbxproj` | Every owned configuration is 6.2 / complete / explicit |
| Formatter config | `rg -n -- '--swiftversion|indent|exclude' .swiftformat` | SwiftFormat language version is 6.2 and generated/build paths remain excluded |
| Format | `swiftformat --lint --config .swiftformat App Packages` | Exit 0; no files require formatting |
| Full lint | `make lint` | Exit 0 with fail-closed semantics and no unreviewed warnings |
| Agent lint | `make lint-agent` and `make lint-agent FILES='App/...swift'` | Human and machine-readable output; targeted scope works |
| Build/tests | `make build-agent` and `make test-full-agent` | Exit 0 for the supported app/package targets |
| Governance | `make validate-agent && make guidance-check` | Exit 0 |
| Diff hygiene | `git diff --check` | No whitespace errors |

Commands that only exist after implementation must be run after the step that
introduces them; record the exact command and result in the implementation
handoff.

## Suggested executor toolkit

- Reuse `swift-conventions` with a vozinha project overlay.
- Reuse `delivery-workflow` with the existing project commands.
- Keep the local concurrency/testing specialist skills; do not duplicate them
  in the global skill bundle.
- Use the existing Makefile and scripts as the single agent-facing command
  surface.

## Scope

In scope:

- Normalize `.swiftformat` to Swift 6.2 and the shared four-space formatting
  baseline.
- Make the lint policy fail closed for verification while retaining an
  explicitly named report-only mode if maintainers still need it.
- Fix the autofix script so a failed formatter/linter is visible; no
  verification path may use `|| true` to hide failure.
- Add/align targeted changed-file linting, correct `--help` behavior, and
  preserve compact `--agent` output.
- Audit every owned Xcode configuration and source/test target for Swift 6.2,
  complete strict concurrency, and explicit actor-isolation settings.
- Rewrite affected `App`, `Packages/MeetingAssistantCore`, and test Swift code
  only for compiler/concurrency/lint/format correctness.
- Update `AGENTS.md`, the relevant `.agents/overlays/` guidance, and add
  `.agents/docs/swift-6-2-agent-baseline.md` as the durable project decision.

Out of scope:

- Product behavior, persistence formats, public service contracts, or a broad
  architecture refactor.
- The existing unrelated change in
  `App/AppDelegate/AppDelegateUserInterfacePreferences.swift`; reconcile it
  separately before implementation.
- Generated build artifacts, DerivedData, dependency caches, secrets, or
  global skill source files.

## Git workflow

Use an isolated branch/worktree named `chore/vozinha-swift-6-2-baseline`.
Prefer small Conventional Commits such as `chore(swift): establish Swift 6.2
agent baseline`; do not push or rewrite history. Keep the final diff limited to
the files in Scope and the plan/index updates.

## Ordered implementation steps

### 1. Freeze the baseline and reconcile scope

Run the drift check, `git status --short`, `git diff --check`, the current
format/lint/build/test/guidance commands, and capture existing warning counts.
Confirm the dirty AppDelegate file is either merged into the branch safely or
excluded from the migration diff.

**Verify:** the starting commit and current failures are recorded; any result
that differs materially from the Current state section is a STOP condition.

### 2. Normalize compiler and actor-isolation settings

Keep the already-correct 6.2/complete/nonisolated settings, but verify every
configuration, package manifest, test target, and generated project input. Make
the values explicit rather than relying on inherited defaults. Preserve
`@MainActor` at UI/AppKit/lifecycle boundaries and use explicit `Sendable` or
actor boundaries where Swift 6.2 exposes races.

**Verify:** `rg` finds no owned Swift 5.x/6.0 setting, every configuration has
the selected values, and `make build-agent` reaches compilation diagnostics
without a project-generation mismatch.

### 3. Align formatter and lint contracts

Change `.swiftformat` to `--swiftversion 6.2`, keep four-space indentation and
existing generated/build exclusions, then run the formatter in the isolated
branch. Review the resulting source rewrite instead of accepting blind churn.
Refine `.swiftlint.yml` only where it improves signal: retain useful opt-ins,
remove unjustified blanket disables, and set an explicit warning/error policy.

**Verify:** `swiftformat --lint --config .swiftformat App Packages` is clean;
`swiftlint lint --config .swiftlint.yml App Packages` is clean or every
remaining exception is named in the project baseline document.

### 4. Perform the required Swift source rewrite

Build and test after formatting. Fix Swift 6.2 diagnostics and lint findings in
small slices, especially main-actor UI access, closures crossing concurrency
boundaries, `Sendable` values, and test isolation. Do not add broad
`@preconcurrency` or `@unchecked Sendable` escapes without a local rationale
and reviewer approval. Keep behavior and persistence contracts unchanged.

**Verify:** `make build-agent` and `make test-full-agent` pass; changed source
has no new warnings, and the reviewer can map each non-mechanical rewrite to a
compiler, concurrency, lint, or format diagnostic.

### 5. Make the agent gates deterministic

Keep `make lint` as the canonical fail-closed check, with a separately named
report-only command if needed. Add changed-file arguments to the script/Make
surface, make `--help` exit without linting, preserve `--agent` output, and
remove masked failures from the verification path. Document the fast targeted
loop and the full merge gate in `AGENTS.md` and the overlay.

**Verify:** full and targeted commands pass on clean and intentionally dirty
Swift fixtures; an injected formatter/lint failure produces non-zero exit and
machine-readable failure output.

### 6. Record the baseline decision

Create `.agents/docs/swift-6-2-agent-baseline.md` with the chosen values,
warning policy, allowed source rewrites, exception process, and upgrade steps.
Update `AGENTS.md` and the project overlay to point to that document and to
the canonical Make targets. Do not copy the global skill text into the repo.

**Verify:** a fresh executor can locate the policy, run the gates, and tell the
difference between a targeted agent check and the full merge check.

### 7. Run the final gate and hand off

Run the complete Commands and evidence table, including `make validate-agent`,
`make guidance-check`, and `git diff --check`. Update `plans/README.md` row
120 only after review and validation.

**Verify:** `git status --short` contains only the approved migration, docs,
and plan/index files; no unrelated dirty file was rewritten.

## Test plan

- Compile every supported Xcode configuration and Swift package target.
- Run the existing unit/integration tests, including package tests and
  `test-full-agent`.
- Add characterization coverage only when a concurrency rewrite changes a
  testable seam; do not add speculative test infrastructure.
- Run full and changed-file format/lint gates plus governance checks.
- Manually smoke-test microphone/dictation lifecycle only if the migration
  touches its actor boundary; record unavailable hardware as a handoff item.

## Done criteria

- All owned targets use Swift 6.2; strict concurrency is complete and actor
  isolation is explicit and documented.
- SwiftFormat 6.2 and four-space formatting are clean.
- Lint verification is fail closed, targeted checks work, and fix failures are
  visible.
- Required source rewrites are reviewed, behavior-preserving, and limited to
  migration diagnostics.
- Build, tests, governance, and diff checks pass.
- The project policy document, `AGENTS.md`, overlay, plan row, and this baseline
  are consistent.

## STOP conditions

- The live tree does not match the drift check or the existing dirty change
  cannot be isolated.
- Swift 6.2 requires changing a persistence/data/API contract or product
  behavior.
- The only apparent fix is broad `@unchecked Sendable`, global actor erasure,
  or a large architecture rewrite.
- A third-party/generated artifact must be edited directly.
- Build/test failures are unrelated and cannot be reproduced from the clean
  baseline.

## Maintenance notes

Future Swift/Xcode upgrades must update the Xcode settings, `.swift-version`,
`.swiftformat`, lint policy, project overlay, and baseline document together.
Keep the changed-file gate fast, but never treat it as a substitute for the
full fail-closed merge gate. If an exception is unavoidable, record its exact
path, rule, reason, owner, and removal condition.
