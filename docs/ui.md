# UI

Current UI contract for Vozinha (technical project identity: Prisma). Read
this before changing Settings, onboarding, status/recording surfaces, shared
design-system components, or native window/panel chrome. Durable rationale
belongs in ADRs when the project introduces that directory; this file is the
current contract, not a task log.

## Product intent

Vozinha is a local-first macOS meeting capture, transcription, and AI
post-processing app. Its UI should feel native, calm, and trustworthy while
making recording, permissions, configuration, and processing state obvious.

## Sources of truth

- Shared tokens and components: [`AppDesignSystem.swift`](../Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppDesignSystem.swift), [`AppTypography.swift`](../Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppTypography.swift), and the neighboring `DS*` components
- Shared motion: [`AppleMotion.swift`](../Packages/MeetingAssistantCore/Sources/UI/components/design-system/AppleMotion.swift) and [`SettingsMotion.swift`](../Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsMotion.swift)
- Settings surfaces: [`SettingsPage.swift`](../Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift), [`SettingsFormPage.swift`](../Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsFormPage.swift), and [`SettingsWindowBackground.swift`](../Packages/MeetingAssistantCore/Sources/UI/components/settings/SettingsWindowBackground.swift)
- Project UI routing and constraints: [`AGENTS.md`](../AGENTS.md)

When implementation and this document disagree, inspect the code, reconcile
the contract in the same change, and record a durable trade-off in an ADR when
one exists. Do not create a parallel design-system document.

## Principles and invariants

- Prefer macOS-native semantics, materials, controls, and system colors.
- Keep spacing, radii, typography, colors, surfaces, and control sizing in
  `AppDesignSystem`; use shared `DS*` components before local variants.
- The shared layout scale is tokenized from 2 through 24 points. Common radii
  are 4, 6, 8, 12, and 16; standard controls are 34 points high and compact
  controls 30 points high.
- Use semantic colors for accent, success, warning, error, neutral, recording,
  and permission states. Do not encode important state only through color.
- Settings uses a native window background/material with an opaque fallback for
  Reduce Transparency and a clear title-bar boundary; avoid nested decorative
  plates that compete with the window surface.
- Keep one semantic scroll owner per scrollable surface and preserve the
  existing Settings navigation and form hierarchy.

## States, accessibility, and motion

Affected controls must cover idle, hover, pressed, focused, selected, disabled,
loading, empty, permission, and error states as applicable. Labels, values,
selection, keyboard behavior, and VoiceOver are part of the contract.

Use `AppleMotion`/`SettingsMotion`. Default, interactive, and press springs are
shared; disclosure is 0.2 seconds and Reduce Motion uses a short fade or no
motion. Respect Reduce Transparency and increased contrast, preserving content
hierarchy and feedback in every fallback.

## Review checklist

- [ ] Reuse `AppDesignSystem`, `AppTypography`, `AppleMotion`, and existing
      `DS*` components before adding local styling.
- [ ] Preserve native window/material behavior and accessibility fallbacks.
- [ ] Verify relevant states, keyboard/VoiceOver, Light/Dark, increased
      contrast, Reduce Transparency, and Reduce Motion.
- [ ] Update this file when a reusable UI rule or invariant changes.
- [ ] Add or update an ADR for a meaningful alternative, risk, ownership
      decision, or external reference; do not record one-off polish.

## Lifecycle

Create or update this file when a rule applies across surfaces, constrains
future implementation, or explains a product-level trade-off. Retire rules
when their implementation and references disappear; preserve historical
rationale in an ADR when it remains useful.
