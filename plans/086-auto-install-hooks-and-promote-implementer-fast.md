# Plan 086: Auto-install Git hooks and promote allowlisted implementer-fast

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3a1dfa3b..HEAD -- scripts/setup-dev-environment.sh Makefile scripts/hooks AGENTS.md .agents/skills/delivery-workflow .agents/docs/skill-routing.md .agents/docs/build-and-test.md plans/README.md plans/060-evaluate-lean-tools-fast-implementer.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/084-slim-always-on-agent-guidance-and-validation-loop.md
- **Category**: dx
- **Planned at**: commit `3a1dfa3b`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — hooks path changes developer safety nets; Fast-lane promotion changes agent routing
- **Rationale**: Touches `scripts/` and delivery policy; Full lane required. Not `implementer-fast` because the plan itself defines that profile's promotion rules.
- **Escalate when**: Hook install needs to mutate global git config outside the repo, or Fast promotion would require editing `~/.codex` agent tomls as a mandatory step for all developers.

## Why this matters

Two delivery inefficiencies remain after the lane-runner work (032/055/056) and
efficiency evals (058–060):

1. **Hooks are documented but not installed by `make setup`.** Tracked hooks live
   in `scripts/hooks` and require `git config core.hooksPath scripts/hooks`.
   Clones can silently use stale `.git/hooks` copies (this workspace even has
   `pre-push.disabled`), so agents and humans may skip the cheap pre-commit /
   exact-range pre-push contract.
2. **`implementer-fast` was measured cheaper with non-inferior quality on
   deterministic Fast work (plan 060 candidate), but project guidance still
   treats it as a rare explicit opt-in.** That leaves avoidable cost on
   docs/localization/guidance slices. Lean-code stays opt-in (060) and is
   **not** promoted here.

This plan makes hook installation part of `make setup`, and promotes
`implementer-fast` only for an explicit allowlist of Low/Fast deterministic
task classes — still refusing Medium/High/ambiguous work.

## Current state

- `scripts/setup-dev-environment.sh` verifies brew/Xcode and installs
  swiftlint/swiftformat, then exits — **no hooksPath step** (ends ~lines 91–102).
- Canonical hooks:
  - `scripts/hooks/pre-commit` — staged SwiftFormat/SwiftLint; `SKIP_LINT=1` bypass
  - `scripts/hooks/pre-push` — `make validate-agent ARGS="--lane auto --committed ..."`
- Docs tell humans to run manually:

```text
.agents/docs/build-and-test.md:217-219
git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/pre-commit ...
```

- Guidance still says Fast implementer is opt-in only:

```text
AGENTS.md (pre-084) / delivery-workflow/SKILL.md:50
implementer-fast is explicit opt-in for deterministic Low/Fast work only
.agents/docs/skill-routing.md:32
Deterministic Low/Fast change | Explicit opt-in to implementer-fast ...
```

- Plan 060 decision (keep lean opt-in; Fast limited to deterministic Fast-lane
  isolated worktrees) remains binding — this plan **narrowly promotes** Fast
  usage inside that envelope, and does **not** promote lean-code globally.

Evidence reminder (privacy-safe reports under `~/.codex/evals/reports`):
`implementer-fast` was a cost candidate vs single-control on measured Fast work;
do not invent new percentages in guidance — cite plan 060 / “measured candidate”.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Setup dry path | `./scripts/setup-dev-environment.sh` | exit 0; prints hooks configured/verified |
| HooksPath | `git config --local --get core.hooksPath` | `scripts/hooks` |
| Executable bits | `find scripts/hooks -maxdepth 1 -type f ! -perm -u+x -print` | empty |
| Guidance | `make guidance-check` | exit 0 |
| Workflow fixtures | `make workflow-test` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | exit 0 |

## Suggested executor toolkit

- `delivery-workflow` for Fast-lane / implementer policy text
- `project-standards` for AGENTS pointer hygiene after 084
- Do not edit global `~/.codex/agents/*.toml` unless the operator explicitly
  expands scope; prefer repository guidance that tells orchestrators when to
  select the existing Fast profile.

## Scope

**In scope**:

- `scripts/setup-dev-environment.sh`
- `Makefile` only if help text for `setup` should mention hooks (minimal)
- `.agents/docs/build-and-test.md` (hooks setup section → point at `make setup`)
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/delivery-workflow/references/delivery-workflow-details.md` (hooks notes only if needed)
- `.agents/docs/skill-routing.md`
- `AGENTS.md` (pointer-only updates after 084 slim; do not re-expand catalogs)
- `README.md` only if setup/hooks instructions are stale
- `scripts/tests/workflow-test.sh` and/or a small new fixture under `scripts/tests/` **if** needed to assert hooksPath configuration logic without requiring network/brew reinstall
- `plans/README.md`

**Out of scope**:

- Changing pre-commit/pre-push validation semantics (lint rules, lane selection, fingerprint reuse)
- Promoting lean-code / disabling plugins globally
- Rewriting `validate-agent.sh` / `scope-check.sh`
- Plan 085 skill pruning
- Force-pushing or rewriting git history
- Setting `core.hooksPath` globally (`--global`) — local repo config only

## Git workflow

- Branch: `chore/086-hooks-setup-and-fast-allowlist`
- Suggested commits:
  1. `chore(setup): configure core.hooksPath during make setup`
  2. `docs(delivery): allowlist implementer-fast for deterministic Low/Fast work`
- Do NOT push or open a PR unless asked.

## Steps

### Step 1: Teach `make setup` to configure tracked hooks

In `scripts/setup-dev-environment.sh`, after toolchain checks succeed and before the final “Next steps” banner, add a hooks section that:

1. Resolves `PROJECT_ROOT` (script already runs from repo context via Make; compute absolute path from `BASH_SOURCE` like other scripts).
2. Runs `git rev-parse --is-inside-work-tree` and fails clearly if not in a git worktree.
3. Sets **local** config only:
   `git config --local core.hooksPath scripts/hooks`
   (use a path relative to the repo root — matches current docs).
4. `chmod +x` on `scripts/hooks/pre-commit`, `scripts/hooks/pre-push`, and `scripts/hooks/first-commit-version-bump.sh`.
5. Verifies:
   - `git config --local --get core.hooksPath` equals `scripts/hooks`
   - no hook file lacks user execute bit
6. Prints a short OK line. If hooksPath was previously set to something else, print a warning and overwrite to `scripts/hooks` (repo policy), unless the operator set `MA_KEEP_HOOKS_PATH=1` — only add that escape hatch if overwriting would be unsafe in nested worktrees; default should enforce repo hooks.

Do not delete `.git/hooks/*`; with `core.hooksPath` set, Git ignores them.

Update `.agents/docs/build-and-test.md` Git Hooks Setup section to say:

```bash
make setup
# or explicitly:
git config --local core.hooksPath scripts/hooks
```

**Verify**:

```bash
./scripts/setup-dev-environment.sh
git config --local --get core.hooksPath
# expect: scripts/hooks
find scripts/hooks -maxdepth 1 -type f ! -perm -u+x -print
# expect: empty
```

### Step 2: Add a deterministic fixture for hooks configuration (preferred)

Extend `scripts/tests/workflow-test.sh` or add `scripts/tests/hooks-setup-test.sh` that:

- Uses a temporary git repo **or** invokes a extracted function/script path in a safe way
- Asserts that running the hooks-setup portion configures `core.hooksPath=scripts/hooks`

If extracting a function is cleaner, split a tiny helper
`scripts/lib/configure-git-hooks.sh` sourced by setup + test — keep it short.

Wire the test into `make workflow-test` if not auto-discovered.

**Verify**: `make workflow-test` → exit 0.

If a hermetic fixture is impractical without rewriting setup heavily, STOP and
report rather than shipping untested hook mutation — do not skip this lightly.

### Step 3: Promote allowlisted `implementer-fast` in project guidance

Update `delivery-workflow/SKILL.md` (and a short pointer in slim `AGENTS.md` +
`skill-routing.md`) to replace “explicit opt-in only” with:

**Default to `implementer-fast` when all of the following hold:**

1. Risk is Low and lane is Fast
2. Work is deterministic and fully specified (no product-behavior ambiguity)
3. Execution is in an isolated git worktree
4. Scope matches the allowlist:
   - docs/comments-only edits
   - localization key add/remove/symmetry with no behavior change
   - guidance-only `.agents` / `AGENTS.md` edits
   - constrained single-module non-functional refactor with explicit file list

**Still refuse / escalate to normal `implementer` when any hold:**

- Medium or High risk triggers (audio, concurrency, persistence, security, infra, broad diffs)
- Ambiguous acceptance criteria
- Public API / behavior changes
- Need for exploratory design or multi-skill invention
- Plan or user marked Medium/High / Full

State explicitly: **lean-code remains opt-in and is not a default** (plan 060).

Update `.agents/docs/skill-routing.md` Workflow Routing row from
“Explicit opt-in to `implementer-fast`” to “Allowlisted Low/Fast deterministic work → `implementer-fast`; otherwise normal implementer”.

Keep model identifiers out of project guidance (custom agent files own them).

**Verify**:

```bash
rg -n "implementer-fast|allowlist|lean-code" AGENTS.md .agents/skills/delivery-workflow/SKILL.md .agents/docs/skill-routing.md
python3 - <<'PY'
from pathlib import Path
texts = [
 Path('AGENTS.md').read_text(),
 Path('.agents/skills/delivery-workflow/SKILL.md').read_text(),
 Path('.agents/docs/skill-routing.md').read_text(),
]
joined = '\n'.join(texts)
assert 'allowlist' in joined.lower() or 'Allowlisted' in joined
assert 'lean' in joined.lower()  # still mentioned as not default
assert 'explicit opt-in for deterministic Low/Fast work only' not in joined
print('fast policy OK')
PY
make guidance-check
```

### Step 4: Full validation and ledger

```bash
make workflow-test
make validate-agent ARGS="--lane full --no-reuse --agent"
```

Update `plans/README.md`: mark 086 DONE; note that 060's “neither promoted globally” is superseded **only** for allowlisted Fast implementer usage inside the repo guidance, not for lean-code.

## Test plan

- New/extended workflow fixture covering hooksPath configuration (Step 2).
- `make guidance-check` for policy text/link validity.
- No product XCTest changes.

## Done criteria

- [ ] `make setup` / `./scripts/setup-dev-environment.sh` configures `core.hooksPath=scripts/hooks` and ensures hook executables
- [ ] Hook setup is covered by `make workflow-test`
- [ ] Docs no longer present manual hooksPath as the only path; `make setup` is primary
- [ ] `implementer-fast` is allowlisted default for deterministic Low/Fast classes; Medium/High still refused
- [ ] lean-code explicitly remains non-default
- [ ] `make guidance-check` exits 0
- [ ] `make workflow-test` exits 0
- [ ] `make validate-agent ARGS="--lane full --no-reuse --agent"` exits 0
- [ ] `plans/README.md` updated

## STOP conditions

- Configuring hooksPath breaks an intentional developer overlay that the operator needs — stop and introduce a documented escape hatch rather than forcing blindly.
- Plan 084 has not landed and `AGENTS.md` still hosts duplicated Fast recipes — stop and rebase onto 084 before editing pointers.
- Promoting Fast would require mandatory `~/.codex` edits for the repo to function — stop; keep guidance-only selection rules instead.
- Workflow fixture cannot hermetically test setup without network/brew side effects — stop and propose a extracted pure helper rather than weakening setup.

## Maintenance notes

- Reviewers should reject broadening the Fast allowlist to “any small PR”.
- If pre-push semantics change later, keep setup only responsible for wiring `core.hooksPath`, not for re-encoding gate policy.
- Re-run a small evaluator sample before widening allowlist beyond docs/l10n/guidance/non-functional single-module refactors.
- Stale `.git/hooks/pre-push.disabled` copies can remain; document that `hooksPath` makes them inert.
