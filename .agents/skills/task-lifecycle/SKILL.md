---
name: task-lifecycle
description: This skill should be used when the user asks to "run the task lifecycle", "classify risk lane", "prepare implementation workflow", or "enforce pre-merge gates".
---

# Universal Task Lifecycle

## Role

Use this skill as the canonical owner for macro task sequencing in Prisma.

- Own risk classification, lane selection, and lifecycle phases.
- Set the order of implementation, verification, review, and cleanup.
- Delegate concrete Git commands, validation commands, and review output to their specialist owners.

## Scope Boundaries

- This skill owns macro task sequencing (risk, lane, lifecycle phases).
- Use ../git-workflow/SKILL.md for detailed Git operations.
- Use ../quality-assurance/SKILL.md for verification strategy and command policy.
- Use ../code-review/SKILL.md for review findings format and severity ritual.

## When to Use

Use this skill when the task requires any of the following:

- Classifying task risk and selecting Fast vs Full lane
- Defining the required workflow before implementation starts
- Sequencing implementation, verification, review, and cleanup
- Resolving overlap between Git workflow, QA workflow, and code review workflow

This skill defines the **MANDATORY** operational standards for every coding task performed on this codebase.

The lifecycle is designed to guarantee:
- Risk-proportional quality gates
- Isolation via dedicated feature branches
- Reuse-first implementation decisions (`reuse -> extend -> create`) for logic and UI blocks
- Atomic commits (small, intention-revealing, buildable)
- A consistent local code review ritual before final push/merge
- Cleanup (branches, including remote when applicable)

Policy source:

- `AGENTS.md` is the source of truth.
- This skill operationalizes that policy and must stay aligned with it.
- `../quality-assurance/SKILL.md` owns concrete command mapping and must only use real `Makefile` targets.

## Phase 0: Risk Classification (Required)

Classify the task before implementation:

- **Low risk**: docs/comments-only, localization/resource text updates, or constrained non-functional refactors in one module.
- **Medium risk**: feature/bugfix in one subsystem, public API changes, UI behavior/state changes.
- **High risk**: audio pipeline, concurrency/actor isolation, persistence, security/permissions, cross-module architectural changes, or large deltas.

If uncertain, classify as the higher risk.

Lane selection:

- **Fast lane** for Low risk.
- **Full lane** for Medium/High risk.

## Command Mapping

Once risk is classified, apply lane gates through `../quality-assurance/SKILL.md`:

- **Fast lane merge gate**: `make scope-check`
- **Full lane merge gate**: `make build-test` + `make lint`

`make preflight` is optional comprehensive validation and does not replace lane merge gates.

## Phase 1: Task Initialization

Branch policy:

- **Full lane**: Use an isolated feature branch in the current checkout.
- **Fast lane**: Use a feature branch in the current checkout.

1. **Context Identification**: Analyze the task and identify the target files.
2. **Reusable Block Scan (required)**:
   - Search for existing logic/UI blocks that can satisfy the change (services, use cases, helpers, design-system components).
   - Apply the decision order: **reuse -> extend -> create**.
   - Create a new block only when the pattern is new in the project or existing blocks cannot be safely extended.
3. **Clarification & Confirmation (when needed)**:
   - If requirements are ambiguous, incomplete, or have high-impact trade-offs, ask concise confirmation questions before implementation.
   - This step is optional when the request is already specific enough and low-risk.
   - Do not assume behavior, scope, acceptance criteria, or destructive intent when uncertainty remains.
4. **Branching**: Create and switch to a fresh branch from `main`. Use `../git-workflow/SKILL.md` for concrete Git commands, naming, and cleanup expectations.

## Phase 2: Implementation Loop (Green + Atomic)

Language policy:

- Documentation must be written in **English**.
- Code comments must be written in **English**.


Work inside the selected lane context (feature branch in the current checkout).

Repeat the following loop until the task is complete:

1. **Implement a small, coherent slice**: Prefer incremental changes that follow the selected reusable-block strategy (`reuse`, `extend`, or `create`).
2. **Run proportional checks during development**:
   - Fast lane: staged lint/format plus scoped checks for touched files/subsystem.
   - Full lane: run scoped checks first, then the Full-lane merge gate at milestones when risk or churn justifies it.
   - Use `../quality-assurance/SKILL.md` for exact commands, escalation criteria, compact-mode targets, and scope-specific checks.
   - Keep the decision order consistent: targeted tests → narrow build → scope-specific checks → full gate.
   - If tests touch module internals, ensure the test target depends on that module explicitly in `Package.swift`.
3. **If verification fails**: Stop and fix before progressing.
4. **Atomic commit (green state)**:
   - Group changes by intent.
   - Use Conventional Commits.
   - Do not commit knowingly broken code.
5. **Documentation + limitation tracking**:
   - Update DocC when the change introduces new constraints or APIs.
   - If the change introduces a known limitation or intentional trade-off, create or update a GitHub issue via `gh` and use the `known-limitation` label.
   - Do not track limitations in a standalone markdown backlog file.

> Verify continuously, but keep hard gates at push/merge time to optimize cycle time.

## Phase 3: Local Code Review Ritual (Risk-based)

Before the final push/merge, perform a local review using **[code-review](../code-review/SKILL.md)**.

1. **Define the scope**: Review the commit list and files touched.
2. **Review depth by lane**:
   - Fast lane: lightweight checklist review is acceptable.
   - Full lane: semáforo table (🔴/🟡/🟢) is mandatory.
3. **Fix findings**:
   - Must fix **🔴 Critical** and **🟡 Medium**.
   - Fix **🟢 Low** when it clearly improves clarity/safety with low risk.
4. **Hard gate before push/merge**:
   - Fast lane minimum: the Fast-lane merge gate defined in `AGENTS.md` and mapped in `../quality-assurance/SKILL.md`.
   - Full lane minimum: the Full-lane merge gate defined in `AGENTS.md` and mapped in `../quality-assurance/SKILL.md`.
   - `make lint` remains mandatory for Full-lane changes.
   - `make preflight` is optional and useful as a final comprehensive pass.
   - Agent compact commands are for low-noise diagnostics and do not replace required merge gates.
5. **Atomic commits for review fixes**: Commit review-driven changes separately from feature work.

## Phase 4: Integration (Push / Merge)

1. **Push the branch** (for PR or collaboration):
   ```bash
   git push -u origin <branch-name>
   ```
2. **Merge into `main`** using the team’s preferred approach (PR or local merge).
    - If merging locally, return to `main` and merge:
     ```bash
       git checkout main
     git merge <branch-name>
     ```

## Phase 5: Cleanup (Mandatory)

Once the task is complete and verified:

1. **Delete local branch** (never delete `main`):
   ```bash
   git branch -D <branch-name>
   ```
2. **Delete remote branch (if it was pushed)**:
   ```bash
   git push origin --delete <branch-name>
   ```

## References

- **[git-workflow](../git-workflow/SKILL.md)**: Detailed commit and branching guidelines.
- **[quality-assurance](../quality-assurance/SKILL.md)**: Standards for testing and build verification.
- **[code-review](../code-review/SKILL.md)**: Mandatory pre-push review ritual and reporting format.
