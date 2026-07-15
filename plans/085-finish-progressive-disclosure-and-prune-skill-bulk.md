# Plan 085: Finish progressive disclosure and prune hot-path skill bulk

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 3a1dfa3b..HEAD -- .agents/skills/macos-app-engineering .agents/skills/delivery-workflow .agents/skills/menubar .agents/skills/localization .agents/docs/skill-routing.md .agents/SKILLS_INDEX.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/084-slim-always-on-agent-guidance-and-validation-loop.md
- **Category**: dx / docs
- **Planned at**: commit `3a1dfa3b`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `no` — one writer; large guidance rewrite needs serial review
- **Reviewer required**: `yes` — risk of deleting still-used Prisma guidance while pruning generic dumps
- **Rationale**: Guidance-only; no scripts/Makefile. Depends on 084 so INDEX/routing links stay coherent. Prefer normal implementer because prune decisions are judgment-heavy (not `implementer-fast`).
- **Escalate when**: A reference file believed "generic" turns out to be the only home of Prisma-specific rules that must move into product docs or another skill, or file count / ambiguity pushes beyond Fast comfort.

## Why this matters

Plan 057 slimmed several `SKILL.md` entrypoints, but hot-path bulk remains:

- `macos-app-engineering/references/` still holds ~11.8k lines across 24 files; most are unlinked generic Apple dumps, while `macos-app-engineering-details.md` still looks like a full skill (frontmatter + Role/When to Use) rather than a routed reference.
- `delivery-workflow/references/delivery-workflow-details.md` likewise still carries full skill frontmatter and Role/Scope/When to Use duplication.
- `menubar` (~295 lines) and `localization` (~171 lines) remain monolothic, so every trigger loads deep examples.

Agents that "open the details" still burn large input contexts. This plan finishes progressive disclosure for the hottest skills and deletes or archives unused reference bulk without removing Prisma-owned constraints.

## Current state

Measured at `3a1dfa3b`:

| Path | Observation |
|---|---|
| `.agents/skills/macos-app-engineering/SKILL.md` | Slim (~68 lines) with routed reference table pointing at `macos-app-engineering-details.md` |
| `.../references/macos-app-engineering-details.md` | Still has YAML frontmatter + Role/Scope/When to Use; contains the real Prisma Settings/UI rules |
| `.../references/*.md` | 24 files; only a minority are linked from the details "References" list; many (`document-apps`, `shoebox-apps`, `networking`, `project-scaffolding`, `app-extensions`, etc.) are unlinked |
| `delivery-workflow/references/delivery-workflow-details.md` | Starts with skill frontmatter + Role/Scope/When to Use; sections include Risk, Lifecycle, Git, Hooks |
| `menubar/SKILL.md` | Monolith with inline code samples for status item/popover |
| `localization/SKILL.md` | Monolith with Bundle.safeModule rules + locale hygiene |

Link census helper (run during recon; treat `????` as prune candidates unless content is uniquely Prisma-owned):

```bash
python3 - <<'PY'
from pathlib import Path
root = Path('.agents/skills/macos-app-engineering')
text = '\n'.join(p.read_text() for p in [root/'SKILL.md', root/'references'/'macos-app-engineering-details.md'])
for r in sorted((root/'references').glob('*.md')):
    print(('LINK' if r.name in text else 'ORPH'), r.name, sum(1 for _ in open(r)))
PY
```

Exemplar pattern to match (already good):
`.agents/skills/delivery-workflow/SKILL.md` — Role / Scope / When to Use / decision tables / **Routed references** table / Related Skills.

Hard constraints from `AGENTS.md` / `project-standards`: do not invent a root `docs/`; keep durable refs under `.agents/`; run `make guidance-check` after guidance edits; preserve meaning of non-negotiable rules when moving text.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Guidance | `make guidance-check` | exit 0 |
| Size report | see Step verifies | budgets below met |
| Link existence | `rg -n "references/" .agents/skills/macos-app-engineering .agents/skills/menubar .agents/skills/localization .agents/skills/delivery-workflow` | every referenced path exists |
| Diff hygiene | `git diff --check` | exit 0 |
| Lane preview | `make validate-agent ARGS="--lane auto --dry-run --base main"` | guidance-only / Fast strategy, exit 0 |
| Fast gate | `make validate-agent ARGS="--lane fast --agent"` | exit 0 |

## Suggested executor toolkit

- `macos-app-engineering` while pruning its own tree (preserve Settings Form / design-system constraints).
- `menubar` / `localization` while splitting those skills.
- `delivery-workflow` for details cleanup (do not reopen plan 084 loop text unless drift requires it).
- `project-standards` for skill template section order.

## Scope

**In scope**:

- `.agents/skills/macos-app-engineering/SKILL.md`
- `.agents/skills/macos-app-engineering/references/` (rewrite, move, or delete files)
- `.agents/docs/archive/` for archived generic reference dumps (dated folder ok)
- `.agents/skills/delivery-workflow/SKILL.md` (only if reference table/section names must change)
- `.agents/skills/delivery-workflow/references/delivery-workflow-details.md`
- `.agents/skills/menubar/SKILL.md` + new `menubar/references/`
- `.agents/skills/localization/SKILL.md` + new `localization/references/`
- `.agents/docs/skill-routing.md` / `.agents/SKILLS_INDEX.md` only if trigger blurbs must stay accurate
- `plans/README.md` status row

**Out of scope**:

- `AGENTS.md` always-on slim (plan 084)
- Hook setup / `implementer-fast` promotion (plan 086)
- Splitting `debugging-diagnostics` (optional follow-up; do not expand scope here)
- Editing product Swift, design-system source, or tests
- Global Codex config / lean profile promotion
- Rewriting `swiftui-pro` or `apple-design` trees

## Git workflow

- Branch: `docs/085-skill-hot-path-progressive-disclosure`
- Commits (suggested split):
  1. `docs(skills): prune macos-app-engineering reference bulk`
  2. `docs(skills): make delivery-workflow details reference-only`
  3. `docs(skills): progressive-disclose menubar and localization`
- Do NOT push or open a PR unless asked.

## Steps

### Step 1: Make `macos-app-engineering-details.md` a true reference

Rewrite `references/macos-app-engineering-details.md` so that:

- It has **no** YAML frontmatter
- It has **no** duplicate `Role` / `When to Use` / skill-ownership marketing sections
- It keeps Prisma-owned implementation guidance currently living there (Settings/`Form` patterns, design-system reuse, preview rules, AppKit bridge boundaries, UX direction that is Prisma-specific)
- Top of file is a short purpose line + a **Routed deeper references** table listing only files that still exist after pruning

Update `SKILL.md` routed table if section names change. Keep `SKILL.md` as the only place with Role / Scope / When to Use / Non-negotiable rules.

**Verify**:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md')
text = p.read_text()
assert not text.lstrip().startswith('---'), 'frontmatter must be removed'
assert '## Role' not in text
assert '## When to Use' not in text
print('details reference-only OK', sum(1 for _ in text.splitlines()))
PY
```

### Step 2: Prune or archive unused `macos-app-engineering` reference dumps

For each file under `references/` except `macos-app-engineering-details.md`:

1. If it is **not** linked from `SKILL.md` or `macos-app-engineering-details.md` after Step 1, move it to
   `.agents/docs/archive/macos-app-engineering-references-2026-07-15/<filename>`
   (or delete only if the archive already contains an identical copy — prefer move).
2. If it **is** linked but is generic Apple scaffolding with no Prisma-specific rules, either:
   - unlink it and archive it, folding any unique Prisma sentence into `macos-app-engineering-details.md`, or
   - keep it only when the details router truly needs that deep dive for Prisma work.
3. Prefer keeping at most a small set of deep refs that Prisma actually uses (likely candidates if they contain project-specific guidance: `design-system.md`, `swiftui-composition.md`, `appkit-integration.md`, `macos-polish.md`). Do not keep `document-apps`, `shoebox-apps`, `networking`, `project-scaffolding`, `app-extensions`, `cli-workflow`, `cli-observability`, `testing-tdd`, or similar unlinked generics without a written reason in the PR/commit body.

Target budgets after prune:

- `references/` live markdown files ≤ 8 (including details)
- total live reference lines ≤ 4,500

**Verify**:

```bash
python3 - <<'PY'
from pathlib import Path
refs = list(Path('.agents/skills/macos-app-engineering/references').glob('*.md'))
lines = sum(sum(1 for _ in open(p)) for p in refs)
print(f'files={len(refs)} lines={lines}')
assert len(refs) <= 8, len(refs)
assert lines <= 4500, lines
# no orphan links
text = '\n'.join(p.read_text() for p in [Path('.agents/skills/macos-app-engineering/SKILL.md'), *refs])
import re
for m in re.findall(r'references/([A-Za-z0-9_.-]+\.md)', text):
    assert (Path('.agents/skills/macos-app-engineering/references')/m).exists(), m
print('macos prune OK')
PY
```

### Step 3: Make `delivery-workflow-details.md` reference-only

Strip YAML frontmatter and duplicate Role/Scope/When to Use/Risk-table clones that already live in `SKILL.md`.

Keep task-specific sections aligned to the routed table in `SKILL.md`:

- Git workflow
- Scoped validation / practical commands
- Hook/troubleshooting / compact-mode notes
- Preflight / deliverable-gate guidance

Preserve the Agent validation loop meaning introduced in plan 084 (do not regress to “run scope-check as merge gate”).

**Verify**:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('.agents/skills/delivery-workflow/references/delivery-workflow-details.md')
text = p.read_text()
assert not text.lstrip().startswith('---')
assert '## Role' not in text
assert '## When to Use' not in text
assert 'validate-agent' in text
print('delivery details OK')
PY
```

### Step 4: Progressive-disclose `menubar`

Split `.agents/skills/menubar/SKILL.md` into:

- `SKILL.md` (target ≤ 100 lines): Role, Scope Boundary, When to Use, non-negotiables (right-click menu vs left-click popover, non-activating panels, lifecycle ownership), routed references table, Related Skills
- `references/menubar-patterns.md` (or similarly named): code samples and deep interaction patterns currently inline

Do not change product meaning of menu-bar guidance; only relocate deep examples.

**Verify**:

```bash
python3 - <<'PY'
from pathlib import Path
skill = Path('.agents/skills/menubar/SKILL.md').read_text()
assert '## Role' in skill and '## When to Use' in skill
assert 'references/' in skill
lines = sum(1 for _ in skill.splitlines())
print('menubar_skill_lines', lines)
assert lines <= 100, lines
refs = list(Path('.agents/skills/menubar/references').glob('*.md'))
assert refs, 'expected references/'
print('menubar split OK')
PY
```

### Step 5: Progressive-disclose `localization`

Same pattern as menubar:

- `SKILL.md` (target ≤ 90 lines): Role, Scope, When to Use, hard rules (`"key".localized`, locale symmetry en/pt, no feature-local bundle helpers, orphan key cleanup), routed references table
- `references/localization-patterns.md`: extended examples, accessibility-copy key patterns, checklist detail

Preserve the critical `Bundle.safeModule` rule in the SKILL entrypoint (not only in the reference).

**Verify**:

```bash
python3 - <<'PY'
from pathlib import Path
skill = Path('.agents/skills/localization/SKILL.md').read_text()
assert 'Bundle.safeModule' in skill or 'safeModule' in skill
assert '.localized' in skill
assert 'references/' in skill
lines = sum(1 for _ in skill.splitlines())
print('localization_skill_lines', lines)
assert lines <= 90, lines
assert list(Path('.agents/skills/localization/references').glob('*.md'))
print('localization split OK')
PY
```

### Step 6: Guidance validation and ledger

```bash
make guidance-check
make validate-agent ARGS="--lane auto --dry-run --base main"
make validate-agent ARGS="--lane fast --agent"
git diff --check
```

Update `plans/README.md` status for 085 to DONE when complete.

## Test plan

- Guidance-only: `make guidance-check` is the regression suite.
- Manually spot-check that Settings Form picker guidance and `Bundle.safeModule` remain reachable from the slim entrypoints (not only buried in archived dumps).
- No XCTest changes.

## Done criteria

- [ ] `macos-app-engineering-details.md` has no frontmatter and no Role/When to Use sections
- [ ] Live `macos-app-engineering/references/` ≤ 8 files and ≤ 4,500 lines
- [ ] Orphaned generic refs archived under `.agents/docs/archive/macos-app-engineering-references-2026-07-15/` (or equivalent dated path)
- [ ] `delivery-workflow-details.md` is reference-only (no frontmatter / Role / When to Use)
- [ ] `menubar/SKILL.md` ≤ 100 lines with `references/`
- [ ] `localization/SKILL.md` ≤ 90 lines with `references/` and `safeModule` retained in SKILL
- [ ] `make guidance-check` exits 0
- [ ] `make validate-agent ARGS="--lane fast --agent"` exits 0
- [ ] No product source modifications
- [ ] `plans/README.md` status updated

## STOP conditions

- Pruning would remove the only copy of a Prisma-specific Settings/Form/design-system rule — stop and fold that rule into `macos-app-engineering-details.md` or `SKILL.md` before archiving.
- Plan 084 has not landed and INDEX/TAXONOMY/link expectations still conflict — stop and rebase onto 084 first.
- `make guidance-check` fails on broken relative links after the split — fix links; if the failure is an unrelated baseline, report it.
- Scope creeps into `debugging-diagnostics` or `swiftui-pro` rewrites — stop; file a follow-up plan instead.

## Maintenance notes

- New deep macOS notes belong in a routed reference, never back into always-loaded `SKILL.md` prose walls.
- Reviewers should reject reintroduction of unlinked generic Apple dumps into `macos-app-engineering/references/`.
- If `menu-bar-apps.md` under macos-app-engineering overlaps `menubar` skill, prefer `menubar` as owner and avoid duplicated samples.
- Optional follow-up (not this plan): progressive-disclose `debugging-diagnostics`.
