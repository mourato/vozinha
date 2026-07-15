# Implementation Plans

This is the active plan ledger. Historical audits, completed plan rows, review
notes, and rejected options remain in the [2026-07-12 ledger archive](archive/2026-07-12-plan-ledger-history.md).
Plan files are never renumbered; the next available plan number is 098.

## Execution rules

- Read the complete plan before implementation and honor its STOP conditions.
- Keep one objective per execution slice and preserve the repository's
  `reuse -> extend -> create` decision.
- Respect dependencies and execute plans in ledger order when a sequence is
  requested.
- Classify risk and run the lane required by the plan. Infrastructure,
  concurrency, persistence, security, audio, and broad changes use Full.
- Update the status row after implementation, review, and required validation.
- Use atomic Conventional Commits. Do not push or open a PR unless requested.
- Guidance-only plans must not modify product source.
- Global `~/.codex` plans require a dedicated configuration task, operator-
  approved rollback copies, privacy-safe artifacts, and explicit stop conditions.

Status values: `TODO` | `IN PROGRESS` | `DONE` | `BLOCKED` (with a one-line
reason) | `REJECTED` (with a one-line rationale).

## Active and recent plans

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| [040](040-migrate-ui-observation-boundaries.md) | Migrate UI state to Observation at stable boundaries | P1 | L | 039 | DONE |
| [055](055-harden-scoped-validation-artifacts.md) | Make scoped validation correct for committed diffs and safe under parallel agents | P1 | M | 032 | DONE |
| [056](056-create-canonical-lane-runner.md) | Provide one canonical lane runner with safe evidence reuse | P1 | L | 055 | DONE |
| [057](057-reduce-agent-guidance-context.md) | Reduce recurring agent context through an active ledger and routed skill references | P1 | M | - | DONE |
| [058](058-build-global-agent-efficiency-evaluator.md) | Build a global agent-efficiency evaluator with model-attributed cost | P1 | L | - | DONE (54 controlled runs; 100% segment attribution; API-equivalent estimates) |
| [059](059-tune-global-agent-routing.md) | Tune global routing and root reasoning from controlled cost-quality evidence | P1 | M | 058 | DONE (medium beat high on cost/latency; defaults remain unchanged) |
| [060](060-evaluate-lean-tools-fast-implementer.md) | Evaluate a lean code profile and a Fast-lane implementer before enabling either | P2 | M | 058, 059 | DONE (lean/Fast candidates measured; neither promoted globally) |
| [061](061-add-selected-text-at-dictation-start-context.md) | Add opt-in selected-text-at-start context for dictation | P1 | L | - | DONE (implemented; Full runner marked incomplete despite 1,002/1,002 tests passing because of CoreData/XPC diagnostics) |
| [062](062-centralize-dictation-post-processing-in-modes.md) | Centralize dictation post-processing in modes | P1 | L | 061 | DONE |
| [063](063-resolve-post-processing-by-dictation-mode.md) | Resolve post-processing by dictation mode | P1 | L | 062 | DONE |
| [064](064-remove-user-prompts-and-system-prompt-settings-surface.md) | Remove user-prompts and system-prompt settings surface | P1 | M | 062, 063 | DONE |
| [065](065-add-friendly-mode-icons-and-emoji.md) | Add friendly mode icons and emoji | P1 | M | 062, 064 | DONE |
| [066](066-move-dictation-mode-editor-to-detail-panel.md) | Move dictation-mode editing from a sheet to a settings detail panel | P1 | L | - | DONE |
| [067](067-redesign-mode-trigger-search-and-selection.md) | Redesign mode trigger search, selection, and removal | P1 | L | 066 | DONE |
| [068](068-add-mode-instruction-drilldown-and-narrow-layout.md) | Add instruction drill-down and compact mode settings layout | P1 | M | 066, 067 | DONE |
| [069](069-establish-settings-content-surface-contract.md) | Establish a shared settings content-surface contract | P1 | M | - | DONE |
| [070](070-build-modes-secondary-sidebar-editor.md) | Build the Modes secondary-sidebar editor | P1 | L | 069 | DONE |
| [071](071-normalize-fluid-settings-groups.md) | Normalize fluid configuration groups and responsive rows | P1 | L | 069 | DONE |
| [072](072-align-mode-trigger-flow-with-voiceink-reference.md) | Align the mode trigger flow with the VoiceInk reference | P2 | M | 070, 071 | DONE |
| [073](073-harden-settings-safe-area-contract.md) | Harden the settings safe-area contract | P1 | M | - | DONE |
| [074](074-make-modes-pane-native-and-responsive.md) | Make the Modes editor pane native and responsive | P1 | L | 073 | DONE |
| [075](075-add-interruptible-modes-pane-transitions.md) | Add interruptible Modes pane transitions | P1 | M | 074 | DONE |
| [076](076-harden-editor-interaction-accessibility.md) | Harden editor interaction safety and accessibility | P2 | M | 074 | DONE |
| [077](077-add-typography-and-visual-validation-matrix.md) | Add typography and visual validation coverage | P3 | M | 073, 074, 075, 076 | DONE |
| [078](078-match-voiceink-mode-editor-drawer-experience.md) | Replace the Modes split view with the VoiceInk-style editor drawer experience | P1 | L | - | DONE (merged in `a9a86350`; implementation commits include `d2c45d00`) |
| [079](079-establish-single-form-settings-surface.md) | Establish one full-width native Form surface per settings page | P1 | M | - | DONE |
| [080](080-migrate-primary-settings-journeys-to-form-sections.md) | Migrate primary settings journeys to shared native Form sections | P1 | L | 079 | DONE |
| [081](081-migrate-system-settings-hierarchy-to-form-sections.md) | Migrate the complete System settings hierarchy to native Form sections | P1 | L | 079 | DONE |
| [082](082-retire-form-islands-and-normalize-specialized-settings-surfaces.md) | Retire per-group Form islands and normalize specialized settings surfaces | P2 | M | 080, 081 | DONE |
| [083](083-add-settings-form-visual-and-preview-gates.md) | Add route-wide visual evidence and truthful preview gates for Settings | P1 | M | 079, 080, 081, 082 | TODO |
| [084](084-slim-always-on-agent-guidance-and-validation-loop.md) | Slim always-on guidance, collapse skill routing, and unify the agent validation loop | P1 | M | - | DONE |
| [085](085-finish-progressive-disclosure-and-prune-skill-bulk.md) | Finish progressive disclosure and prune hot-path skill reference bulk | P1 | L | 084 | DONE |
| [086](086-auto-install-hooks-and-promote-implementer-fast.md) | Auto-install Git hooks via setup and promote allowlisted implementer-fast | P1 | M | 084 | DONE |
| [087](087-fix-pre-push-reliability-and-agent-ops-followups.md) | Fix pre-push reliability (Rust staging + reuse) and finish agent-ops follow-ups | P1 | L | 084, 085, 086 | DONE |
| [088](088-optimize-macos-ui-swift-skills-cluster.md) | Optimize macOS UI / Apple design / Swift skills cluster (fold swiftui-pro; slim apple-design) | P1 | M | 028, 084, 085 | DONE |
| [089](089-slim-agent-validation-loop-and-pass-reuse.md) | Slim agent validation loop and align clean-tree PASS reuse with pre-push | P1 | M | 087 | DONE |
| [090](090-restore-immediate-settings-switches-and-document-boolean-control-rule.md) | Restore immediate-effect settings switches and document the boolean-control rule | P1 | M | - | DONE |
| [091](091-remove-empty-meeting-transcription-form-row.md) | Remove the empty Meeting Transcription Form row before Pyannote | P1 | S | - | DONE |
| [092](092-align-activity-index-with-settings-form-visual-contract.md) | Align Activity index groups with the Settings Form visual contract | P1 | M | - | DONE |
| [093](093-establish-settings-flatten-ia-and-expandable-row.md) | Establish Settings flatten IA contract and ExpandableSettingsRow | P1 | M | 079–082 (DONE) | DONE |
| [094](094-flatten-meetings-into-single-form-page.md) | Flatten Meetings into a single Form page | P1 | L | 093 | DONE |
| [095](095-flatten-system-settings-onto-general.md) | Flatten System settings hierarchy onto General | P1 | L | 093 | DONE |
| [096](096-flatten-activity-drilldowns-to-sheets.md) | Flatten Activity drill-downs to sheets; localize History chrome | P1 | L | 093 | TODO |
| [097](097-retire-settings-toolbar-navigation-chrome.md) | Retire Settings toolbar back/forward navigation chrome | P1 | M | 094, 095, 096 | TODO |

Plans 001–061 are completed or archived in the historical ledger. The archive preserves the original audit scope,
findings, dependency history, status table, committee notes, and rejected
options verbatim for searchability.

## Active dependency notes

- 040 remains a measured, boundary-by-boundary migration and must not become a
  repository-wide mechanical conversion.
- 055 established the base-aware diff snapshot and immutable run-tree contract.
- 056 owns final validation-evidence reuse; uncertainty must fail closed and
  execute a fresh gate.
- 057 may reduce static guidance size, but must not claim token/cost savings
  without the controlled evaluator from 058.
- 058 completed 54 controlled runs across six tasks and three scenarios; the
  privacy-safe reports remain under `~/.codex/evals/reports`.
- 059 supports medium root effort over high for this workload, but global
  defaults were deliberately not changed during measurement.
- 060 found lean and Fast candidates; keep lean opt-in until artifact/browser
  smoke coverage is added, and keep Fast limited to deterministic Fast-lane
  work in isolated worktrees.
- 061 is a cross-module dictation-context feature; preserve the current
  prompt/context-hardening worktree changes before implementation and keep the
  new source opt-in false unless product explicitly changes the privacy default.
- 066 must land before 067 and 068 because both child drill-downs depend on the
  editor owning an explicit detail route rather than a modal boolean.
- 067 preserves the existing one-target-per-mode invariant and runtime matching;
  it changes only the search/selection surface.
- 068 keeps all current persisted mode settings and routes new instruction text
  through a child detail view.
- 069 establishes the shared safe-area, gutter, scrolling, and background
  contract before any drawer work.
- 070 depends on 069 and owns the native Modes secondary pane, drawer header,
  child-route integration, and fixed editor footer.
- 071 depends on 069 and owns the full-width group contract and responsive rows;
  it must not invent a second navigation shell.
- 072 depends on 070 and 071 and refines only apps/sites trigger presentation
  while preserving target identity, exclusivity, and runtime matching.
- 073 hardens the shared safe-area and chrome contract before the Modes pane is
  restructured.
- 074 depends on 073 and owns native secondary-pane behavior, empty-pane policy,
  and responsive list/editor sizing.
- 075 depends on 074 and owns only pane transitions, spatial continuity, and
  Reduce Motion behavior.
- 076 depends on 074 and owns destructive-action confirmation, button labels,
  focus, keyboard, and VoiceOver behavior.
- 077 runs last because it validates the combined surface and owns final
  typography and preview-matrix adjustments.
- 078 supersedes the completed presentation decisions in 066–077 after the
  exact VoiceInk `v2.0-beta.2` reference showed that the target interaction is
  a 400 pt trailing overlay, not a nested split/detail column. Preserve the
  valid draft, persistence, privacy, localization, delete-confirmation, and
  accessibility work from those plans while replacing the presentation,
  hierarchy, trigger route, and visual-validation contract.
- 079 replaces the per-group, scroll-disabled Form island introduced by the
  first migration with the shared one-Form-per-page surface contract.
- 080 and 081 both depend on 079 and are logically independent, but must be
  executed serially because repository policy permits only one writing agent.
- 080 owns Dictation, Meetings, Assistant, Integrations, and their nested
  settings flows; 081 owns the complete System root/detail hierarchy.
- 082 runs after both migrations to delete `SettingsFormGroup`, audit every
  remaining group primitive, and preserve intentional collection/status/data
  surfaces without mechanically forcing them into Form.
- 083 runs last because it validates the combined route matrix and changes
  preview tooling under `scripts/`, which requires the Full lane.
- 084 is the agent-ops guidance diet: slim always-on `AGENTS.md`, archive live
  `SKILLS_TAXONOMY` requirements, thin `SKILLS_INDEX`, and make `validate-agent`
  the remembered gate with an explicit no-redundant-hook-replay loop. It must
  land before 085/086 so routing links and Fast pointers stay coherent.
- 085 depends on 084 and owns hot-path skill bulk only: prune/archive unused
  `macos-app-engineering` references, make delivery/macos details reference-only,
  and progressive-disclose `menubar` + `localization`. Guidance-only / Fast lane.
- 086 depends on 084 and owns setup-time `core.hooksPath` installation plus an
  allowlisted `implementer-fast` default for deterministic Low/Fast work. It does
  **not** promote lean-code. Plan 060's "neither promoted globally" is superseded
  **only** for allowlisted Fast implementer usage in repo guidance, not lean-code.
  Scripts change ⇒ Full lane.
- 084 → 085 → (086 can proceed after 084 in parallel with 085 only if two writers
  are forbidden by policy; default serial order is 084, then 085, then 086).
- 087 follows 084–086 review + the failed pre-push of `3a1dfa3b..9e006e07`.
  It must fix Rust dylib discovery under ambient `CARGO_TARGET_DIR`, stop false
  `externalInputsMismatch` from gitignored `Package.resolved`, restore PASS
  reuse on push, finish pruning linked generic macos refs, and extend hooks
  fixtures. Full lane; do not normalize `MA_RUST_AUDIO_KERNELS_BUILD=off`.
  Plan 086's `MA_RUST_AUDIO_KERNELS_BUILD=off` push workaround is superseded by
  crate-local Cargo target pinning in 087.
- 088 re-audits the macOS UI / Apple design / Swift guidance cluster after
  `apple-design` and `swiftui-pro` were added post–plan 028. Default path folds
  `swiftui-pro` into a MAE review appendix and slims `apple-design`; it does not
  reopen merging `swift-conventions` with `code-quality`. Low-utility
  `.agents/docs/archive/` trees (taxonomy dump, MAE generic refs, retired
  `swiftui-pro`) are deleted rather than retained for recovery.
- 089 depends on 087 and removes the remaining agent-ops tax: omit
  `workingState` from fingerprints on clean trees so working-tree PASS reuses
  into `--committed`/pre-push, and rewrite guidance so Low/Fast defaults to
  check → commit → push without stacked dry-run/staged/Full.
- 090 restores save-semantics boolean controls after the Form migration
  incorrectly applied checkboxes to immediate Settings pages; it also elevates
  the rule in `macos-app-engineering`. Independent of 091/092.
- 091 removes the bare `Divider()` empty Form row in Meeting Transcription
  (Pyannote). Low/Fast; independent of 090/092.
- 092 narrows plan 082’s Activity exception: the Activity **index** adopts
  `SettingsFormPage` chrome for visual parity, while analytics child routes
  (More Insights, Performance, History) remain specialized. Independent of
  090/091 content-wise; serialize writers per repo policy.
- **B2 Settings flatten (093–097)** aggressively reduces *navigation* hierarchy
  (subpages + global toolbar back/forward), inspired by VoiceInk `v2.0-beta.2`
  expandable rows / sheets / side panels. Execute **093 → (094 ∥ 095 ∥ 096) →
  097**. One writing agent at a time; preferred serial order after 093 is
  094 (Meetings), 095 (System), 096 (Activity), then 097 (chrome cutover).
  Plan 083 (visual gates) remains TODO and should be refreshed after 097 if
  still open.
- 093 owns the IA contract + `SettingsExpandableSection` primitive and skill
  guidance; no product section migration.
- 094 folds Meetings `.export` / `.meetingPrompts` / `.monitoringTargets` into
  the root Form (expandable + existing sheets) and deletes
  `MeetingSettingsNavigationState`.
- 095 folds System `.permissions` / `.protectedApps` into General; keeps
  Models / Dictionary / Audio as the only System child destinations with
  **local** back. Does not fold those three into General.
- 096 keeps Activity History as the only Activity subpage; Event Detail /
  More Insights / Model Performance become sheets; History search and
  conversation dismiss move off the global toolbar.
- 097 removes back/forward chrome and relocates capability toggles onto their
  pages. Do not start 097 until 094–096 preconditions pass.

## Findings considered and rejected

- Converting Activity analytics **child** routes, transcription History, Modes
  lists, monitored apps/sites, provider/model catalogs, dictionary rules, or
  permission status blocks mechanically into scalar Form rows remains rejected
  as a *content-type* rule (plan 082). **B2 (093–097) supersedes** the older
  stance that those surfaces must remain *separate navigation destinations*:
  navigation may flatten (inline expandable, sheets, local back) while the
  specialized content chrome stays. Plan 092’s Activity index Form chrome is
  preserved; 096 only changes how analytics/detail are presented.
- Applying the Modes drawer's 400 pt width to main Settings pages is rejected:
  the fixed width belongs only to the trailing overlay; root/detail content
  must use the full available container width.
- Splitting agent-ops work into many micro-plans (AGENTS-only, INDEX-only,
  hooks-only, etc.) is rejected for this pass: related token/loop fixes are
  bundled into 084–086 to reduce orchestration overhead.
- Promoting lean-code as a global default is rejected until artifact/browser
  smoke coverage from plan 060 exists; 086 only allowlists `implementer-fast`.
- Deleting archived macos reference dumps without a dated archive copy is
  rejected for plan 085's original prune (must archive first). Plan 088 later
  deletes the whole `.agents/docs/archive/` tree after confirming live routing
  no longer depends on those recovery copies.
- Making `SKIP_TESTS=1` or default `MA_RUST_AUDIO_KERNELS_BUILD=off` the normal
  pre-push path is rejected; 087 must fix staging/reuse instead.
- Weakening Full escalation for real `scripts/*` / Makefile changes to speed
  pushes is rejected; reuse and false-mismatch fixes are the lever.
- Merging `apple-design` into `macos-app-engineering` in the same pass as
  retiring `swiftui-pro` (plan 088 Option C) is rejected by default: it would
  re-inflate MAE after plan 085 pruned hot-path bulk. Keep motion/feel as a
  progressive-disclosure specialist unless the operator explicitly selects C.
- Merging `swift-conventions` into the UI cluster is rejected: language-style
  ownership stays separate from macOS/UI implementation (plan 028).
