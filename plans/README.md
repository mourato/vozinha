# Implementation Plans

This is the active plan ledger. The next available plan number is 112.

## Execution rules

- Read the complete plan and honor its STOP conditions.
- Keep one objective per execution slice and use `reuse -> extend -> create`.
- Respect dependencies and reclassify risk against the live scope.
- Preserve one writer in an explicitly isolated worktree.
- Run the plan's required lane, review, and validation before marking it done.
- Use atomic Conventional Commits; do not push unless requested.
- Keep product source out of guidance-only plans.

Status values: `TODO` | `IN PROGRESS` | `DONE` | `BLOCKED` | `REJECTED`.

## Active and current batch

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| [083](083-add-settings-form-visual-and-preview-gates.md) | Add route-wide visual evidence and truthful preview gates for Settings | P1 | M | 079, 080, 081, 082 | TODO |
| [102](102-close-fast-validation-gate.md) | Make Fast and guidance pushes pass a real technical gate | P0 | M | - | DONE |
| [103](103-align-auto-lane-with-risk-policy.md) | Make auto lane conservative for product Swift changes | P0 | M | 102 | DONE |
| [104](104-centralize-agent-routing-ownership.md) | Make `agent-ops` the single owner of delegation and profile selection | P1 | S | 103 | DONE |
| [105](105-prune-agent-operational-context.md) | Prune dead agent context and make guidance drift fail closed | P1 | L | 104 | DONE |
| [106](106-snapshot-mode-dictation-configuration.md) | Persist and snapshot dictation configuration per mode | P0 | L | - | DONE |
| [107](107-relocate-dictation-settings-into-mode-drawer.md) | Relocate Dictation settings into the mode drawer and retire the tab | P0 | L | 106 | DONE |
| [108](108-move-assistant-integrations-into-drawers.md) | Move Assistant and Integrations into Dictation Modes drawers | P0 | L | 107 | DONE |
| [109](archive/completed/109-promote-dictionary-and-add-vocabulary-workflow.md) | Promote Dictionary and add a separate vocabulary workflow | P1 | L | 108 | DONE |
| [110](archive/completed/110-wire-vocabulary-through-transcription.md) | Wire vocabulary snapshots through transcription and enhancement | P1 | L | 109 | DONE |
| [111](archive/completed/111-add-dictionary-quick-add-panel.md) | Add the VoiceInk-style Dictionary quick-add panel | P1 | L | 109 | DONE |

## Dependency order

The Settings reorganization batch is `106 -> 107 -> 108 -> 109`, followed by
runtime vocabulary integration in 110. Plan 111 also depends on 109 and can run
in parallel with 110 only in a separate isolated worktree after confirming that
the shared Dictionary service API is stable. The remediation batch is
`102 -> 103 -> 104 -> 105`. Plan 083 is independent.

## Archives

- [2026-07-12 ledger history](archive/2026-07-12-plan-ledger-history.md)
- [2026-07-16 ledger history](archive/2026-07-16-plan-ledger-history.md)
- [Completed plan files](archive/completed/)

## Current decisions

- Keep this root ledger active-only; archive completed batches with Git history.
- Keep `.agents/SKILLS_INDEX.md` as the single skill catalog.
- Keep exact-range technical validation fail closed; reuse only compatible PASS evidence.
- Store concrete provider/model/language and text-handling values per Dictation
  Mode, then snapshot the effective mode at recording start.
- Keep Dictionary data local-only; preserve Prisma's existing literal and empty
  substitution semantics while adding a separate vocabulary model.
- Use VoiceInk beta as a behavioral benchmark only; do not copy source or adopt
  its CloudKit persistence.
