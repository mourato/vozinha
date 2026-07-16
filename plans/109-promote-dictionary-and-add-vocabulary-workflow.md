# Plan 109: Promote Dictionary and add a separate vocabulary workflow

> **Executor instructions**: Follow the steps in order and update the ledger.
> The VoiceInk reference is conceptual only; do not copy GPL source.
>
> **Drift check (run first)**:
> `git diff --stat 22794e18..HEAD -- Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/VocabularySettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/ViewModels/VocabularySettingsViewModel.swift Packages/MeetingAssistantCore/Sources/Domain/Models/VocabularyReplacementRule.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsSection.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/SystemSettingsTab.swift`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/108-move-assistant-integrations-into-drawers.md`
- **Category**: direction
- **Planned at**: commit `22794e18`, 2026-07-16

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — navigation, local persistence, and page state overlap
- **Reviewer required**: yes — persistence and user-data import/export require Full review
- **Rationale**: This creates a local data type while preserving an existing transcript-transform contract.
- **Escalate when**: Storage would leave the local-only boundary, import needs a destructive replace mode, or the source delta grows beyond eight production files not named here.

## Why this matters

Prisma's Dictionary currently contains only deterministic replacement rules and
is buried under Settings. VoiceInk beta treats Dictionary as a primary tool and
separates vocabulary terms (recognition/spelling hints) from substitutions.
This plan establishes that information architecture and local data foundation.

## Current state

- `VocabularySettingsTab.swift` is already an independently composable
  `SettingsFormPage`, but shows only replacement rules and a sheet editor.
- `VocabularyReplacementRule.swift` supports comma-separated variants,
  case-insensitive whole-word matching, literal replacement text, ordered
  application, and intentionally allows an empty replacement to remove fillers.
  Preserve this contract; VoiceInk's replacement semantics are not identical.
- `AppSettingsStore/AppSettings.swift:632` persists only
  `[VocabularyReplacementRule]` in UserDefaults.
- `.vocabulary` currently redirects to `.system/.dictionary`; General Settings
  displays Dictionary in `systemDrilldownsSection`.
- Immutable reference evidence: VoiceInk `origin/main` at `c47a86d` and beta ref
  `refs/benchmark/beingpax-v2.0-beta.2` at `ba32144` contain separate
  Vocabulary and Word Replacement models, a two-way Dictionary page, inline
  comma-separated vocabulary entry, and import/export. Prisma remains
  local-only; do not adopt VoiceInk's CloudKit store.
- Sidebar decision for this plan: Activity -> Dictation Modes -> Meetings ->
  Dictionary, with Settings kept in its existing bottom position.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Domain tests | `./scripts/run-tests.sh --suite dev --file VocabularyReplacementRuleTests` | existing contract remains green |
| View-model tests | `./scripts/run-tests.sh --suite dev --file VocabularySettingsViewModelTests` | exit 0 |
| Navigation/search | `./scripts/run-tests.sh --suite dev --file SettingsSectionTests` | exit 0 |
| Preview | `make preview-check` | exit 0 |
| Final | `make validate-agent ARGS="--lane auto"` | Full PASS |

## Suggested executor toolkit

- Use `benchmarking`, `data-persistence`, `macos-app-engineering`,
  `localization`, `testing-xctest`, and `delivery-workflow`.

## Scope

**In scope**:

- `Domain/Models/{VocabularyReplacementRule,VocabularyTerm,DictionaryArchive}.swift`
- `Infrastructure/Models/AppSettingsStore/{AppSettings,Keys,Initialization,LoadingHelpers,VocabularyRulesNormalization}.swift`
- `UI/ViewModels/{VocabularySettingsViewModel,VocabularyTermsSettingsViewModel}.swift`
- `UI/pages/settings/tabs/{VocabularySettingsTab,GeneralSettingsTab,SystemSettingsTab}.swift`
- `UI/components/settings/{SettingsSection,SettingsSearchRouteManifest,SettingsSearchIndex,SettingsPreviewEvidenceCatalog}.swift`
- `UI/pages/settings/SettingsPage.swift`
- English/Portuguese localizations and matching tests.

Paths are below `Packages/MeetingAssistantCore/Sources` unless stated.

**Out of scope**: Sending vocabulary to a provider or prompt (Plan 110), global
quick-add shortcut/panel (Plan 111), CloudKit/sync, and changing substitution
matching semantics.

## Git workflow

- Isolated branch/worktree: `codex/109-dictionary-vocabulary`.
- One writer. Commit examples:
  `feat(dictionary): add local vocabulary terms` and
  `refactor(settings): promote dictionary to sidebar`.

## Steps

### Step 1: Characterize and preserve substitutions

Add tests for literal `$` and backslash replacements, empty replacements,
comma variants, punctuation, duplicate collisions, ordering/cascades, transcript
and segment parity. Do not weaken existing behavior to match VoiceInk.

**Verify**: `./scripts/run-tests.sh --suite dev --file VocabularyReplacementRuleTests` -> all old and new cases pass before UI restructuring.

### Step 2: Add a normalized local vocabulary model

Create a small `VocabularyTerm` value with stable ID/value semantics and a
central normalization path: trim, reject empty, case-insensitive deduplicate,
preserve a deterministic display/order policy, and support comma-separated bulk
input. Persist locally beside replacement rules and cover load/reset/corrupt
payload/idempotent normalization.

**Verify**: add `AppSettingsVocabularyTermsTests.swift`; run
`./scripts/run-tests.sh --suite dev --file AppSettingsVocabularyTermsTests` -> pass.

### Step 3: Build two explicit Dictionary workflows

Keep one `SettingsFormPage` header and add an accessible two-way selection for
Substitutions and Vocabulary, defaulting to Substitutions to preserve current
entry behavior. Reuse the replacement editor/list/delete confirmation. Add
inline comma-separated term entry, duplicate/error feedback, sortable/removable
chips or an equally native list, keyboard focus, and distinct empty states.
Avoid custom card chrome and redundant descriptions.

**Verify**: `./scripts/run-tests.sh --suite dev --file VocabularySettingsViewModelTests && make preview-check` -> populated, empty, duplicate, long-copy, and both-workflow previews pass.

### Step 4: Add versioned import/export for both collections

Create a versioned Codable dictionary archive containing vocabulary terms and
substitutions. Export must contain no unrelated settings. Import must validate,
normalize, merge deterministically, report duplicates/invalid records, and be
all-or-nothing on decode failure. Preserve empty replacement values. Use the
existing macOS file importer/exporter pattern in the repo.

**Verify**: add archive round-trip, old-version, corrupt-file, duplicate-merge,
and rollback tests; run their test file -> pass.

### Step 5: Promote Dictionary to the sidebar

Make `.vocabulary` a visible primary section at the decided order and render
`VocabularySettingsTab()` directly. Remove Dictionary from
`systemDrilldownsSection` and remove `.dictionary` from `SystemSettingsRoute`.
Retarget vocabulary and substitution search keys to the visible destination.
Preserve stable raw identifiers as redirects where applicable.

**Verify**: `./scripts/run-tests.sh --suite dev --file SettingsSectionTests && ./scripts/run-tests.sh --suite dev --file SettingsSearchIndexTests` -> expected order and direct Dictionary routes pass.

### Step 6: Validate privacy, Full lane, and review

Confirm no dictionary value is logged or synchronized. Run strict lint and Full
validation; complete mandatory review.

**Verify**: `make lint-strict && make validate-agent ARGS="--lane auto"` -> Full PASS with no unresolved Critical/Medium findings.

## Test plan

- Existing substitution contract plus punctuation/template edge cases.
- Vocabulary normalization, bulk add, duplicate handling, persistence/reset.
- Archive round trip, merge, invalid rollback, both collections.
- Sidebar order, legacy/system route removal, search destination.
- Keyboard, VoiceOver labels, empty/populated/error previews.

## Done criteria

- [ ] Dictionary is a primary sidebar page and no longer a Settings child.
- [ ] Vocabulary and Substitutions are visibly separate workflows.
- [ ] Terms persist locally and normalize deterministically.
- [ ] Existing substitution semantics are unchanged.
- [ ] Versioned import/export covers both collections safely.
- [ ] Full validation and review pass.

## STOP conditions

- A persistence design would use CloudKit or send dictionary data externally.
- Import cannot be made atomic with the selected store.
- Existing empty/literal substitution behavior would regress.
- The required sidebar order has changed since this plan was approved.

## Maintenance notes

- The Dictionary page owns data entry; runtime consumption is Plan 110.
- Keep normalization centralized so providers and the quick panel never query
  or normalize persistence independently.

