# Plan 084: Slim always-on guidance and unify the agent validation loop

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3a1dfa3b..HEAD -- AGENTS.md .agents/docs/skill-routing.md .agents/docs/build-and-test.md .agents/SKILLS_INDEX.md .agents/skills/SKILLS_TAXONOMY.md .agents/skills/delivery-workflow/SKILL.md .agents/skills/delivery-workflow/references/delivery-workflow-details.md scripts/validate-agent-guidance.py plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: dx / docs
- **Planned at**: commit `3a1dfa3b`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — always-on policy and guidance-check contract affect every agent session
- **Rationale**: Guidance-heavy, but `scripts/validate-agent-guidance.py` changes push this into Full. Ambiguity around what to keep in `AGENTS.md` needs careful judgment.
- **Escalate when**: Product Swift sources must change, or the guidance-check rewrite requires new schema beyond INDEX + skill-routing consistency.

## Why this matters

Cursor injects `AGENTS.md` on every turn (~1,375 words today). That file currently
duplicates risk lanes, Fast/Full recipes, `implementer-fast` policy (twice),
command catalogs, and hook sequencing already owned by `delivery-workflow` and
`.agents/docs/build-and-test.md`. Agents also load overlapping routers
(`skill-routing.md`, `SKILLS_INDEX.md`, `SKILLS_TAXONOMY.md`) and often re-run
`scope-check` plus `validate-agent` plus what hooks already enforce. This plan
cuts always-on tokens, collapses routing to one canonical surface, and makes the
agent validation loop explicit so agents stop paying for redundant gates.

This plan does **not** claim measured token savings; it only reduces static
guidance size and removes contradictory instructions. Cost claims remain owned
by the evaluator work from plans 058–060.

## Current state

- `AGENTS.md` (~160 lines) mixes hard constraints with delivery recipes:

```text
AGENTS.md:70-115  Risk and Delivery Lanes + Fast/Full recipes + iteration commands
AGENTS.md:96      implementer-fast opt-in (delegation)
AGENTS.md:103     implementer-fast again (plan execution)
AGENTS.md:117-127 Canonical command catalog
AGENTS.md:123     lists scope-check and validate-agent as peers
```

- Routing is triplicated:
  - `.agents/docs/skill-routing.md` — problem-specific routing (canonical intent)
  - `.agents/SKILLS_INDEX.md` — full table + "By Problem Type" duplicate (~100 lines)
  - `.agents/skills/SKILLS_TAXONOMY.md` — ownership matrix (~38 lines)
- `scripts/validate-agent-guidance.py:158-178` requires every local skill to appear
  in **both** INDEX and TAXONOMY.
- `delivery-workflow/SKILL.md` already owns lanes and `validate-agent`, but has no
  short "agent loop" that forbids re-running what hooks own.
- `.agents/docs/build-and-test.md:13` has a long agent-loop paragraph that still
  encourages dry-run + staged validate without saying "do not duplicate pre-push".

Exemplar for progressive disclosure already landed in plan 057:
`.agents/skills/delivery-workflow/SKILL.md` (slim) + routed references table.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Guidance | `make guidance-check` | exit 0, prints `Guidance validation passed.` |
| Word budget | `python3 - <<'PY'` (see Step 1 verify) | `AGENTS.md` words ≤ 900 |
| Routing refs | `rg -n "SKILLS_TAXONOMY" AGENTS.md .agents README.md scripts` | only archive pointer + validator history comments if any; no live requirement |
| Scope preview | `make validate-agent ARGS="--lane auto --dry-run --base main"` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | exit 0 (scripts changed) |
| Workflow fixtures | `make workflow-test` | exit 0 if validator/fixture surface changes require it; otherwise skip only if no `scripts/tests/` touch |

## Suggested executor toolkit

- Use `project-standards` for AGENTS/governance ownership.
- Use `delivery-workflow` when rewriting lane/validation loop text.
- Do not use product UI skills; this is guidance-only plus guidance-check script.

## Scope

**In scope**:

- `AGENTS.md`
- `.agents/docs/skill-routing.md`
- `.agents/docs/build-and-test.md`
- `.agents/SKILLS_INDEX.md`
- `.agents/skills/SKILLS_TAXONOMY.md` (move/archive, do not silently delete history)
- `.agents/docs/archive/` (create if missing; destination for taxonomy archive)
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/delivery-workflow/references/delivery-workflow-details.md` (only the Agent loop / scope-check vs validate-agent narrative sections — do not do the full details rewrite; that is plan 085)
- `scripts/validate-agent-guidance.py`
- `plans/README.md` (status row + dependency notes)
- `README.md` only if it currently points agents at TAXONOMY or duplicated routing; keep the edit minimal

**Out of scope**:

- Product Swift sources, tests, or Xcode project files
- Pruning `macos-app-engineering/references/` or splitting `menubar`/`localization` (plan 085)
- Hook install automation or `implementer-fast` default promotion (plan 086)
- Changing `scripts/validate-agent.sh` / `scripts/scope-check.sh` behavior
- Promoting lean-code profiles or editing `~/.codex` configs
- Claiming percentage token savings without a new evaluator run

## Git workflow

- Branch: `docs/084-slim-agent-guidance-loop`
- Conventional Commits, atomic by concern. Examples from this repo:
  - `docs(agents): slim always-on guidance and validation loop`
  - `chore(guidance): archive skills taxonomy and thin skill index`
- Do NOT push or open a PR unless the operator asks.

## Steps

### Step 1: Slim `AGENTS.md` to hard constraints + pointers

Rewrite `AGENTS.md` so it keeps:

1. Identity / project context / module ownership
2. Non-negotiable rules, Git safety, policy precedence, deviations
3. A **short** risk table (Low/Medium/High → Fast/Full) without Fast/Full recipe bullets
4. One short delegation paragraph (root-first; one writer; no model IDs in project guidance)
5. A compact **Agent validation loop** (5–8 lines max) that points to `delivery-workflow`
6. A short command pointer list (not a full catalog) linking `.agents/docs/build-and-test.md`
7. Skill routing pointer to **only** `.agents/docs/skill-routing.md`
8. Security / privacy + compressed self-check (≤5 bullets)

Remove or relocate (do not lose the policy — move ownership explicitly):

- Full Fast/Full merge-gate recipes → `delivery-workflow`
- Duplicate `implementer-fast` paragraphs → single pointer to `delivery-workflow` / plan 086 will refine defaults
- Long iteration command block that lists `scope-check-agent` as a peer of `validate-agent`
- Skill catalog enumeration that duplicates `skill-routing.md`

Hard constraints that must remain verbatim in spirit (wording may tighten, meaning must not weaken): secrets/Keychain, localization keys, concurrency/file-size rules, `reuse → extend → create`, no destructive git without authorization, precedence order, Full-lane review bar pointer.

**Verify**:

```bash
python3 - <<'PY'
from pathlib import Path
import re
text = Path('AGENTS.md').read_text()
words = len(re.findall(r'\S+', text))
print(f'words={words}')
assert words <= 900, words
assert 'skill-routing.md' in text
assert 'delivery-workflow' in text
assert text.count('implementer-fast') <= 1
assert 'SKILLS_TAXONOMY' not in text
print('AGENTS slim OK')
PY
```

→ prints `AGENTS slim OK` with `words=` ≤ 900.

### Step 2: Make `skill-routing.md` the only deep router; thin the INDEX; archive TAXONOMY

1. Ensure `.agents/docs/skill-routing.md` remains the canonical problem→skill router. If INDEX currently has unique routing prose under "By Problem Type", merge any non-duplicate unique sentences into `skill-routing.md`, then delete that duplicated section from INDEX.
2. Rewrite `.agents/SKILLS_INDEX.md` to:
   - one short intro pointing to `docs/skill-routing.md`
   - the skills table only (name, path, one-line trigger)
   - no second routing matrix
3. Move `.agents/skills/SKILLS_TAXONOMY.md` to
   `.agents/docs/archive/skills-taxonomy-2026-07-15.md` (create archive dir).
   Add a one-line header note: archived; live ownership lives in `skill-routing.md`.
4. Update any live links that pointed at `SKILLS_TAXONOMY.md` to the archive path or remove them if obsolete.

**Verify**:

```bash
test -f .agents/docs/archive/skills-taxonomy-2026-07-15.md
test ! -f .agents/skills/SKILLS_TAXONOMY.md
python3 - <<'PY'
from pathlib import Path
import re
idx = Path('.agents/SKILLS_INDEX.md').read_text()
assert 'skill-routing.md' in idx
# INDEX should not re-host a large "By Problem Type" section
assert '### By Problem Type' not in idx
words = len(re.findall(r'\S+', idx))
print(f'index_words={words}')
assert words <= 450, words
print('INDEX thin OK')
PY
```

### Step 3: Update `validate-agent-guidance.py` for the new catalog contract

Change `validate_skill_catalog()` so that:

- Every local skill directory with `SKILL.md` must appear in `.agents/SKILLS_INDEX.md`
- TAXONOMY is **no longer required**
- Optionally (preferred): every indexed local skill name should also appear at least once in `.agents/docs/skill-routing.md` (table or prose). If a skill is intentionally index-only meta noise, document the exception in a comment in the validator — but today all local skills should be routable.

Keep existing make-target and path-link checks.

**Verify**: `make guidance-check` → exit 0.

### Step 4: Add the canonical Agent validation loop to `delivery-workflow`

In `.agents/skills/delivery-workflow/SKILL.md`, add a section **Agent validation loop** (keep the skill under ~120 lines total if possible) with these rules, verbatim in meaning:

1. Prefer `make validate-agent ARGS="--lane auto --dry-run --base main"` **at most once** when the gate choice is unclear.
2. During iteration, run only the smallest changed-path check (`make build-agent`, focused tests, `make preview-check`, `make guidance-check`, etc.). Do **not** run Full `build-test` on every slice.
3. Before commit, run **one** `make validate-agent ARGS="--lane auto --staged --base main --agent"` when evidence is needed; otherwise rely on the staged pre-commit lint/format hook for Swift formatting.
4. Do **not** re-run the Full merge gate solely because a push is coming — the pre-push hook runs `validate-agent --committed` on the exact range and reuses compatible PASS fingerprints.
5. `make scope-check` / `scope-check-agent` are the **engine/preview** used internally by `validate-agent` and for ad-hoc changed-path mapping. Agents should treat `validate-agent` as the remembered command; do not run both “for safety”.
6. `SKIP_LINT=1` / `SKIP_TESTS=1` remain emergency bypasses only.

Update `.agents/docs/build-and-test.md` Quick Navigation agent-loop paragraph to match this shorter contract (replace the long sentence at line 13; do not expand the rest of the catalog unless links break).

If `delivery-workflow-details.md` still tells agents to run `scope-check` as the merge gate, fix that sentence to point at `validate-agent` — but do not rewrite the whole details file (plan 085).

**Verify**:

```bash
rg -n "Agent validation loop|do not run both|validate-agent" .agents/skills/delivery-workflow/SKILL.md .agents/docs/build-and-test.md
python3 - <<'PY'
from pathlib import Path
text = Path('.agents/skills/delivery-workflow/SKILL.md').read_text()
assert 'Agent validation loop' in text or '## Agent validation loop' in text
assert 'scope-check' in text  # may still mention as engine
assert 'validate-agent' in text
print('loop OK')
PY
make guidance-check
```

### Step 5: Cross-link hygiene and ledger update

1. Grep for stale TAXONOMY / duplicate routing instructions:

```bash
rg -n "SKILLS_TAXONOMY|By Problem Type|make scope-check\` as the merge|Before push/merge, run \`make scope-check" AGENTS.md .agents README.md || true
```

Fix remaining live guidance hits (archive file may still contain historical text).

2. Update `plans/README.md`: set this plan's status to DONE when finished; add dependency notes for 085/086; set next plan number to 087 if not already.

**Verify**: `make guidance-check` → exit 0; `git diff --check` → exit 0.

### Step 6: Full-lane validation

Because `scripts/validate-agent-guidance.py` changed:

```bash
make workflow-test
make validate-agent ARGS="--lane full --no-reuse --agent"
```

→ both exit 0.

If `workflow-test` has no coverage for guidance-check changes, still run it; do not skip Full validate-agent.

## Test plan

- No product XCTest changes.
- Treat `make guidance-check` as the primary regression test for catalog/routing consistency.
- After editing the validator, add a failing-case thought check manually: temporarily rename is unnecessary if `make guidance-check` passes against the live tree; do not leave broken fixtures.

## Done criteria

- [ ] `AGENTS.md` ≤ 900 words and contains ≤1 `implementer-fast` mention
- [ ] `.agents/skills/SKILLS_TAXONOMY.md` moved to `.agents/docs/archive/skills-taxonomy-2026-07-15.md`
- [ ] `.agents/SKILLS_INDEX.md` is table-first and ≤ 450 words
- [ ] `scripts/validate-agent-guidance.py` no longer requires TAXONOMY
- [ ] `delivery-workflow` documents the Agent validation loop and `validate-agent` as the remembered gate
- [ ] `make guidance-check` exits 0
- [ ] `make workflow-test` exits 0
- [ ] `make validate-agent ARGS="--lane full --no-reuse --agent"` exits 0
- [ ] No product source files modified (`git status` shows only guidance/script/plan paths)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Hard constraints would need to be weakened to hit the word budget — stop; raise the budget slightly rather than delete safety rules.
- `make guidance-check` fails because a skill cannot be represented in `skill-routing.md` without a larger routing redesign — stop and report.
- Product code appears to require edits for this plan — stop; this plan is guidance/script only.
- Full validate-agent fails on an unrelated baseline; record the baseline and stop rather than weakening gates.

## Maintenance notes

- Future skill additions must update INDEX + skill-routing; do not revive TAXONOMY as a live gate.
- Reviewers should reject PRs that re-expand `AGENTS.md` with command catalogs or Fast/Full recipes.
- Plan 086 may change `implementer-fast` from pure opt-in to allowlisted default; keep only a pointer in `AGENTS.md`.
- Plan 085 will finish delivery-workflow details progressive disclosure; avoid duplicating that rewrite here.
