# Plan 055: Make scoped validation correct for committed diffs and safe under parallel agents

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 58ca8a84..HEAD -- Makefile scripts/scope-check.sh scripts/lib/agent-output.sh scripts/tests .agents/docs/build-and-test.md .agents/skills/delivery-workflow/SKILL.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Lane**: Full — build/test infrastructure is a High trigger
- **Depends on**: plans/032-optimize-agent-delivery-gates.md (DONE)
- **Category**: bug / tests / dx
- **Planned at**: commit `58ca8a84`, 2026-07-12

## Why this matters

The current scoped gate collects committed files from `BASE_REF...HEAD`, but
counts added lines only from the working tree against `HEAD`. A clean branch
with more than 300 committed added lines can therefore bypass the repository's
High-risk trigger. In parallel, all agent commands default to the same
`/tmp/ma-agent` directory and fixed filenames, so concurrent worktrees can
overwrite each other's logs and structured results. These are correctness
problems: they can weaken validation or cause agents to diagnose the wrong run.

## Current state

- `scripts/scope-check.sh` owns changed-file collection and risk escalation:

```bash
# scripts/scope-check.sh:102-114
git diff --name-only --diff-filter=ACMR "${BASE_REF}"...HEAD >> "${changed_file_list}"
git diff --name-only --diff-filter=ACMR HEAD >> "${changed_file_list}"
git ls-files --others --exclude-standard >> "${changed_file_list}"

# scripts/scope-check.sh:398-401
added_lines="$(git diff --numstat HEAD -- | awk '$1 ~ /^[0-9]+$/ {sum += $1} END {print sum+0}')"
if [ "${added_lines}" -gt 300 ]; then
```

  The first operation includes committed branch changes; the second calculation
  does not.

- `scripts/lib/agent-output.sh` provides the shared log directory:

```bash
# scripts/lib/agent-output.sh:111-120
ma_agent_log_dir() {
    printf '%s\n' "${MA_AGENT_LOG_DIR:-/tmp/ma-agent}"
}

ma_agent_prepare_log_dir() {
    local dir
    dir="$(ma_agent_log_dir)"
    mkdir -p "${dir}"
    printf '%s\n' "${dir}"
}
```

- `scripts/scope-check.sh:172-181` then truncates fixed
  `scope-check.log` and `scope-check.result.json` paths in that directory.
  Other agent scripts use the same pattern with their own fixed names.
- No deterministic workflow-script test suite currently covers diff selection,
  large-delta escalation, multi-test quoting, schema-v2 output, or concurrent
  artifact isolation.
- Repository convention: scripts expose compact `AGENT_*` lines and schema-v2
  metadata while keeping full logs on disk; see
  `scripts/lib/agent-output.sh:275-312`. Preserve that external contract.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Script syntax | `bash -n scripts/scope-check.sh scripts/lib/agent-output.sh scripts/tests/*.sh` | exit 0 |
| Workflow fixtures | `make workflow-test` | exit 0; all fixture cases pass without invoking Xcode |
| Guidance | `make guidance-check` | exit 0 |
| Narrow build | `make build-agent` | `AGENT_STATUS=PASS` |
| Full gate | `make lint-strict-agent && make build-test` | strict lint passes; build/test result is green or an unrelated baseline is classified |
| Diff hygiene | `git diff --check` | exit 0 |

## Suggested executor toolkit

- Use `delivery-workflow` for lane/gate behavior.
- Use `testing-xctest` only if Swift tests unexpectedly become necessary; the
  intended tests are shell/Python fixture tests and must not start Xcode.
- Use `thermo-nuclear-code-quality-review` after implementation because this
  plan changes enforcement infrastructure.

## Scope

**In scope**:

- `scripts/scope-check.sh`
- `scripts/lib/agent-output.sh`
- Agent-mode scripts that must adopt the shared run-directory helper
- `scripts/tests/` (create a deterministic workflow fixture suite)
- `Makefile` (add one `workflow-test` target)
- `.agents/docs/build-and-test.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `plans/README.md`

**Out of scope**:

- Swift app source, XCTest behavior, CI provider configuration, signing, release
  packaging, or changing which paths are High-risk.
- Weakening the 300-added-line or more-than-8-source-file thresholds.
- Reusing a shared mutable "latest" result as machine input.
- Persisting prompts, responses, tool arguments, transcripts, source contents,
  or secrets in result artifacts.

## Git workflow

- Branch: `fix/055-scoped-validation-correctness`
- Commits: `fix(workflow): make scoped risk calculation base-aware`, then
  `test(workflow): cover scoped validation and parallel artifacts` if two
  logical commits improve reviewability.
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Define one canonical diff snapshot

Refactor `scripts/scope-check.sh` so changed files, added-line counts, source-file
counts, module counts, and risk triggers are derived from the same union:

1. committed changes from `BASE_REF...HEAD` when `--base` is supplied;
2. staged and unstaged changes against `HEAD`;
3. untracked files, counted consistently without interpreting binary lines as
   numeric additions.

Do not simply concatenate `git diff --numstat` outputs and double-count files
present in both committed and working-tree ranges. Build a canonical snapshot
or calculate each layer with explicit deduplication. The dry-run summary must
say which base/range was used instead of the current hard-coded "vs HEAD" label.

**Verify**: fixture tests for committed-only, staged-only, unstaged-only,
untracked-only, and combined changes all report the expected unique file and
added-line counts.

### Step 2: Namespace every agent invocation

Extend `scripts/lib/agent-output.sh` with one helper that creates an immutable
run directory below `${MA_AGENT_LOG_DIR:-/tmp/ma-agent}`. Its identity must
include enough information to avoid collisions across repository/worktree,
process, and invocation; for example a sanitized repository/worktree hash plus
UTC timestamp, PID, and a short random suffix.

Requirements:

- Parent commands create the run directory once and export it to child commands.
- Nested build/lint/test commands write inside the same run tree, with unique
  step filenames.
- Result JSON points to the exact immutable log/result paths.
- A human-facing `latest` symlink or pointer is optional, but no machine flow may
  read it as authoritative evidence.
- Concurrent invocations must never truncate or overwrite each other.

Update every agent-mode producer that currently calls
`ma_agent_prepare_log_dir` and writes a fixed filename.

**Verify**: start two no-op/dry-run agent commands concurrently in a fixture;
both exit 0 and produce distinct existing log and result paths.

### Step 3: Add deterministic workflow tests

Create `scripts/tests/` fixtures that copy only the required workflow scripts,
minimal Makefile/config, and synthetic source/test names into disposable Git
repositories under `mktemp -d`. Tests must clean up after themselves and must
not depend on the developer's current branch.

Cover at least:

- committed-only `BASE_REF...HEAD` large delta triggers Full;
- a 300-line delta does not trigger `> 300`, while 301 does;
- more than eight unique Swift source files triggers Full;
- staged/unstaged/untracked inputs are included once;
- repeated `--file` targets remain one quoted test invocation;
- invalid base ref fails clearly;
- schema-v2 JSON remains valid;
- two parallel runs produce isolated artifacts.

Add `make workflow-test` as the canonical fast command.

**Verify**: `make workflow-test` exits 0 on three consecutive runs and does not
create tracked or untracked files in the Prisma worktree.

### Step 4: Synchronize guidance and review

Document the immutable run-directory contract and `make workflow-test` in the
delivery skill and build/test reference. Do not add the implementation detail
to root `AGENTS.md` unless an executor needs it for every task.

Run the Full lane and thermo review. Fix all Critical and Medium findings before
marking the plan DONE.

**Verify**: `make guidance-check`, `git diff --check`,
`make lint-strict-agent`, and `make build-test` satisfy the expected results.

## Test plan

- New fixture suite: `scripts/tests/`, modeled after the repo's existing
  CLI-first shell scripts and using disposable Git repositories.
- Required cases: committed/staged/unstaged/untracked diff layers, exact risk
  boundaries, quoting, invalid base, JSON validity, concurrency isolation.
- Run `make workflow-test` three times to expose nondeterministic collisions.
- Run `make build-agent` and the Full lane because workflow infrastructure is a
  High-risk trigger even though Swift source is unchanged.

## Done criteria

- [ ] All risk metrics use the same base-aware, deduplicated diff snapshot.
- [ ] A clean branch with 301 committed added lines selects Full.
- [ ] Exactly 300 added lines does not trigger the `> 300` rule.
- [ ] Every agent invocation gets immutable, non-colliding artifact paths.
- [ ] Parallel fixture runs preserve both result files.
- [ ] `make workflow-test` exists and passes three consecutive runs.
- [ ] No test invokes Xcode or mutates the Prisma worktree.
- [ ] `make guidance-check` and `git diff --check` pass.
- [ ] Full-lane validation and thermo review have no unresolved Critical/Medium findings.
- [ ] `plans/README.md` marks plan 055 `DONE`.

## STOP conditions

- The only apparent fix changes or weakens repository risk thresholds.
- A reliable added-line count requires parsing file contents instead of Git
  numstat/diff metadata.
- Artifact isolation breaks nested commands' ability to return one aggregate
  result tree.
- Workflow tests require running real builds/tests or touching the user's branch.
- Any result artifact would contain prompts, tool arguments, source contents, or secrets.

## Maintenance notes

Any future agent-mode command must obtain its path through the shared run helper.
Reviewers should reject fixed mutable result paths and any new risk metric that
uses a different diff range from changed-file selection.
