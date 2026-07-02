---
name: accessibility-audit
description: This skill should be used when the user asks to "audit accessibility", "improve keyboard navigation", "fix VoiceOver behavior", or "review reduced-motion and focus behavior" in Prisma.
---

# Accessibility Audit

## Role

Use this skill for accessibility-sensitive interaction work in Prisma.

- Own accessibility audits across SwiftUI and AppKit surfaces.
- Cover keyboard navigation, focus order, reduced motion, non-color cues, overlays, and panel behavior.
- Delegate localization and accessible copy keys to `../localization/SKILL.md`.

## Scope Boundary

Use this skill when the task involves:

- VoiceOver labels, hints, traits, and grouping
- keyboard shortcuts and keyboard-only navigation
- focus order and focus recovery
- reduced-motion behavior
- non-color affordances and warnings
- floating panels, overlays, menu bar UI, and other non-standard surfaces

## When to Use

Use this skill when the user asks for accessibility review or fixes involving VoiceOver, keyboard navigation, focus recovery, reduced motion, or accessibility-sensitive overlays and panels.

## Audit Checklist

### VoiceOver

- Every interactive element has a meaningful label.
- Hints are present when the result of an action is not obvious.
- Grouped content uses combined accessibility elements only when the grouped reading order stays clear.

### Keyboard and Focus

- Primary flows are usable without a pointer.
- Focus order matches visual and task order.
- Opening and closing sheets, popovers, and overlays restores focus deterministically.
- Shortcuts do not block expected system defaults without a clear product reason.

### Motion and Visual Signals

- Honor reduced-motion settings for animation-heavy surfaces.
- Do not rely on color alone to communicate warnings, recording state, or failure.
- Accessibility-sensitive animation fallbacks should remain informative, not just disabled.

### Overlay and Panel Surfaces

- Floating indicators and non-activating panels remain understandable when read by assistive technologies.
- Menu bar and status-item flows expose enough state via labels, hints, or menu copy.
- Visibility changes should not create focus traps or orphaned interactions.

## Repository Hotspots

Review these areas first when the task touches accessibility-sensitive UI:

- `Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/`
- `Packages/MeetingAssistantCore/Sources/UI/components/onboarding/`
- `Packages/MeetingAssistantCore/Sources/UI/Presentation/AssistantScreenBorderController.swift`
- `App/AppDelegate/RecordingUI.swift`

## Validation Notes

- Document one short manual checklist result for accessibility-sensitive changes.
- Include keyboard-only and VoiceOver expectations in PR notes when overlays, onboarding, or menu bar behavior changes.
- If the task is only about localized strings or accessibility copy keys, route back to `../localization/SKILL.md`.

## Related Skills

- `../localization/SKILL.md`
- `../native-app-designer/SKILL.md`
- `../menubar/SKILL.md`
- `../menubar/SKILL.md`
