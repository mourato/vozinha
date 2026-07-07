---
name: localization
description: This skill should be used when the user asks to "localize UI text", "update Localizable.strings", "improve accessible copy", or "add accessibility localization".
---

# Localization and Accessible Copy

## Role

Use this skill as the canonical owner for localization and accessible copy in Prisma.

- Own localized string usage, locale-file hygiene, and accessibility-copy key patterns.
- Keep UI text aligned with shared localization helpers and bundle-resolution rules.
- Delegate broad accessibility interaction audits to the accessibility owner.

## Scope Boundary

- Use this skill for localized strings, localization-key cleanup, and accessible copy text.
- Use `../accessibility-audit/SKILL.md` for keyboard focus, reduced motion, overlays, and broader accessibility behavior.

## Overview

Guide for internationalization and accessible copy in Prisma.

## When to Use

Activate this skill when working with:
- `Bundle.safeModule` resource resolution
- `"some.key".localized` / `"some.key".localized(with: ...)`
- localized accessibility labels and hints
- string-key cleanup across locale files

Route broad accessibility audits, keyboard focus checks, reduced-motion review, and overlay/panel accessibility to `../accessibility-audit/SKILL.md`.

## Key Concepts

### Resource Loading

**CRITICAL**: This project centralizes localization bundle resolution in `Bundle.safeModule` (see `Packages/MeetingAssistantCore/Sources/Common/Utilities/BundleExtension.swift`).

```swift
// ✅ Standard (everywhere)
Text("settings.transcriptions.title".localized)
Text("permissions.granted_count".localized(with: granted, required))
let title = key.localized

// ✅ Formatting (respects Locale.current)
let message = "about.version".localized(with: AppVersion.current)

// ❌ Avoid in feature code (only allowed inside helpers)
NSLocalizedString("settings.transcriptions.title", comment: "")
```

Do not re-implement bundle lookup helpers in feature code. Always use the shared helpers.

## Localization Patterns

### String Management

**NEVER** hardcode UI strings:

```swift
// ❌ WRONG
Text("Record")

// ✅ CORRECT
Text("recording.start".localized)
```

When adding or removing UI text, ensure it is handled correctly: either by proper localization or by removing/sanitizing it safely.

### Mandatory Registration on New Key Introduction

Whenever a new localization key is introduced in source code via `"key".localized`, **register it in all supported locale files** in the same PR/task:

1. Add the key to `en.lproj/Localizable.strings` with the English value.
2. Add the key to `pt.lproj/Localizable.strings` with the Portuguese translation.
3. Keep locale files symmetric — no key should exist in only one language.
4. Verify symmetry before merge — grep both locale files for the new key to confirm.

This requirement applies regardless of risk level (Fast or Full lane). A missing registration is a defect, not a deferrable item.

### Mandatory Sanitization on UI Text Removal

If any user-facing text is removed from the interface, localization cleanup is required in the same task:

1. Remove orphaned keys from all supported locale files (`en.lproj`, `pt.lproj`, etc.).
2. Confirm no source references remain for the removed keys.
3. Keep locale files symmetric whenever applicable (no stale key in one language only).

This sanitization is mandatory, not optional.

### Key Convention

Use descriptive, dot-separated keys with `lower_snake_case` segments:

```swift
// Good keys
"recording.start"                   // Start recording
"recording.stop"                    // Stop recording
"recording.in_progress"             // Recording in progress
"settings.transcriptions.empty_desc" // Empty state description
```

## Accessible Copy (VoiceOver Text)

### Purpose Descriptions

Describe **what the UI does**, not just labels:

```swift
// ❌ WRONG - Label, not description
Button(action: {}) {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("Microphone")

// ✅ CORRECT - Purpose description
Button(action: {}) {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("recording.start.accessibility".localized)
.accessibilityHint("recording.start.hint.accessibility".localized)
.accessibilityAddTraits(.startsMediaSession)
```

### Accessibility Key Convention

Follow this pattern for consistent naming:

```swift
// Pattern: component.action.accessibility
"menubar.recording.start.accessibility" = "Start recording";
"menubar.recording.stop.accessibility" = "Stop recording";
"menubar.recording.status.accessibility" = "Recording status";
```

## References

- [BundleExtension.swift](../../../Packages/MeetingAssistantCore/Sources/Common/Utilities/BundleExtension.swift)
- [Localizable.strings](../../../Packages/MeetingAssistantCore/Sources/Common/Resources/en.lproj/Localizable.strings)
- [Apple Accessibility Guide](https://developer.apple.com/documentation/accessibility)
- `../accessibility-audit/SKILL.md`

## Related Skills

- `../accessibility-audit/SKILL.md`
- `../swiftui-patterns/SKILL.md`

## 2026-07-01 Progression Drill

### New Evidence

- `a62d4a8e` changed settings labels and prompt copy across both `en.lproj` and `pt.lproj` while updating `SettingsSearchIndex` and related tests.
- `7c568e46` added localized visible labels for `Activity`, `Intelligence`, and `System` while keeping legacy settings section keys available for old routes and search hits.
- Plans 011-014 require search/localization updates whenever Dashboard/History, Models/Text & Context/Dictionary, or General/Sound/Permissions are merged into parent destinations.

### Skill Deepening Focus

1. For settings taxonomy changes, update locale files, section titles, search index mappings, and tests in the same slice.
2. Keep old localization keys only when legacy routes or search terms still need them; otherwise remove orphaned keys symmetrically across locales.
3. Add search tests for both new parent labels and old child terms so renamed pages remain discoverable.
4. When consolidating pages, re-check nearby descriptions for duplicated copy introduced by parent and child labels saying the same thing.

### 2026-07-07 Process Gap Closure

**Gap:** New `.localized` keys could be added in source code without corresponding entries in `Localizable.strings`, causing raw keys to appear in the UI. Neither the Standard Task SOP nor this skill explicitly required registration in all locale files.

**Fix:** Added "Mandatory Registration on New Key Introduction" section above to make locale-file registration a hard requirement in the same PR/task.
