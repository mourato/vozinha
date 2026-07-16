---
name: menubar
description: This skill should be used when the user asks to "build menu bar behavior", "configure NSStatusItem", "implement popover", or "manage non-activating floating panels".
---

# Menu Bar Applications

## Role

Canonical owner for menu-bar-specific UI patterns in Prisma: `NSStatusItem`, popover, status-menu, and non-activating panel behavior aligned with macOS-native patterns and app lifecycle.

## Scope Boundary

- Use this skill for status-item behavior, menu-bar menus, popovers, and floating-panel interaction patterns.
- Use `../macos-app-engineering/SKILL.md` for general macOS UI/app lifecycle, SwiftUI composition, and broader experience decisions.

## When to Use

Trigger for `NSStatusItem`, `NSStatusBar`, `NSMenu`, `NSStatusBarButton`, `NSPopover`, or menu-bar app development.

## Non-negotiable rules

- **Right-click** shows a context menu; **left-click** toggles the popover (do not conflate the two).
- Call `closePopover()` before showing a context menu or starting other actions.
- Use `popover.behavior = .transient` so click-outside dismisses the popover.
- Floating indicators use `.screenSaver` window level (not `.floating`) for always-visible behavior.
- Panels use `[.borderless, .nonactivatingPanel]` with `collectionBehavior` including `.canJoinAllSpaces` and `.fullScreenAuxiliary`.
- **Observe recording state reactively** (Combine/`@Published`) — never tie indicator visibility to a single trigger path.
- Keep references to dynamic menu items so titles update when state changes.
- Use `[weak self]` in closures; localize tooltips and menu titles via `"key".localized`.

## Routed references

Read [menubar patterns](references/menubar-patterns.md) for code samples and deep interaction patterns:

| Request | Reference sections |
|---|---|
| Context menu and dynamic items | Context menu behavior; dynamic menu items |
| Popover setup | Menu bar with popover |
| Floating recording indicator | Floating panel patterns; window levels |
| Reactive state wiring | Reactive state observation; decouple trigger from UI |
| Pitfalls and startup | Common pitfalls; startup visibility checklist |

## Related Skills

- `../macos-app-engineering/SKILL.md`

## References

- [MenuBar.swift](../../../App/AppDelegate/MenuBar.swift)
- [FloatingRecordingIndicatorView.swift](../../../Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift)
