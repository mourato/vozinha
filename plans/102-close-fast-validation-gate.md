# Plan 102: Make Fast and guidance pushes pass a real technical gate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update this plan's row in
> `plans/README.md`.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat fa93d031..HEAD -- \
>   scripts/hooks/pre-push \
>   scripts/scope-check.sh \
>   scripts/validate-agent.sh \
>   scripts/tests/workflow-test.sh \
>   scripts/tests/workflow-fixture-step.sh \
>   Makefile AGENTS.md \
>   .agents/skills/delivery-workflow \
>   .agents/docs/build-and-test.md \
>   plans/README.md
> ```
>
> If any in-scope file changed, compare the current-state excerpts below with
> the live code. If the Fast hook, guidance path, or fingerprint contract has
> materially changed, STOP and report the drift.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: none; plans 100 and 101 are already incorporated in the baseline
- **Category**: dx
- **Planned at**: commit `fa93d031`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — hook, runner, fixtures, and guidance form one gate contract
- **Reviewer required**: `yes` — a fail-open push path or duplicate Full run is merge-blocking
- **Rationale**: This changes `scripts/`, Git hook behavior, and the canonical validation contract.
- **Escalate when**: The change requires a new persistent receipt store, Git notes, CI/branch-protection changes, or changes to Full-lane test contents.

## Why this matters

The repository calls `validate-agent` the remembered technical gate, but a
push whose auto decision is Fast currently succeeds without checking a PASS
receipt and without executing validation. Guidance-only changes are also
classified as non-code and return successfully without `make guidance-check`.
This plan makes every branch push execute or reuse the canonical committed-range
gate and makes guidance validation part of the Fast result instead of relying
on agent memory.

This plan deliberately restores Fast validation on push. The content-addressed
cache remains the optimization: an exact compatible PASS is reused; otherwise
the committed range is actually checked. Do not introduce a second receipt
format.

## Current state

### Fast pre-push is fail-open

`scripts/hooks/pre-push:198-206`:

```bash
selected_lane="$(resolve_auto_lane "${base_ref:-}" "${head_ref}" "${empty_base}")"
if [ "${selected_lane}" = "fast" ]; then
    echo "Fast push: relying on end-of-task validate-agent --lane auto evidence."
    echo "Push validation passed (light)."
    return 0
fi
```

No fingerprint or result file is checked before returning success.

### Guidance returns before its checker runs

`scripts/scope-check.sh:496-500,538-540`:

```bash
case "${file_path}" in
    *.swift|*.m|*.mm|*.h|*.c|*.cpp|Makefile|Package.swift|scripts/*|...)
        code_relevant=1
        ;;
esac

if [ "${code_relevant}" -eq 0 ]; then
    echo "Only non-code files changed. Skipping scoped build/tests."
    return 0
fi
```

`AGENTS.md`, `.agents/docs/**`, and `.agents/skills/**` therefore produce a
PASS result without `scripts/validate-agent-guidance.py` running.

### Existing reusable mechanisms

- `scripts/validate-agent.sh:628-631` already reuses a valid fingerprinted PASS.
- `scripts/validate-agent.sh:549-597` already materializes committed HEADs safely.
- `scripts/tests/workflow-test.sh:test_pre_push_protocol` owns Fast/Full hook fixtures.
- `scripts/tests/workflow-test.sh:test_validate_runner_preview_and_reuse` owns cache fixtures.
- `scripts/tests/workflow-fixture-step.sh` emits valid schema-v2 child results.

Reuse these paths; do not build another cache or hook protocol.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Shell syntax | `bash -n scripts/hooks/pre-push scripts/scope-check.sh scripts/validate-agent.sh scripts/tests/workflow-test.sh` | exit 0 |
| Workflow fixtures | `make workflow-test` | ends with `WORKFLOW_TEST_STATUS=PASS` |
| Guidance | `make guidance-check` | `Guidance validation passed.` |
| Full infrastructure gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | `AGENT_STATUS=PASS` |
| Diff hygiene | `git diff --check` | no output, exit 0 |

## Suggested executor toolkit

- Use `delivery-workflow` for lane, hook, artifact, and evidence rules.
- Use `project-standards` only for the small guidance wording changes.
- Use the existing workflow fixtures instead of manual pushes to a real remote.

## Scope

**In scope**:

- `scripts/hooks/pre-push`
- `scripts/scope-check.sh`
- `scripts/tests/workflow-test.sh`
- `scripts/tests/workflow-fixture-step.sh` only if a named guidance fixture step is useful
- `scripts/validate-agent.sh` only for truthful technical-PASS wording or a minimal reusable helper; prefer no change
- `Makefile` only if a fixture-compatible agent target is required; prefer no new public target
- `AGENTS.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/delivery-workflow/references/delivery-workflow-details.md`
- `.agents/docs/build-and-test.md`
- `plans/README.md`

**Out of scope**:

- Changing the risk matrix or deciding which Swift changes are Fast; plan 103 owns that
- Changing Full-lane contents (`lint-strict` plus `build-test`)
- Adding CI, GitHub branch protection, Git notes, a database, or another receipt format
- Making `SKIP_TESTS=1` normal
- Adding review approval to the technical validation JSON; reviewer approval remains a separate delivery requirement
- Changing pre-commit formatting behavior

## Git workflow

- Work only in an explicitly isolated worktree.
- Suggested branch: `fix/102-close-fast-validation-gate`
- Suggested commits:
  1. `fix(workflow): validate fast and guidance push ranges`
  2. `test(workflow): cover fast receipts and guidance gates`
  3. `docs(delivery): describe truthful technical validation`
- Do not push or open a PR unless requested.

## Policy contract

Implement exactly these semantics:

1. Pre-push still computes the exact committed range and auto lane.
2. For `selectedLane=fast`, invoke canonical committed validation with
   `--lane auto` and the exact same `--base/--head` or `--empty-base/--head`
   range. Do not return success before that command succeeds.
3. Allow `validate-agent` to reuse compatible PASS evidence normally. If no
   compatible receipt exists, execute the Fast gate; do not fail merely because
   cache is absent.
4. For `selectedLane=full`, preserve the current mandatory Full path and Rust
   failure hint behavior.
5. When changed paths include `AGENTS.md`, `.agents/docs/**`, or
   `.agents/skills/**`, the scope result must execute `make guidance-check`
   before returning PASS. `README.md` should only be included if its supported
   command/guidance section changed; do not try to infer Markdown content in
   this plan.
6. Guidance-only must not run Swift build/tests. Its Fast receipt is the
   `scope-check` result containing a successful `guidance-check` command.
7. User-facing output and docs must call `validate-agent` a **technical
   validation gate**, not complete merge approval. Full review requirements
   remain explicit and separate.
8. Preserve exact-ref validation, direct-URL redaction, detached-worktree
   materialization, cache validation, and emergency bypass warnings.

## Steps

### Step 1: Add guidance-aware Fast execution to `scope-check`

In `scripts/scope-check.sh`:

1. Add a `guidance_relevant=0` local in `main`.
2. While iterating changed files, set it for:
   - `AGENTS.md`
   - `.agents/docs/*`
   - `.agents/skills/*`
3. Before the current non-code early return, run `make guidance-check` through
   `run_cmd` when `guidance_relevant=1`.
4. Emit a clear plan line such as `- Running guidance gate...`.
5. Return the check's non-zero status; never swallow it.
6. Keep pure non-guidance Markdown/assets on the existing no-build path.

**Verify**:

```bash
bash -n scripts/scope-check.sh
./scripts/scope-check.sh --dry-run --committed --base 15ae3e3c^ --head 15ae3e3c
```

Expected: output includes `make guidance-check`, excludes Swift build/test
commands, and exits 0.

### Step 2: Replace the Fast hook shortcut with canonical validation

In `scripts/hooks/pre-push`, keep `resolve_auto_lane` for display/branching.
Replace the Fast `return 0` block with a call to:

```bash
make validate-agent ARGS="--lane auto --committed <exact-range-args> --agent"
```

Use the same output capture, status propagation, result-path reporting, signal
cleanup, and secret-safe display pattern as the current Full branch. Extract
one small local helper if needed to avoid duplicating the command runner, but
do not create another script.

Fast success output must distinguish:

- `AGENT_REUSED=1`: compatible evidence reused;
- `AGENT_REUSED=0`: Fast validation executed now.

The hook must fail if `make validate-agent` fails or produces an incomplete
aggregate. Preserve Full invocation as `--lane full`.

**Verify**: `bash -n scripts/hooks/pre-push` → exit 0.

### Step 3: Extend workflow fixtures before changing expectations

Update `scripts/tests/workflow-test.sh` using the existing `new_fixture`,
`test_pre_push_protocol`, and cache helpers.

Add assertions for all cases:

1. Fast push without a prior receipt executes `scope-check-agent` and succeeds.
2. Repeating the same exact Fast push with the same log root reports
   `AGENT_REUSED=1` and does not execute the fixture step twice.
3. Fast validation failure blocks the push.
4. An `AGENTS.md`-only committed change runs the fixture guidance command and
   does not run `build-test`.
5. A broken guidance command blocks validation/push.
6. Full script change still runs `lint-strict` and `build-test` exactly once.
7. Direct remote URLs remain redacted.

If the fixture Makefile needs a `guidance-check` target, route it to
`workflow-fixture-step.sh guidance`; add a fail flag specific to that step
instead of making unrelated fixture steps fail.

**Verify**: `make workflow-test` → `WORKFLOW_TEST_STATUS=PASS`.

### Step 4: Make the documentation truthful and remove Option-C assumptions

Update the in-scope guidance so it says:

- pre-push always validates or reuses the exact pushed range;
- Fast may be cheap through fingerprint reuse but is not an unconditional pass;
- guidance-only runs `guidance-check` without product tests;
- `validate-agent` proves technical checks only; required review is separate;
- do not stack manual working-tree/staged/committed gates because the hook owns
  the final committed range.

Remove wording that says Fast pre-push merely “relies” on agent evidence.
Do not edit the risk matrix; plan 103 owns it.

**Verify**:

```bash
make guidance-check
rg -n "Push validation passed \(light\)|relies on end-of-task" \
  AGENTS.md .agents/skills/delivery-workflow .agents/docs/build-and-test.md
```

Expected: guidance passes; the `rg` command returns no stale Option-C claim.

### Step 5: Run the required infrastructure gate

Run, in order:

```bash
bash -n scripts/hooks/pre-push scripts/scope-check.sh scripts/validate-agent.sh scripts/tests/workflow-test.sh
make workflow-test
make guidance-check
git diff --check
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Expected: every command exits 0; final output includes `AGENT_STATUS=PASS`.
Do not run a second redundant Full validation after an exact PASS.

## Test plan

- Extend `scripts/tests/workflow-test.sh`; do not create network-dependent tests.
- Model hook tests after `test_pre_push_protocol` and cache tests after
  `test_validate_runner_preview_and_reuse`.
- Cover success, cache reuse, missing receipt/execution, child failure,
  guidance-only success/failure, Full preservation, and URL redaction.
- Tests must use temporary Git repositories under `TMP_ROOT` and leave the real
  worktree unchanged.

## Done criteria

- [ ] Fast pre-push cannot return success before exact-range `validate-agent` succeeds.
- [ ] Compatible Fast PASS evidence is reused; missing evidence executes the gate.
- [ ] `AGENTS.md`/`.agents` changes run `make guidance-check` and skip product builds.
- [ ] A failing guidance check or Fast child blocks push.
- [ ] Full path and emergency bypass behavior are unchanged.
- [ ] Output/docs say “technical validation”, not “merge approved”.
- [ ] `make workflow-test` and `make guidance-check` pass.
- [ ] Full `validate-agent --no-reuse` passes once.
- [ ] Only in-scope files plus `plans/README.md` changed.
- [ ] Ledger row is updated.

## STOP conditions

Stop and report if:

- Exact committed validation cannot reuse the existing schema-v2 cache without
  changing fingerprint semantics.
- Fast correctness appears to require persistent state outside
  `${MA_AGENT_LOG_DIR:-/tmp/ma-agent}`.
- The fix would weaken Full triggers, ref validation, URL redaction, worktree
  isolation, or emergency-bypass visibility.
- Workflow fixtures require a real remote, real Xcode build, or secret-bearing URL.
- An in-scope script changed materially after `fa93d031`.
- A verification fails twice after a focused fix.

## Maintenance notes

- Plan 103 will change which deltas select Fast versus Full; keep this plan's
  exact-range gate independent of that policy.
- Reviewers should scrutinize every early `return 0` in pre-push and scope-check.
- Fingerprint reuse is an optimization, never authorization to skip an invalid
  or absent result.
- Review approval remains outside the technical result until a separately
  designed, commit-bound review receipt exists.
