# Plan 090: Restore immediate-effect settings switches and document the boolean-control rule

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat cfb72f45..HEAD -- \
>   .agents/skills/macos-app-engineering/SKILL.md \
>   .agents/skills/macos-app-engineering/references/macos-app-engineering-details.md \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/DictationSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/GeneralSettingsTab.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SpeakerIdentificationSettingsSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/AssistantIntegrationsSection.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/AssistantIntegrationEditorSheet.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormPage.swift \
>   Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorDetailView.swift \
>   plans/README.md
> ```
>
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `cfb72f45`, 2026-07-15

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent of plans 091 and 092; can run in parallel only if repository policy allows a second writer (default: serial)
- **Reviewer required**: `yes` — confirm every boolean surface is classified by save semantics, not by Form vs non-Form
- **Rationale**: Touches multiple settings tabs plus guidance; Full lane because UI interaction contract and skill docs change together
- **Escalate when**: A binding turns out to be draft/deferred rather than immediate, or more than eight production source files need non-mechanical edits beyond the inventory below

## Why this matters

Prisma already documented that boolean controls follow **save semantics**:
immediate settings use switches; draft values committed by Save/Create use
checkboxes. The Form migration in plan 080 replaced many `DSToggleRow`
switches with native `Toggle` + `.toggleStyle(.checkbox)` on pages that still
persist immediately into `AppSettingsStore`. That inverted the interaction
contract (Dictation Text Handling is the clearest user-visible example) and
made Form membership look like a reason to use checkboxes. This plan restores
the correct controls and elevates the rule so the next Settings pass cannot
reintroduce the regression.

## Current state

### Documented rule (already present, too easy to miss)

`.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md`
currently contains:

```swift
// Immediate-effect setting
DSToggleRow("Enable feature", isOn: $viewModel.isEnabled)

// Draft value committed by Save/Create
Toggle(isOn: $draftValue) { Text("Enable feature") }
.toggleStyle(.checkbox)
```

That snippet is **not** listed in `SKILL.md` non-negotiables, and it does not
say that “lives inside a `Form`” is not the same as “deferred save.”

### Incorrect: checkbox on immediate-effect settings (fix → switch)

| Surface | File | Controls |
|---|---|---|
| Dictation → Text Handling | `DictationSettingsTab.swift:56-88` | auto-copy, auto-paste, smart spacing, smart paragraphs |
| Meetings → Workflow | `MeetingSettingsTab.swift:139-156` | auto-start recording, merge audio |
| Meetings → Intelligence | `MeetingSettingsTab.swift:210-220` | post-processing, meeting Q&A |
| Meetings → Export | `MeetingSettingsTab.swift:307-349` | auto-export, template enabled |
| Meetings → Prompts | `MeetingSettingsTab.swift:430-438` | auto-detect meeting type |
| Meetings → Speaker ID | `SpeakerIdentificationSettingsSection.swift:23-31` | diarization enabled |
| System / General | `GeneralSettingsTab.swift:60-71`, `:274-281` | launch at login, show in Dock, show settings on launch, recording indicator |
| Assistant → Integrations | `AssistantIntegrationsSection.swift:32-40` | assistant integrations capability |

Exemplar excerpt (`DictationSettingsTab.swift`):

```swift
Toggle(isOn: $viewModel.autoCopyTranscriptionToClipboard) {
    VStack(alignment: .leading) {
        Text("settings.general.auto_copy_transcription".localized)
        // ...
    }
}
.toggleStyle(.checkbox) // ← wrong: binding writes immediately
```

### Correct exemplars to match

- Immediate Form rows already correct: `AudioSettingsTab.swift` and
  `EnhancementsSettingsTab.swift` use `DSToggleRow` (switch).
- Deferred-save checkboxes already correct:
  `DictationStyleEditorDetailView.swift` `CheckboxRow` helpers.
- Toolbar capability switches already correct:
  `SettingsPage.swift` `makeCapabilityToolbarToggle` uses `.toggleStyle(.switch)`.

### Opposite mistake (deferred draft using switch)

`AssistantIntegrationEditorSheet.swift:146-162` uses `DSToggleRow` for overlay
visibility options that live on a draft and commit only when Close runs
`onApplyAndClose(draft)`. Those should become checkboxes (reuse the
`CheckboxRow` pattern from `DictationStyleEditorDetailView`, or a shared
private/local equivalent — prefer reuse/extend before create).

### Misleading Form previews

`SettingsFormPage.swift` previews use `.toggleStyle(.checkbox)` for
“Automatically start recording”, which teaches the wrong default for an
immediate setting.

### Repo conventions

- Prefer native `Toggle` labels inside `Form`/`Section` (plan 080). Do **not**
  reintroduce `DSToggleRow` solely to get a switch if a native
  `Toggle { ... }.toggleStyle(.switch)` aligns with Form row guides.
- `DSToggleRow` remains valid for immediate settings outside Form row anatomy
  or when an existing section already uses it consistently (Audio).
- User-facing strings stay on `"key".localized`; do not add new copy.
- Conventional Commits: `fix(settings): ...`, `docs(skills): ...`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory | `rg -n "toggleStyle\\(\\.checkbox\\)|DSToggleRow\\(|CheckboxRow\\(" Packages/MeetingAssistantCore/Sources/UI --glob '*.swift'` | Lists every boolean control to classify |
| Guidance | `make guidance-check` | exit 0 after skill edits |
| Previews | `make preview-check` | exit 0 |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'GeneralSettingsLaunchAtLoginTests\|GeneralSettingsObservationTests\|AppSettingsStoreCapabilityTests\|AppSettingsAssistantIntegrationsTests\|MeetingSettingsNavigationStateTests\|ActivitySettingsNavigationStateTests'` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Lint | `make lint-agent` | exit 0 |
| Full gate | `make validate-agent ARGS="--lane full --no-reuse --agent"` | PASS |

## Suggested executor toolkit

- Read and follow `.agents/skills/macos-app-engineering/SKILL.md` and
  `references/macos-app-engineering-details.md` before editing UI.
- Use `delivery-workflow` for risk/lane confirmation before validation.
- Do **not** use `apple-design` unless motion/feel regressions appear.

## Scope

**In scope**:

- Skill documentation:
  - `.agents/skills/macos-app-engineering/SKILL.md`
  - `.agents/skills/macos-app-engineering/references/macos-app-engineering-details.md`
- Production immediate-settings fixes listed in the inventory table
- `AssistantIntegrationEditorSheet.swift` draft booleans → checkbox
- `SettingsFormPage.swift` preview exemplars
- `plans/README.md` status row for this plan

**Out of scope**:

- Activity visual Form parity (plan 092)
- Meeting Transcription empty `Divider` row (plan 091)
- Modes editor checkbox set (already correct)
- `MeetingConversationView` send-on-return checkbox (ephemeral conversation UI, not Settings persistence)
- Changing persistence/bindings, localization keys, or capability enablement logic
- Plan 083 preview tooling / scripts

## Git workflow

- Branch: `fix/090-immediate-settings-switches`
- Commits (atomic):
  1. `docs(skills): elevate boolean control save-semantics rule`
  2. `fix(settings): restore switches for immediate Form settings`
  3. `fix(settings): use checkboxes for integration editor draft toggles`
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Elevate the rule in `macos-app-engineering`

Add a non-negotiable bullet to
`.agents/skills/macos-app-engineering/SKILL.md` (near the other Settings
control bullets), with this exact meaning:

> Boolean settings controls follow **save semantics**, not container type.
> Immediate-effect settings (including ordinary Settings `Form` pages that
> write to `AppSettingsStore` as the user changes them) use switch/`Toggle`
> switch style or `DSToggleRow`. Draft values committed only by Save/Create/
> Apply use `.toggleStyle(.checkbox)`. Living inside a `Form` is not a reason
> to use checkboxes.

Then expand the “Boolean controls by save semantics” subsection in
`references/macos-app-engineering-details.md` to include:

1. The rule above.
2. Explicit anti-pattern: “Do not apply `.toggleStyle(.checkbox)` to every
   Toggle just because the page uses `SettingsFormPage`.”
3. Classification checklist:
   - Does changing the control persist immediately without a Save button? → switch
   - Does the value live on a draft until Save/Create/Apply/Close-commit? → checkbox
4. Keep both code exemplars (immediate `DSToggleRow` / native switch Toggle, and
   deferred checkbox Toggle).
5. Point to correct exemplars: `AudioSettingsTab` (immediate),
   `DictationStyleEditorDetailView` (deferred).

**Verify**: `make guidance-check` → exit 0; `rg -n "save semantics|Immediate-effect|toggleStyle\\(\\.checkbox\\)" .agents/skills/macos-app-engineering` shows the new guidance in both files.

### Step 2: Fix Dictation Text Handling (canonical user-facing case)

In `DictationSettingsTab.swift`, remove `.toggleStyle(.checkbox)` from the four
Text Handling toggles and use `.toggleStyle(.switch)` explicitly (or omit only
if the file’s neighbors already rely on the platform default switch — prefer
explicit `.switch` for reviewability).

Preserve labels, captions, and bindings unchanged.

**Verify**:
`rg -n "toggleStyle\\(\\.checkbox\\)" Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/DictationSettingsTab.swift`
→ no matches.

### Step 3: Fix Meetings immediate toggles and Speaker Identification

In `MeetingSettingsTab.swift`, convert every inventory checkbox listed for
Workflow / Intelligence / Export / Prompts to `.toggleStyle(.switch)`.

In `SpeakerIdentificationSettingsSection.swift`, convert the diarization
Toggle the same way.

Do not change navigation drill-downs, pickers, or capability opacity.

**Verify**:
`rg -n "toggleStyle\\(\\.checkbox\\)" Packages/MeetingAssistantCore/Sources/UI/pages/settings/tabs/MeetingSettingsTab.swift Packages/MeetingAssistantCore/Sources/UI/components/settings/SpeakerIdentificationSettingsSection.swift`
→ no matches.

### Step 4: Fix General / System immediate toggles and Assistant capability

In `GeneralSettingsTab.swift`, convert launch-at-login, show-in-Dock,
show-settings-on-launch, and recording-indicator toggles to switch style.

In `AssistantIntegrationsSection.swift`, convert only
`isAssistantIntegrationsEnabled` to switch style. Keep per-integration
enable switches as switches.

**Verify**: focused tests in the Commands table pass; no behavior changes in
assertions about persisted values.

### Step 5: Fix deferred draft switches in the integration editor

In `AssistantIntegrationEditorSheet.swift`, replace the two overlay-visibility
`DSToggleRow`s with checkbox-style toggles matching
`DictationStyleEditorDetailView`’s `CheckboxRow` pattern. Prefer extracting a
tiny shared helper only if duplication is otherwise required; otherwise copy the
local private `CheckboxRow` shape into this file (reuse → extend → create:
local duplicate of a 10-line private helper is acceptable; do not invent a new
design-system primitive unless a third identical copy appears).

**Verify**: editor still applies draft only on Close; no live write while
toggling before Close.

### Step 6: Fix Form preview exemplars

Update `SettingsFormPage.swift` previews so the sample boolean uses
`.toggleStyle(.switch)` (immediate setting exemplar). Leave deferred-save
checkbox examples in Modes/editor previews untouched.

**Verify**: `make preview-check` → exit 0.

### Step 7: Final inventory and validation

Re-run the inventory `rg` and classify every remaining
`.toggleStyle(.checkbox)` as either:

- deferred-save / draft (keep), or
- preview evidence intentionally showing checkbox chrome (keep), or
- STOP if another immediate settings page still uses checkbox.

Then run build, lint, and Full `validate-agent`.

**Verify**: Commands table Full gate → PASS; update `plans/README.md` row to DONE.

## Test plan

- No new XCTest required if existing General/Meeting/capability tests cover
  bindings; do not add snapshot tests here (owned by plan 083).
- Manual / preview check: Dictation Text Handling shows switches; Modes editor
  Context Resources still shows checkboxes; integration editor overlay options
  show checkboxes.
- Pattern reference for any new local checkbox helper:
  `DictationStyleEditorDetailView.swift` private `CheckboxRow`.

## Done criteria

- [ ] Skill non-negotiable + details section document save-semantics clearly
- [ ] `make guidance-check` exits 0
- [ ] No `.toggleStyle(.checkbox)` remains on the immediate-settings inventory files
- [ ] `AssistantIntegrationEditorSheet` draft booleans use checkboxes
- [ ] `SettingsFormPage` previews exemplify switch for immediate settings
- [ ] Focused tests + `make build-agent` + `make lint-agent` + Full `validate-agent` PASS
- [ ] No files outside Scope modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- A listed control is discovered to be draft/deferred (has Save/Create and does
  not write until commit) — do not convert it to a switch; report instead.
- Fixing Form alignment seems to require recreating `DSToggleRow` wrappers
  across all pages — stop; prefer native Toggle switch style inside Form.
- Skill edit causes `guidance-check` failures that need unrelated AGENTS.md
  rewrites — stop and report.
- Scope expands into Activity chrome or Meeting Transcription Divider layout.

## Maintenance notes

- Future Settings Form migrations must classify each boolean by save semantics
  before choosing a control. Reviewers should reject “Form ⇒ checkbox” diffs.
- Plan 080’s phrase “native labelled toggles appropriate to a saved settings
  Form” meant native Form anatomy, not checkbox style.
- If a third editor sheet needs checkboxes, promote a shared settings checkbox
  row helper then — not sooner.
