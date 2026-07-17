# Plan 111: Add the VoiceInk-style Dictionary quick-add panel

> **Executor instructions**: Follow every gate and update `plans/README.md`.
> Use VoiceInk only as behavioral reference; do not copy source.
>
> **Drift check (run first)**:
> `git diff --stat 22794e18..HEAD -- App/GlobalShortcutController.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Services/ModifierShortcutConflictService.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift Packages/MeetingAssistantCore/Sources/UI`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/109-promote-dictionary-and-add-vocabulary-workflow.md`
- **Category**: direction
- **Planned at**: commit `22794e18`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — shortcut, panel lifecycle, and shared save service form one slice
- **Reviewer required**: yes — AppKit/focus/global-shortcut Full review
- **Rationale**: Global panel activation, Spaces, focus restoration, and shortcut conflicts are lifecycle-sensitive.
- **Escalate when**: A new entitlement is needed, the panel cannot be non-activating safely, or shortcut ownership conflicts with an existing action.

## Why this matters

VoiceInk beta lets users capture a new name or correction without abandoning
the app where they are dictating. Prisma can offer the same speed only after
the full Dictionary page and its validation services are shared and stable.

## Current state

- Immutable beta reference `refs/benchmark/beingpax-v2.0-beta.2` at `ba32144`
  includes `DictionaryQuickAddPanel`, a focused Vocabulary/Substitution switch,
  Return to submit, Escape to dismiss, previous-app restoration, and a
  configurable shortcut. `origin/main` at `c47a86d` does not include this panel,
  so the beta ref is the intended benchmark.
- `App/GlobalShortcutController.swift:56` centralizes Prisma shortcut startup,
  observation, cleanup, and Carbon registration.
- `ModifierShortcutConflictService.swift` has the canonical shortcut action set
  but no Dictionary action.
- Plan 109 provides the shared local validation/persistence services. The panel
  must call those services rather than duplicate normalization or saves.
- Follow Prisma's existing non-activating panel/AppKit bridge patterns and
  macOS 15 fallbacks; respect reduced motion and VoiceOver.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| AppKit tests | `make test-appkit` | exit 0 |
| Shortcut tests | `./scripts/run-tests.sh --suite dev --file ModifierShortcutConflictServiceTests` | exit 0 |
| Preview | `make preview-check` | exit 0 |
| Final | `make validate-agent ARGS="--lane auto"` | Full PASS |

## Suggested executor toolkit

- Use `benchmarking`, `macos-app-engineering`, `menubar`, `apple-design`,
  `accessibility-audit`, `testing-xctest`, and `delivery-workflow`.

## Scope

**In scope**:

- `App/GlobalShortcutController.swift` and app lifecycle composition.
- `Infrastructure/Services/ModifierShortcutConflictService.swift` plus shortcut
  settings/key definitions.
- A new `UI/Services/DictionaryQuickAddPanelController.swift` colocated with its
  owning type and new quick-add SwiftUI content/components.
- `UI/pages/settings/tabs/VocabularySettingsTab.swift` for shortcut configuration.
- Plan 109's vocabulary/substitution view models/services only to expose a
  shared save API, not to change semantics.
- English/Portuguese localization, previews, and AppKit/shortcut tests.

**Out of scope**: Transcription provider vocabulary use (Plan 110), clipboard
capture, automatic correction inference, sync, or multiple simultaneous panels.

## Git workflow

- Isolated branch/worktree: `codex/111-dictionary-quick-add`.
- One writer. Commit example:
  `feat(dictionary): add global quick-add panel`.

## Steps

### Step 1: Define the shortcut action and conflicts

Add a dedicated Dictionary quick-add shortcut definition, persisted setting,
and conflict-service action. Register/observe/unregister it through
`GlobalShortcutController` using existing lifecycle patterns. Add its editor to
the Dictionary page without making it the page's dominant content.

**Verify**: conflict tests cover Dictation, Assistant, Meeting, and Dictionary
pairings; controller tests prove update and cleanup.

### Step 2: Build one app-level panel controller

Create a single controller that captures the previously active application,
shows one appropriately leveled/focused panel across Spaces/full screen,
dismisses idempotently, tears down observers, and restores the previous app on
submit or cancel when safe. Use macOS 15-compatible APIs with guarded newer APIs.

**Verify**: AppKit tests cover open -> dismiss -> reopen, repeated shortcut,
Escape, app termination, Space/full-screen behavior where testable, and no
retained window/controller cycle.

### Step 3: Reuse Dictionary validation in focused quick-add content

Provide a clear Vocabulary/Substitution switch. Vocabulary accepts comma-
separated terms; Substitution accepts source variants plus an optional empty
replacement. Return submits when valid, Escape cancels, validation errors remain
visible, and focus starts in the first field. Do not copy VoiceInk's styling;
use Prisma controls, spacing, materials, and accessibility labels.

**Verify**: unit tests prove the panel and full page produce identical
normalization, duplicate detection, empty replacement, and save results.

### Step 4: Verify focus, accessibility, and restoration

Test keyboard-only operation, VoiceOver names/order, reduced motion,
reduced transparency, high contrast, long Portuguese copy, and previous-app
restoration after both submit and cancel. Avoid logging entered values.

**Verify**: `make test-appkit && make preview-check` -> pass; accessibility audit has no blocking finding.

### Step 5: Run Full validation and review

**Verify**: `make lint-strict && make validate-agent ARGS="--lane auto"` -> Full PASS; required review clears all Critical and Medium findings.

## Test plan

- Shortcut conflict/registration/update/teardown.
- Panel open/reopen/idempotent dismiss/retain-cycle behavior.
- Return/Escape, first focus, invalid and duplicate submissions.
- Shared full-page/panel save semantics.
- Previous-app restoration and accessibility/reduced-motion states.

## Done criteria

- [x] A configurable global shortcut opens one quick-add panel.
- [x] Users can add vocabulary or substitutions without opening Settings.
- [x] Return/Escape and previous-app restoration behave deterministically.
- [x] Full page and panel share validation/persistence semantics.
- [x] No raw term/substitution is logged.
- [x] AppKit, preview, Full validation, accessibility, and review gates pass.

## STOP conditions

- Plan 109 has no reusable atomic save service.
- Existing shortcut infrastructure cannot represent another action safely.
- Previous-app restoration steals focus after the user intentionally activates a different app.
- Panel lifecycle leaks observers, windows, or controllers.

## Maintenance notes

- Keep one global controller; multiple panel owners will race activation state.
- Re-run focus/Spaces tests whenever app activation policy changes.

