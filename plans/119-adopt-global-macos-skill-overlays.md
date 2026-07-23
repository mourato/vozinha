# Plan 119: Adopt global macOS skills with the vozinha project overlay

> **Executor instructions**: This plan is guidance-only. Do not modify Swift,
> Makefile, scripts, packages, reports, or runtime artifacts. The global Plan
> 004 must be merged before this plan begins. The planned checkout currently
> has unrelated uncommitted changes; do not execute until those changes have
> been committed or otherwise reconciled by the maintainer.
>
> **Drift check (run first on a clean tree)**: `git diff --stat 256f1075..HEAD -- AGENTS.md .agents/skills .agents/overlays plans/README.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: global Plan 004; current guidance/rebrand work Plans 112–118 must be reconciled first
- **Category**: migration / dx / docs
- **Planned at**: commit `256f1075`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — serialize after the global bundle and current vozinha guidance batch
- **Reviewer required**: yes — this repository has the richest local routing and reference corpus
- **Rationale**: vozinha already documents global-skill overlays, but its long local copies contain Prisma-specific delivery, architecture, storage, audio, and Swift 6.2 rules that must be separated carefully.
- **Escalate when**: any current uncommitted change overlaps the planned files, or a global skill needs Prisma paths or command semantics.

## Why this matters

vozinha has 19 local skills and 14 auxiliary references. It is the most
operationally detailed repository in the set, but its shared macOS skills are
also the most heavily customized. This migration keeps Prisma/Vozinha rules
local while allowing portable macOS workflow guidance to evolve centrally.

## Current state

- `AGENTS.md:41-45` already defines precedence as `AGENTS.md`, then a project
  skill or a global skill plus named project overlay, then references.
- `AGENTS.md:85-91` makes `Makefile` authoritative and requires
  `make guidance-check` after guidance changes.
- Local copies of the seven global candidates are under
  `.agents/skills/{accessibility-audit,apple-design,code-quality,delivery-workflow,macos-app-engineering,menubar,swift-conventions}/`.
- Local specialist skills include `architecture`, `audio-realtime`,
  `benchmarking`, `intelligence-kernel`, `keychain-security`, and the local
  persistence/debugging/testing/documentation family. These must remain local
  in this plan.
- `project-standards` already states that global skills may load project
  overlays; this plan makes the file layout and routing concrete.

## Scope

**In scope**

- `AGENTS.md`
- `.agents/overlays/` with seven vozinha overlays
- `.agents/skills/project-standards/SKILL.md`
- retained local skills only where a cross-link to a migrated global skill must
  be changed
- deletion of only the seven duplicate local global-skill directories
- `plans/README.md` and this plan

**Out of scope**

- all Swift/package/source changes;
- `Makefile`, scripts, reports, storage docs, and release plans;
- `architecture`, `audio-realtime`, `benchmarking`, `intelligence-kernel`,
  `keychain-security`, `data-persistence`, `debugging-diagnostics`,
  `documentation`, `localization`, `testing-xctest`, or their references;
- model/provider settings or changes to the global configuration repository.

## Overlay contents

Each overlay must record only vozinha-specific facts:

- macOS 15 baseline and macOS 26 availability/fallback rules;
- Swift 6.2 strict-concurrency/default-isolation assumptions;
- `Packages/MeetingAssistantCore/Sources/` module ownership;
- `Makefile` as command authority and `make guidance-check` as the
  guidance-only gate;
- SwiftUI/AppKit lifecycle and menu-bar hotspots;
- local-first storage, Keychain, transcript/privacy boundaries, and the
  explicit absence of CloudKit synchronization;
- project terminology: Vozinha display brand, Prisma technical identifiers.

Do not move detailed persistence, audio, or intelligence-kernel rules into the
global overlays; link to the retained local specialist skill instead.

## Steps

### Step 1: Reconcile the dirty worktree and prerequisite

Before editing, inspect the current changes and wait until Plans 112–118 have
been deliberately committed/merged or the maintainer explicitly separates the
overlapping files. Then fast-forward `main`, verify the global Plan 004 merge,
and create:

```sh
git switch main
git pull --ff-only origin main
git switch -c chore/vozinha-global-skill-overlays
```

**Verify**: `git status --short --branch` → clean feature branch; no active
uncommitted files from the previous batch are carried into this branch.

### Step 2: Add overlays and update routing

Create seven files under `.agents/overlays/`. Update `AGENTS.md` to name each
global skill and its matching overlay. Update `project-standards` to state that
the overlay is a companion document, not a same-name replacement. Replace
relative links to deleted local copies with global names or retained local
specialist paths.

**Verify**: `rg -n "global:|project-overlay|\.agents/overlays|Prisma|Vozinha|CloudKit|macOS 15|Swift 6.2" AGENTS.md .agents/skills .agents/overlays` → project facts are confined to AGENTS/overlays/specialists and routing is explicit.

### Step 3: Remove only the seven duplicated local skills

Confirm all seven local directories contain only the shared skill copies and
not unique references required by a specialist. Delete those directories after
the overlay and routing changes are complete. Preserve all 14 auxiliary
reference files that belong to retained local specialists.

**Verify**: `find .agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort` → specialist skills remain; `find .agents/overlays -type f -name '*.md' | wc -l` → 7.

### Step 4: Run guidance validation

Run on the clean migration branch:

```sh
git diff --check
make guidance-check
make workflow-test
```

`make workflow-test` is required because this repository treats guidance and
validation routing as an executable workflow. Expected result: both targets
exit 0 and no source files are reported as changed.

### Step 5: Commit, push, merge, and clean up

Stage only `AGENTS.md`, `.agents/`, `plans/README.md`, and this plan. Commit:

```text
docs(agents): adopt global macos skill overlays
```

Push, open a PR against `main`, wait for required checks and review, then merge
through the protected-branch path. After verifying the merged PR and
`origin/main`, clean both local and remote branch state:

```sh
git switch main
git pull --ff-only origin main
git fetch origin --prune
git branch -d chore/vozinha-global-skill-overlays
git push origin --delete chore/vozinha-global-skill-overlays  # only if present
git worktree list
```

Do not delete any branch or worktree that contains the still-unmerged Plans
112–118 work.

## Test plan

- Seven overlays declare their global parent and vozinha project identity.
- No duplicate local `SKILL.md` remains for the seven global names.
- All retained specialist references resolve.
- `make guidance-check` passes.
- `make workflow-test` passes.
- `git diff --check` passes.

## Done criteria

- [ ] Global skill plus overlay precedence is explicit in `AGENTS.md`.
- [ ] Seven duplicate local skills are removed; specialist skills and references remain.
- [ ] `make guidance-check` and `make workflow-test` pass.
- [ ] No product source, Makefile, scripts, reports, or storage docs changed.
- [ ] Commit, push, PR review, merge, local cleanup, remote branch cleanup, and
      worktree cleanup are complete.
- [ ] Plan 119 is marked according to the active ledger convention.

## STOP conditions

- The worktree is not clean before branching.
- Plans 112–118 still have overlapping uncommitted files.
- The global prerequisite is absent or not discoverable.
- A specialist reference would break after duplicate deletion.
- `make guidance-check` or `make workflow-test` fails twice.
- A merge requires changing application source or bypassing protected-branch review.

## Maintenance notes

Keep Prisma-specific architecture, storage, audio, AI, and privacy guidance in
local specialists or overlays. Review the seven overlays whenever the Makefile,
module layout, deployment target, concurrency settings, or storage boundary
changes.
