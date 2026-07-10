---
name: native-app-designer
description: This skill should be used when the user asks to "design or redesign macOS/iOS interface", "improve user experience", "analyze UI/UX quality", or "define visual/motion direction". For macOS/iOS UI work, consult this skill first.
---

# Native App Designer (Primary UI/UX Reference)

## Role

Use this as the primary UI/UX reference for Apple-platform interfaces.

For this repository (macOS app), consult this skill whenever the task includes:

- UI implementation changes
- UX analysis or review
- Visual hierarchy, spacing, typography, color direction
- Interaction and motion behavior
- Interface quality improvements and polish

## Scope Boundary

- This skill owns visual/interaction direction and UX quality criteria.
- This skill complements implementation-oriented skills:
  - `../swiftui-patterns/SKILL.md` for SwiftUI composition/state/layout
  - `../macos-development/SKILL.md` for platform integration and lifecycle
  - `../debugging-strategies/SKILL.md` for runtime diagnosis when UX symptoms need investigation

## When to Use

Use this skill when the task changes UI behavior, visual hierarchy, motion direction, interface quality, or user experience on Apple platforms.

## Mandatory Consultation Rule (macOS/iOS)

When the stack is macOS and/or iOS and the task touches interface or user experience, load this skill before implementation.

Use this sequence:

1. `native-app-designer` -> define UX/UI direction and acceptance criteria.
2. `swiftui-patterns` or `macos-development` -> implement structure and platform behavior.
3. `debugging-strategies` -> investigate jank, layout thrash, or runtime symptoms when the cause is unclear.

## UX/UI Review Checklist

1. **Clarity**: Primary actions and hierarchy are obvious within 3 seconds.
2. **Consistency**: Uses project design-system components/tokens before custom wrappers.
3. **Native Feel**: Interactions align with macOS/iOS conventions.
4. **Accessibility**: Labels, contrast, and reduced-motion paths are covered.
5. **Motion Quality**: Animation supports comprehension, not decoration.
6. **Visual Rhythm**: Spacing/typography form clear grouping and scanning flow.
7. **Redundancy Control**: Nearby titles, descriptions, tooltips, and popovers do not repeat the same message.

## Practical Guidelines

- Prefer semantic colors/materials and design-system tokens over hardcoded values.
- Avoid generic, repetitive layouts that flatten hierarchy.
- In settings and inspector-style screens, keep one primary explanation per cluster. Do not repeat identical copy in the page header, section header, card body, and tooltip.
- In settings screens, use `SettingsListGroup` for simple lists of rows so spacing and separators stay native and consistent. Use `DSGroup` only for composed content such as editors, tables, cards, app/model pickers, or callout/action clusters.
- In deferred-save forms or sheets, prefer checkbox-style boolean controls over switch controls. Switches imply immediate effect; when the screen has an explicit Save/Create action, boolean options should read as draft selections that are committed with the rest of the form. Keep switches for immediate settings rows, toolbar capability toggles, or other controls whose state applies as soon as it changes.
- Treat popovers/help affordances as escalation, not baseline content. If two or more nearby popovers explain the same concept or add little beyond visible copy, consolidate or remove them.
- Use motion to guide attention and communicate state changes.
- Keep reduced-motion behavior available for motion-heavy transitions.
- Keep motion local and purposeful; do not introduce shader/matched-geometry machinery unless a Prisma surface clearly earns it and the reduced-motion fallback is clear.
- For macOS surfaces, use AppKit bridging only when SwiftUI behavior is insufficient.
- Keep one canonical primary window per workflow surface. Introduce auxiliary windows only when detached context materially improves the flow.
- Prefer in-window navigation, split view, sheet, or popover before creating another primary workflow surface.
- Preserve predictable keyboard ownership and window targeting whenever a flow can appear in more than one surface.

## Routing

- Need concrete SwiftUI state/layout patterns -> `../swiftui-patterns/SKILL.md`
- Need runtime diagnosis for jank/layout thrash -> `../debugging-strategies/SKILL.md`
- Need broader platform lifecycle/integration decisions -> `../macos-development/SKILL.md`

## 2026-06-30 Progression Drill

### New Evidence

- `93b86304` reorganized AI model/provider settings into clearer surfaces instead of keeping provider configuration buried in one crowded tab.
- `c7294bc9` extracted Protect Sensitive Apps into a standalone always-on section, making privacy behavior discoverable without tying it to dictation-style editing.
- `68dd959f` renamed styles to modes and extracted user prompts into `UserPromptsSettingsTab`, reducing overloaded settings vocabulary and repeated explanations.

### Skill Deepening Focus

1. For settings UX, classify the user mental model first: provider setup, sensitive-app protection, prompt behavior, and mode selection should not compete in one cluster.
2. Prefer standalone sections/pages when a control is always-on or cross-cutting; avoid hiding it inside another feature's editor.
3. Check labels and search terms after taxonomy changes so the UI vocabulary, settings search, and localization all say the same thing.
4. Remove duplicated visible explanations when extraction makes a page's purpose obvious.

## 2026-07-01 Progression Drill

### New Evidence

- `1d7ebf7f` added plans 004-009 after comparing Prisma with VoiceInk and rejected copying VoiceInk's sidebar verbatim because Prisma has first-class Meetings, Assistant, Integrations, and local history workflows.
- `7c568e46` introduced a consolidated settings route foundation with visible destinations `Activity`, `Dictation`, `Meetings`, `Assistant`, `Integrations`, `Intelligence`, and `System`.
- Plans 011-014 define the next consolidation/polish slices: merge Dashboard/History into Activity, Models/Text & Context/Dictionary into Intelligence, General/Sound/Permissions into System, then normalize headers, helper copy, and toolbar accessories.

### Skill Deepening Focus

1. Treat settings consolidation as a user-job taxonomy problem, not a row-count exercise: preserve distinct workflows while grouping low-frequency configuration.
2. Require legacy deep links/search routes to resolve before moving visible content so navigation feels stable during sidebar reduction.
3. For consolidated pages, standardize internal navigation and avoid a different subnavigation pattern for each destination.
4. After grouping pages, audit visible copy again; old child-tab descriptions often become redundant under the new parent label.
5. For settings-sidebar polish, preserve native macOS behavior first. A custom sidebar container needs an explicit interaction reason and same-slice verification for selection, search, keyboard, and VoiceOver behavior.
