# Plan 087: Fix pre-push reliability and finish agent-ops follow-ups

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9e006e07..HEAD -- scripts/stage-rust-audio-kernels.sh scripts/run-build.sh scripts/validate-agent.sh scripts/scope-check.sh scripts/hooks/pre-push scripts/tests scripts/lib/configure-git-hooks.sh .agents/skills/macos-app-engineering .agents/skills/delivery-workflow AGENTS.md .agents/docs/build-and-test.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/084-slim-always-on-agent-guidance-and-validation-loop.md, plans/085-finish-progressive-disclosure-and-prune-skill-bulk.md, plans/086-auto-install-hooks-and-promote-implementer-fast.md
- **Category**: dx / bug / perf
- **Planned at**: commit `9e006e07`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — pre-push / validate-agent / scope-check are shared delivery infrastructure
- **Rationale**: Touches gate scripts, fingerprint reuse, and Rust staging. Ambiguity around worktree materialization needs careful fail-closed behavior.
- **Escalate when**: Fix appears to require changing Xcode project signing, shipping a bundled dylib in-repo, or weakening Full-lane infra triggers for `scripts/*`.

## Why this matters

Pushing `3a1dfa3b..9e006e07` (plans 084–086) failed on the pre-push hook. The
implementing session recorded the root symptom: committed validation in a
detached temp worktree reported

```text
[rust-audio] expected artifact not found: .../prisma-validate-head.*/Native/AudioKernelsRust/target/debug/libaudio_kernels_rust.dylib
```

The push only succeeded with `MA_RUST_AUDIO_KERNELS_BUILD=off` (Full gate still
ran ~232s). That is a reliability bug in staging under redirected Cargo target
dirs (agents/sandboxes often set `CARGO_TARGET_DIR`), not a reason to keep
disabling Rust staging on every push.

Separately, review of 084–086 found:

1. Six large **generic** macOS reference files remain linked (~3.5k lines) after
   the 085 prune.
2. Committed validation frequently sets `externalInputsMismatch=true` because
   gitignored `Package.resolved` exists in the developer checkout but is absent
   in the fresh worktree — **disabling PASS reuse** and making every push pay
   Full cost again.
3. Hooks fixture covers only the happy path.

This plan fixes the push failure, makes committed validation smarter about
reuse and escalation, finishes the guidance prune, and hardens hook tests.

## Current state

### Push failure (evidence)

From `/tmp/ma-agent/run-f7b3705f802f3cec-.../build-test.log` during committed
validation of `9e006e07`:

```text
[rust-audio] building libaudio_kernels_rust.dylib (Debug)
[rust-audio] expected artifact not found: /var/.../prisma-validate-head.*/Native/AudioKernelsRust/target/debug/libaudio_kernels_rust.dylib
```

`scripts/stage-rust-audio-kernels.sh` always looks here after `cargo build`:

```text
scripts/stage-rust-audio-kernels.sh:116-119
ARTIFACT_PATH="${CRATE_DIR}/target/${CARGO_PROFILE_DIR}/${LIB_NAME}"
if [ ! -f "${ARTIFACT_PATH}" ]; then
    echo "[rust-audio] expected artifact not found: ${ARTIFACT_PATH}" >&2
```

When `CARGO_TARGET_DIR` is set in the environment (Cursor sandboxes and some
dev shells do this), Cargo writes the dylib under `$CARGO_TARGET_DIR/...`, not
under `Native/AudioKernelsRust/target/...`. `cargo` can still exit 0, then
staging fails. Workaround used in the session: `MA_RUST_AUDIO_KERNELS_BUILD=off`.

### Cache/reuse disabled on almost every committed push

```text
scripts/validate-agent.sh:225-240  hash_external_gate_inputs hashes Package.resolved paths
scripts/validate-agent.sh:266-268  committed mode sets EXTERNAL_INPUTS_MISMATCH when checkout hash != materialized hash
.gitignore:58                      Package.resolved is ignored
```

Developer trees often have `Packages/MeetingAssistantCore/Package.resolved`;
detached validate worktrees do not → mismatch → "Cache disabled" → no reuse of
a just-run working-tree Full PASS → ~4 minutes of rebuild on push.

### Lane over-escalation noise

`count_added_lines` sums **all** numstat additions in the range. Guidance
rewrites + script adds easily exceed 300 lines and force Full even when the
behavioral risk is only infrastructure (already covered by `scripts/*` triggers).
Archive renames are mostly zero-cost due to rename detection, but pure docs
still pay Full when paired with any script touch (correct) — keep infra
triggers; do not weaken `scripts/*` → Full.

### Leftover hot-path bulk (plan 085 follow-up)

Live refs still linked from `macos-app-engineering-details.md`:

```text
appkit-integration.md, concurrency-patterns.md, design-system.md,
macos-polish.md, swiftui-composition.md, testing-debugging.md
```

These still read as generic Apple dumps (no `SettingsListGroup` / Prisma tokens).
Prisma-specific rules already live in `macos-app-engineering-details.md` and
`SKILL.md`.

### Pre-push shape today

```text
scripts/hooks/pre-push:146-156
args="--lane auto --committed --base ${base_ref} --head ${head_ref}"
make validate-agent ARGS="${args}"
```

Always materializes a detached worktree via `run_committed_tree` — correct for
isolation, but must be compatible with Cargo target redirection and must not
false-disable reuse.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Workflow fixtures | `make workflow-test` | `WORKFLOW_TEST_STATUS=PASS` |
| Guidance | `make guidance-check` | exit 0 |
| Rust stage with redirected target | see Step 1 verify | stages or finds dylib; exit 0 |
| Committed dry-run | `make validate-agent ARGS="--lane auto --dry-run --committed --base origin/main --head HEAD --agent"` | exit 0; prints selected lane |
| Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | exit 0 |
| Simulated pre-push | `git push --dry-run origin HEAD` is insufficient; use workflow pre-push fixture + a committed validate without `MA_RUST_AUDIO_KERNELS_BUILD=off` | PASS |

## Suggested executor toolkit

- `delivery-workflow` for gate/reuse policy text
- `project-standards` for guidance prune ownership
- Do **not** disable Rust staging by default in hooks

## Scope

**In scope**:

- `scripts/stage-rust-audio-kernels.sh`
- `scripts/run-build.sh` only if needed to pass through target-dir / env hygiene
- `scripts/validate-agent.sh` (external-input fingerprint + optional worktree seeding / in-place fast path)
- `scripts/scope-check.sh` (large-delta exclusions for archive/guidance noise — carefully)
- `scripts/hooks/pre-push` (clearer failure hints; no semantic bypass)
- `scripts/tests/workflow-test.sh` and/or new fixtures under `scripts/tests/`
- `scripts/tests/hooks-setup-test.sh` (edge cases)
- `.agents/skills/macos-app-engineering/SKILL.md`
- `.agents/skills/macos-app-engineering/references/` + archive under `.agents/docs/archive/`
- `.agents/skills/delivery-workflow/SKILL.md` and/or `references/delivery-workflow-details.md` (pre-push remediation notes)
- `.agents/docs/build-and-test.md` (hooks / push troubleshooting)
- `plans/README.md`

**Out of scope**:

- Disabling pre-push by default or making `SKIP_TESTS=1` normal
- Removing Full escalation for real `scripts/*` / Makefile changes
- Promoting lean-code
- Product Swift/audio algorithm changes
- Vendoring the Rust dylib into git
- Changing Xcode signing identities

## Git workflow

- Branch: `fix/087-pre-push-reliability-and-agent-ops-followups`
- Suggested atomic commits:
  1. `fix(build): resolve Rust audio dylib under CARGO_TARGET_DIR`
  2. `fix(workflow): stop false externalInputsMismatch on gitignored Package.resolved`
  3. `fix(workflow): smarten committed validation reuse and scope large-delta exclusions`
  4. `test(workflow): cover hooks edge cases and rust/target-dir staging`
  5. `docs(skills): unlink generic macos-app-engineering reference dumps`
- Do NOT push unless asked. When validating push behavior locally, prefer
  `make validate-agent ARGS="--lane auto --committed --base <base> --head HEAD --agent"`
  over forcing `MA_RUST_AUDIO_KERNELS_BUILD=off`.

## Steps

### Step 1: Fix Rust staging artifact discovery

Edit `scripts/stage-rust-audio-kernels.sh` so that after `cargo build` succeeds,
the artifact is resolved in this order:

1. If `CARGO_TARGET_DIR` is set and non-empty:
   `${CARGO_TARGET_DIR}/${CARGO_PROFILE_DIR}/${LIB_NAME}`
   (and, if needed, the triple-prefixed layout Cargo sometimes uses — probe
   with `find` limited to depth 3 under `CARGO_TARGET_DIR` for `${LIB_NAME}`
   only when the direct path is missing).
2. Else `${CRATE_DIR}/target/${CARGO_PROFILE_DIR}/${LIB_NAME}` (current behavior).
3. If still missing: fail with a message that prints `CARGO_TARGET_DIR`,
   `CONFIGURATION`, and the paths probed.

Do **not** silently fall back to `MA_RUST_AUDIO_KERNELS_BUILD=off`. Prefer
explicit `--target-dir "${CRATE_DIR}/target"` on the `cargo build` invocation
**or** honoring `CARGO_TARGET_DIR` consistently for both build and lookup.
Recommended approach (simplest + deterministic):

- Pass `--target-dir "${CRATE_DIR}/target"` to `cargo build` so the script owns
  the output location regardless of ambient `CARGO_TARGET_DIR`.
- Keep lookup at `${CRATE_DIR}/target/${CARGO_PROFILE_DIR}/${LIB_NAME}`.
- Document in a one-line comment that ambient `CARGO_TARGET_DIR` is overridden
  for staging reproducibility in validate worktrees.

**Verify**:

```bash
TMP_TARGET="$(mktemp -d)"
export CARGO_TARGET_DIR="${TMP_TARGET}"
# Should still produce/stage using crate-local --target-dir override, exit 0
# when bundles exist OR exit 0 with "no app/xpc bundle" in auto mode after a
# successful cargo build. Minimum bar without a full app build:
./scripts/stage-rust-audio-kernels.sh --mode on --configuration Debug
# Expect: either staged bundles, or failure only after dylib exists and bundles
# are missing — NEVER "expected artifact not found" while cargo succeeded.
unset CARGO_TARGET_DIR
test -f Native/AudioKernelsRust/target/debug/libaudio_kernels_rust.dylib
```

Add a small fixture under `scripts/tests/` that runs `cargo build` with a fake
`CARGO_TARGET_DIR` env and asserts the staging script’s resolution/override
logic (can stub `cargo` if needed for hermetic CI — prefer real cargo when
present, skip with explicit message if cargo missing).

### Step 2: Fix false `externalInputsMismatch` for gitignored Package.resolved

In `scripts/validate-agent.sh` `hash_external_gate_inputs` / committed
materialization:

**Required behavior:**

- Fingerprint must not treat “Package.resolved present in dirty checkout but
  absent in fresh worktree” as a semantic mismatch that disables reuse.
- Options (pick the smallest correct one; prefer A):
  - **A (preferred):** Only hash `Package.resolved` files when they are
    **tracked** by git (`git ls-files --error-unmatch`). Ignored local copies
    do not participate in checkout vs materialized comparison.
  - **B:** Before running the child validate in the worktree, copy any
    existing ignored `Package.resolved` from the original checkout into the
    same relative paths in the worktree (seed), then hash.
- Keep fail-closed reuse: if tracked lockfiles truly differ, mismatch remains.

After the fix, a committed validate where the only prior issue was ignored
Package.resolved should print **no** “Cache disabled: External gate inputs
differ…” solely for that reason, and should be able to reuse a PASS with the
same tree/toolchain fingerprint.

**Verify**: unit/fixture in `make workflow-test` that constructs two temp dirs /
simulates hashes OR runs `hash_external_gate_inputs` logic via a test harness.
Also:

```bash
make validate-agent ARGS="--lane auto --dry-run --committed --base origin/main --head HEAD --agent"
# Ensure dry-run still works; inspect that EXTERNAL mismatch is not spuriously set
# when only ignored Package.resolved differs.
```

### Step 3: Smarter committed validation path (reuse + optional in-place)

Improve `run_committed_tree` / pre-push interaction without weakening isolation:

1. **Reuse first:** With Step 2 fixed, when a developer already ran
   `validate-agent` on the same head tree + lane + toolchain, pre-push must
   reuse the fingerprinted PASS instead of rebuilding (~seconds, not minutes).
2. **In-place fast path (optional but recommended):** If all hold, skip creating
   a detached worktree and run materialized validation in the current checkout:
   - `HEAD` == `${HEAD_REF}` being validated
   - working tree clean for tracked files (`git diff --quiet` &&
     `git diff --cached --quiet`)
   - `VALIDATION_MODE=committed`
   - Still set `MA_VALIDATE_MATERIALIZED=1` and compute fingerprints the same way
   - If the tree is dirty, keep today’s detached worktree path (fail closed)
3. Update `scripts/hooks/pre-push` failure output to mention:
   - result JSON path
   - Rust staging / `CARGO_TARGET_DIR` hint only when the log contains the
     rust-audio artifact error
   - **Do not** suggest `SKIP_TESTS=1` as the primary remediation
   - May mention `PUSH_CHECK_VERBOSE=1` for full logs

**Verify**: extend `test_pre_push_protocol` / validate-runner reuse fixtures in
`scripts/tests/workflow-test.sh` to cover:
- clean HEAD in-place committed path (if implemented)
- dirty tree still uses worktree
- reuse hits after a synthetic PASS index entry with matching fingerprint

### Step 4: Scope-check large-delta intelligence (narrow)

In `scripts/scope-check.sh` `count_added_lines` (committed/staged/working):

- Exclude paths under `.agents/docs/archive/` from the added-line sum used for
  the “Large delta > 300” Full reason.
- Optionally also exclude pure renames already zeroed by git; no change needed
  if numstat is already 0.
- **Do not** remove Full escalation for `scripts/*`, Makefile, audio/data/security
  paths, or >8 Swift files.

**Verify**:

```bash
# Fixture or workflow-test case: a synthetic range that only adds files under
# .agents/docs/archive/ must NOT emit "Large delta detected" solely from those lines.
make workflow-test
```

### Step 5: Finish macos-app-engineering prune

1. Remove the six generic live references from the routed table in
   `macos-app-engineering-details.md` (and any SKILL links).
2. Move those files into
   `.agents/docs/archive/macos-app-engineering-references-2026-07-15/`
   (same archive dir as plan 085) if not already there; delete from
   `references/` live tree.
3. Keep `macos-app-engineering-details.md` as the only deep default reference
   (plus `SKILL.md` non-negotiables).
4. Target: live `references/` ≤ 2 files (`macos-app-engineering-details.md` and
   at most one Prisma-specific deep dive if truly needed — default is **1**).

**Verify**:

```bash
python3 - <<'PY'
from pathlib import Path
refs=list(Path('.agents/skills/macos-app-engineering/references').glob('*.md'))
assert [p.name for p in refs] == ['macos-app-engineering-details.md'] or len(refs) <= 2
text=Path('.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md').read_text()
for banned in ['concurrency-patterns.md','testing-debugging.md','swiftui-composition.md','design-system.md','appkit-integration.md','macos-polish.md']:
    assert banned not in text, banned
print('macos hot path pruned')
PY
make guidance-check
```

### Step 6: Hooks edge-case tests

Extend `scripts/tests/hooks-setup-test.sh` to assert:

1. Overwrite warning path: existing `core.hooksPath=custom-hooks` → becomes
   `scripts/hooks` when `MA_KEEP_HOOKS_PATH` unset.
2. Keep path: with `MA_KEEP_HOOKS_PATH=1`, custom hooksPath is preserved.

**Verify**: `bash scripts/tests/hooks-setup-test.sh` → `HOOKS_SETUP_TEST_STATUS=PASS`.

### Step 7: Guidance + Full validation

Update delivery-workflow details / build-and-test hooks section:

- Pre-push runs `validate-agent --committed` and reuses PASS fingerprints when
  external inputs are comparable.
- Rust staging is required in auto/on; do not document `MA_RUST_AUDIO_KERNELS_BUILD=off`
  as a routine push workaround (emergency only).
- Point at this plan’s failure mode (ambient `CARGO_TARGET_DIR`) as fixed.

Then:

```bash
make guidance-check
make workflow-test
make validate-agent ARGS="--lane full --no-reuse --agent"
# Committed gate without disabling Rust:
make validate-agent ARGS="--lane auto --committed --base origin/main --head HEAD --agent"
```

Both validate commands must PASS **without** `MA_RUST_AUDIO_KERNELS_BUILD=off`.

Update `plans/README.md`: mark 087 DONE; set next plan number to 088; note that
086’s push workaround is superseded by this fix.

## Test plan

- Extend `make workflow-test` with:
  - Rust target-dir override / artifact resolution fixture
  - external-input fingerprint ignored-Package.resolved case
  - committed reuse and/or in-place clean-HEAD path
  - archive path excluded from large-delta
  - hooks overwrite / keep edge cases
- No product XCTest changes required unless a tiny pure helper is extracted and
  already covered by workflow fixtures.

## Done criteria

- [ ] With ambient `CARGO_TARGET_DIR` set to a temp dir, staging no longer fails
      with “expected artifact not found” after a successful cargo build
- [ ] Committed validate does not set `externalInputsMismatch` solely because
      gitignored `Package.resolved` exists only in the checkout
- [ ] Compatible Full PASS can be reused on a subsequent committed validate /
      pre-push for the same head tree (demonstrate via workflow fixture or
      two-run evidence)
- [ ] `.agents/docs/archive/**` additions do not alone trigger “Large delta”
- [ ] Live macos-app-engineering refs pruned to ≤2 files; generics archived
- [ ] Hooks edge cases covered; `make workflow-test` PASS
- [ ] `make guidance-check` PASS
- [ ] `make validate-agent ARGS="--lane full --no-reuse --agent"` PASS
- [ ] `make validate-agent ARGS="--lane auto --committed --base origin/main --head HEAD --agent"` PASS without `MA_RUST_AUDIO_KERNELS_BUILD=off`
- [ ] `plans/README.md` updated

## STOP conditions

- Cargo/`cdylib` cannot be built on the executor machine even with `--target-dir`
  override — stop and report; do not paper over with default `off`.
- Fixing mismatch appears to require tracking `Package.resolved` in git — stop
  and ask; do not commit lockfiles without operator approval.
- In-place committed path cannot be proven equivalent to worktree isolation —
  ship Steps 1–2–4–5–6 without in-place, and document the deferral.
- Any change would skip Full validation for real `scripts/*` edits — stop.

## Maintenance notes

- Reviewers should reject reintroducing ambient-`CARGO_TARGET_DIR`-blind staging.
- If Cargo changes default artifact layout, update the probe list in the stage
  script and the workflow fixture together.
- Pre-push must remain a real gate; smarter reuse is not a bypass.
- Follow-up (out of scope): progressive-disclose `debugging-diagnostics`.
