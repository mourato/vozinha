# Plan 101: Remediate daily review findings

## Status

- **Priority**: P1
- **Effort**: M
- **Risk/lane**: High/Full
- **Depends on**: 098, 099, 100
- **Status**: IN PROGRESS

## Execution profile

- **Recommended profile**: `implementer`
- **Parallelizable**: no; one writer in the isolated worktree
- **Reviewer required**: yes; hook safety and accessibility behavior are merge-blocking
- **Escalate when**: the safe fix requires index-blob rewriting, a new focus abstraction, or changes outside the reviewed surfaces

## Objective

Close every finding from the 2026-07-16 review without rewriting history:

1. Fail the pre-commit hook before autofix when a staged Swift path also has unstaged changes, preserving both index and worktree; enumerate paths safely.
2. Add workflow fixtures for same-file partial staging and a Swift path containing spaces.
3. Keep the side-panel host pinned to the top safe area while transitioning only the fixed-width drawer, leaving the outside-dismiss layer spatially stable.
4. Remove the underlying Modes list, row actions, and Add control from keyboard and VoiceOver focus while the drawer is open; preserve deterministic initial and restored focus.
5. Align build guidance with Option C, remove plan 098 trailing whitespace, and validate the changed paths.

Plans 098 and 099 were marked `DONE` before their implementation commits. This follow-up records the review and enforces prospective ledger discipline; completed history is not rewritten.

## Reuse -> extend -> create

- **Reuse**: `SettingsMotion`, `SettingsSidePanel`, existing Modes focus bindings, and `ModeEditorDrawer`'s name-field focus owner.
- **Extend**: the existing pre-commit fixture, focus modifiers, and drawer accessibility focus.
- **Create**: only this plan and narrowly scoped test cases; no generic UI or hook abstraction.

## Acceptance criteria

- Partial staging fails clearly before file mutation; index and worktree bytes remain unchanged.
- Staged Swift files with spaces format, lint, and re-stage correctly.
- The dismiss layer never slides; normal motion moves only the drawer and Reduce Motion remains opacity-only.
- Opening the main editor focuses its Name field for keyboard and VoiceOver; closing restores the prior mode/Add target. Prompt-editor focus remains owned by its existing editor.
- The underlying list is VoiceOver-hidden and its row, Edit, Actions, and Add controls are excluded from keyboard focus while the drawer is presented, without visual dimming.
- `bash -n`, `make workflow-test`, focused Modes/AppleMotion/navigation tests, `make build-agent`, `make preview-check`, `make guidance-check`, and `git diff --check` are reported honestly.

## STOP conditions

- A required fix would weaken fail-closed linting, `SKIP_LINT` emergency semantics, or Full-lane validation.
- Focus containment requires replacing the canonical Modes navigation/focus owner.
- Validation reveals a new non-baseline regression outside this plan's scope.
