---
name: macos-app-engineering
description: Use for macOS UI/app work touching SwiftUI views, AppKit bridging, Settings UI, design-system components, previews, lifecycle, platform behavior, or a SwiftUI API/review pass.
---

# macOS App Engineering

## Role

Own ordinary macOS application **implementation**: SwiftUI composition, settings
surfaces, AppKit bridges, lifecycle, previews, platform availability,
design-system reuse, and (via the review appendix) SwiftUI modern-API review.

## Scope Boundary

Exclusive claim: ordinary macOS UI/app implementation and SwiftUI review
heuristics for this repo.

Route elsewhere:

- Interaction *feel* (gestures, springs, interruptibility, materials/depth,
  typography metrics) → `apple-design`
- Accessibility *audit* (VoiceOver, keyboard/focus, Reduce Motion compliance,
  overlays) → `accessibility-audit`
- Swift *language* style, type safety, module/file naming → `swift-conventions`
- Concurrency remediation → `swift-concurrency-expert`
- Architecture / module boundaries → `architecture`

## When to Use

Trigger for SwiftUI views, Settings navigation/layout, design-system controls,
preview coverage, AppKit panels/status items, lifecycle integration, native
macOS behavior, or a SwiftUI modern-API / maintainability review pass.

## Non-negotiable rules

- Preserve native `NavigationSplitView`/`List(.sidebar)` semantics and existing
  settings taxonomy unless the request explicitly changes them.
- Reuse existing design-system tokens, settings containers, navigation state,
  localization, and search contracts before creating new abstractions.
- Keep AppKit bridging at lifecycle/panel/capability boundaries and preserve
  macOS 15 fallbacks for newer APIs.
- In settings `Form` surfaces, use a native `Picker` with a visible label as
  the default value-control pattern. Reserve `DSMenuPicker` for compact
  controls outside `Form`, such as filters or fixed-width action rows.
- Boolean settings controls follow **save semantics**, not container type.
  Immediate-effect settings (including ordinary Settings `Form` pages that
  write to `AppSettingsStore` as the user changes them) use switch/`Toggle`
  switch style or `DSToggleRow`. Draft values committed only by Save/Create/
  Apply use `.toggleStyle(.checkbox)`. Living inside a `Form` is not a reason
  to use checkboxes.
- Keep previews representative, deterministic, and free of network, Keychain,
  hardware, or destructive persistence side effects.
- Respect Dynamic Type, Reduce Motion, focus, keyboard, VoiceOver, and native
  control behavior — escalate full audits to `accessibility-audit`.
- Prefer Observation for **new** UI state; preserve existing `ObservableObject`
  contracts until an intentional migration.

## Routed references

Read [macOS engineering details](references/macos-app-engineering-details.md)
for implementation guidance, and [SwiftUI review](references/swiftui-review.md)
for a review pass:

| Request | Reference |
|---|---|
| SwiftUI composition/state and performance | Details: composition and state; rendering |
| Settings pages/navigation/design system | Details: Settings and design-system patterns |
| AppKit bridge, lifecycle, panels, capabilities | Details: platform integration |
| Previews and verification | Details: Preview requirements |
| Broad UI direction | Details: UI/UX direction |
| SwiftUI API / review pass | [swiftui-review.md](references/swiftui-review.md) |

## Verification and handoff

Report the owning view/coordinator, reused components/tokens, availability and
accessibility behavior, preview/test commands, and known baseline failures.

## Related Skills

- `../apple-design/SKILL.md`
- `../accessibility-audit/SKILL.md`
- `../swift-conventions/SKILL.md`
- `../swift-concurrency-expert/SKILL.md`

## References

- [Detailed macOS app guidance](references/macos-app-engineering-details.md)
- [SwiftUI review appendix](references/swiftui-review.md)
