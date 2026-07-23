# Implementation Plans

This is the active plan ledger. The next available plan number is 119.

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
| [112](112-rebrand-visible-app-name-to-vozinha.md) | Rebrand the visible app name to Vozinha | P1 | L | - | IN PROGRESS |
| [113](113-interactive-release-build-and-install-runner.md) | Add an interactive Release-aware build and install runner | P1 | L | 112 | IN PROGRESS |
| [114](114-prune-dated-agent-guidance.md) | Prune dated agent guidance without losing durable rules | P0 | M | 105 | DONE |
| [115](115-promote-localization-integrity-gate.md) | Promote localization integrity to a deterministic gate | P0 | M | 102 | DONE |
| [116](116-reuse-scope-check-decision.md) | Reuse the scope-check decision in agent validation | P1 | S | 103 | DONE |
| [117](117-cache-agent-swiftpm-resolution.md) | Cache agent SwiftPM resolution safely | P1 | M | 102 | DONE |
| [118](118-report-first-agent-artifact-cleanup.md) | Add report-first cleanup for agent build artifacts | P2 | M | 102 | DONE |
| [119](119-adopt-global-macos-skill-overlays.md) | Adopt global macOS skills with the vozinha project overlay | P1 | M | global plan 004; 112–118 reconciled | TODO |

## Dependency order

The Settings reorganization batch is `106 -> 107 -> 108 -> 109`, followed by
runtime vocabulary integration in 110. Plan 111 also depends on 109 and can run
in parallel with 110 only in a separate isolated worktree after confirming that
the shared Dictionary service API is stable. The remediation batch is
`102 -> 103 -> 104 -> 105`. Plan 083 is independent.

Plan 112 is independent of the Settings reorganization batch, but must remain a
single coordinated workstream because it changes shared build, runtime, and
release identity values. It intentionally preserves `com.mourato.prisma`, the
XPC identifier, storage directories, Keychain service, UserDefaults domains,
and `MeetingAssistant*` internal names.

Plan 113 depends on the Release-visible identity from Plan 112. It adds the
interactive Debug/Release runner, installs only Release into the exact
`/Applications/Vozinha.app` target, and must preserve the technical identity
contract from Plan 112. Its AppKit shutdown route and filesystem replacement
transaction are one serial workstream; do not parallelize them.

Plans 114 through 118 are the agent-cost and delivery-automation batch. Plan
114 is guidance-only and should run before routing changes. Plans 115, 116, and
117 are validation infrastructure and should be implemented as separate serial
workstreams. Plan 118 is report-first and must not delete artifacts until its
allowlist and dry-run evidence are accepted. Skill selection otherwise remains
 semantic and follows the standard skill descriptions and project guidance.

## Archives

- [2026-07-12 ledger history](archive/2026-07-12-plan-ledger-history.md)
- [2026-07-16 ledger history](archive/2026-07-16-plan-ledger-history.md)
- [Completed plan files](archive/completed/)

## Current decisions

- Keep this root ledger active-only; archive completed batches with Git history.
- Keep `AGENTS.md`, the skill descriptions, and the routing guide as the
  sources of truth for agent guidance.
- Keep exact-range technical validation fail closed; reuse only compatible PASS evidence.
- Store concrete provider/model/language and text-handling values per Dictation
  Mode, then snapshot the effective mode at recording start.
- Keep Dictionary data local-only; preserve Prisma's existing literal and empty
  substitution semantics while adding a separate vocabulary model.
- Use VoiceInk beta as a behavioral benchmark only; do not copy source or adopt
  its CloudKit persistence.
- Prefer deterministic scripts and Make gates for repeatable checks; keep model
  reasoning for ambiguity, design judgment, and user-facing decisions.
- Treat token or time savings as hypotheses until a later measurement pass
  confirms them; these plans intentionally do not require manual usage tables.

Plan 119 is a guidance-only migration. It must wait until the global macOS
skill bundle is merged and the currently dirty 112–118 work is reconciled. It
preserves vozinha/Prisma specialist skills and moves only the seven shared
macOS skill copies to project overlays.
