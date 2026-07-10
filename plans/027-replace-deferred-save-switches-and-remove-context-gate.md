# Plan 027: Replace deferred-save switches and remove the Context Resources gate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report;
> do not improvise. When done, update the status row for this plan in
> `plans/README.md` unless a reviewer tells you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat HEAD -- Packages/MeetingAssistantCore/Sources/UI/components/settings/DictationStyleEditorSheet.swift Packages/MeetingAssistantCore/Sources/UI/Services/AssistantContextCaptureService.swift Packages/MeetingAssistantCore/Sources/UI/Services/RecordingManager/RecordingManagerContextCapture.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/DictationStyle.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> meaningful mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: UX / product logic
- **Planned at**: current working tree, 2026-07-10
- **Completed at**: 2026-07-10

## Why this matters

The Context Resources group currently mixes switch controls with a deferred
Save/Create sheet. That creates the wrong interaction contract: switches imply
an immediate setting change, while this editor commits a draft only when the
user saves. Boolean draft options in save-backed forms should use checkboxes.

The current group also has a global "Use context when improving text" gate. The
new product model removes that gate: context is included per source. If no
source checkbox is selected, no source is captured. Redaction remains a
checkbox-controlled processing option, but it should not be the only thing that
turns context capture on.

## Current state

- `native-app-designer` now owns the general rule:
  - Deferred-save forms/sheets use checkbox-style boolean controls.
  - Immediate settings rows and toolbar capability controls can keep switches.
- `DictationStyleEditorSheet` has a Save/Create button and still uses
  `DSToggleRow` for draft booleans:
  - `forceMarkdownOutput`
  - `replaceBasePrompt`
  - `contextAwarenessEnabled`
  - `includeAccessibilityText`
  - `includeClipboard`
  - `includeWindowOCR`
  - `redactSensitiveData`
- `DictationStyleEditorSheet` hides individual context sources behind
  `contextAwarenessEnabled`.
- `DictationContextSourcePolicy` persists `isEnabled` plus the individual source
  fields.
- `AssistantContextCaptureService` resolves:
  `contextSourcePolicy?.isEnabled ?? settings.contextAwarenessEnabled`
  and returns before source capture when that value is false.
- `RecordingManagerContextCapture` uses the same global/per-mode gate to decide
  whether deferred OCR should start.
- The global `AppSettingsStore.contextAwarenessEnabled` still exists for legacy
  default-mode construction and global fallback behavior.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Deferred-save switch inventory | `rg -n "DSToggleRow|Toggle\\(|\\.toggleStyle\\(\\.switch\\)|\\.toggleStyle\\(\\.checkbox\\)|Button\\(\\\"common.save|primaryActionTitle|onSave:" Packages/MeetingAssistantCore/Sources/UI/pages/settings Packages/MeetingAssistantCore/Sources/UI/components/settings -g '*.swift'` | Lists save-backed surfaces and boolean controls to classify |
| Context gate inventory | `rg -n "contextAwarenessEnabled|contextAwarenessInclude|DictationContextSourcePolicy|Use context when improving text|settings.context_awareness.enabled" Packages/MeetingAssistantCore/Sources Packages/MeetingAssistantCore/Tests -g '*.swift'` | Lists all UI, settings, runtime, and tests tied to the gate |
| Focused tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests|ExtractedWorkflowServicesTests|SettingsSearchIndexTests'` | exit 0 |
| UI previews | `make preview-check` | exit 0 |
| Compile | `make build-agent` | exit 0 |
| Guidance validation | `make guidance-check` | exit 0 |

## Scope

**In scope**:

- `DictationStyleEditorSheet` Context Resources UI.
- A reusable checkbox-row component only if existing SwiftUI checkbox usage is
  not sufficient for the editor.
- `DictationContextSourcePolicy` and its backward-compatible decoding/defaults.
- Context capture enablement in `AssistantContextCaptureService` and
  `RecordingManagerContextCapture`.
- Tests covering default-mode policy, disabled/all-false source behavior,
  per-source capture, and search/localization fallout.
- Localization cleanup for the removed global label if no other screen uses it.
- Skill guidance already updated in `native-app-designer`; keep it intact unless
  implementation evidence requires a narrower rule.

**Out of scope**:

- Replacing every immediate settings switch in the app.
- Changing toolbar capability toggles in `SettingsPage`.
- Redesigning the settings sidebar or navigation taxonomy.
- Changing protected-app exclusions, provider/model selection, or prompt logic.
- Removing legacy persisted `contextAwarenessEnabled` storage unless the
  migration path is explicitly proven safe.

## Git workflow

- Branch: `fix/context-resources-checkboxes`
- Commit style: `refactor(settings): replace context resource switches with checkboxes`
- Keep commits atomic. Do not push or open a PR unless instructed.

## Steps

### Step 1: Classify switch call sites in save-backed flows

Run the deferred-save switch inventory command and classify each boolean control:

1. **Immediate setting**: changes apply instantly. Keep switch.
2. **Toolbar capability**: feature-level on/off outside a Save form. Keep switch.
3. **Deferred draft option**: a Save/Create button commits the value. Convert to
   checkbox style.
4. **Specialized runtime control**: preserve only with an explicit reason.

Document the classification in PR notes. The first required conversion is the
Context Resources group in `DictationStyleEditorSheet`. Other save-backed
boolean rows in the same sheet should be converted in the same pass if they use
the same draft/Save contract.

**Verify**: Inventory command exits 0 and each in-scope `DSToggleRow` has a
keep/replace decision.

### Step 2: Add or reuse a checkbox row for draft booleans

Prefer direct SwiftUI `Toggle(...).toggleStyle(.checkbox)` if it fits the
existing editor anatomy. Add a small shared row only if it avoids duplication in
the same sheet or matches an established local component pattern.

Requirements:

- Label is visible and localized.
- Checkbox is not visually styled like a switch.
- Row supports VoiceOver with the same label.
- No extra card or nested-card chrome.
- No broad redesign of `DSGroup`.

**Verify**: `make preview-check` passes after the UI component change.

### Step 3: Remove the Context Resources global gate from the editor

In `DictationStyleEditorSheet`:

- Remove the visible "Use context when improving text" row.
- Always show these checkboxes in Context Resources:
  - Include Accessibility UI Text
  - Include Clipboard
  - Include Active Window OCR
  - Redact Sensitive Data
- Stop hiding source controls behind `contextAwarenessEnabled`.
- Save only per-source choices. If the model still requires an `isEnabled`
  field during the migration, derive it from selected capture sources instead of
  exposing it as its own user-facing option.

Acceptance rule:

- `includeAccessibilityText || includeClipboard || includeWindowOCR` means
  context capture is enabled for source capture.
- All three source checkboxes off means no source capture.
- `redactSensitiveData` can stay on while all sources are off; it should not
  force capture by itself.

**Verify**: Search for `settings.context_awareness.enabled` in UI code; it
should not be rendered in the Context Resources editor.

### Step 4: Update context policy and migration behavior

Adjust `DictationContextSourcePolicy` and default-mode construction so old
persisted data remains readable.

Preferred implementation:

- Keep decoding legacy `isEnabled` if needed for compatibility.
- Introduce a computed capture gate such as `hasEnabledContextSources`.
- When old `isEnabled == false`, preserve the effective behavior by treating all
  capture-source fields as false unless explicit source choices exist.
- When old `isEnabled == true`, preserve existing individual source values.
- Avoid a new global toggle or parallel persisted gate.

**Verify**: Add/update tests in `AppSettingsDictationStylesTests` for legacy
decode/default-mode behavior.

### Step 5: Update runtime capture gating

In `AssistantContextCaptureService` and `RecordingManagerContextCapture`:

- Replace `contextSourcePolicy?.isEnabled ?? settings.contextAwarenessEnabled`
  as the primary decision with a per-source capture decision.
- Capture only selected sources.
- Skip deferred OCR unless `includeWindowOCR` is selected.
- Keep protected-app blocking and sensitive-data redaction behavior.
- Preserve active-tab/calendar context behavior intentionally; if those should
  remain outside Context Resources source capture, document that in tests.

**Verify**: Update `ExtractedWorkflowServicesTests` so all-source-disabled policy
does not capture accessibility, clipboard, or OCR.

### Step 6: Clean localization and search routing

Remove or stop indexing the removed global label if no visible UI still uses it:

- `settings.context_awareness.enabled`
- `settings.context_awareness.enabled_desc`

Keep source labels searchable and routed to the relevant Dictation/Modes surface.

**Verify**: `SettingsSearchIndexTests` pass and no orphaned visible key remains.

### Step 7: Run quality gates and review

Run:

1. `swift test --package-path Packages/MeetingAssistantCore --filter 'AppSettingsDictationStylesTests|ExtractedWorkflowServicesTests|SettingsSearchIndexTests'`
2. `make preview-check`
3. `make guidance-check`
4. `make build-agent`

Because this implementation touches settings UI and runtime context behavior,
perform the Full-lane semáforo review before merge. Fix all red and yellow
findings before marking the plan done.

## STOP conditions

- A migration would silently re-enable context sources for users who previously
  disabled the global gate.
- Removing `isEnabled` breaks decoding existing `DictationStyle` values.
- The implementation requires broad rewrites of settings navigation, provider
  selection, or prompt assembly.
- A checkbox cannot be made accessible without creating a larger component
  change; stop and split that component work first.

## Test plan

- Focused policy/runtime tests for dictation styles and context capture.
- Settings search tests for removed and retained context labels.
- `make preview-check` for the editor UI.
- `make guidance-check` because `.agents` guidance changed.
- `make build-agent` for compile confidence.
