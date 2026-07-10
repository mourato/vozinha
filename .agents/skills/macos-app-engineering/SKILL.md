---
name: macos-app-engineering
description: Use for macOS UI/app work that touches SwiftUI views, AppKit bridging, Settings UI, design-system components, interface direction, preview coverage, or platform lifecycle.
---

# macOS App Engineering

## Role

Use this skill as the single primary reference for ordinary macOS UI/app implementation in Prisma.

- Own Apple-platform interface direction, SwiftUI composition, Settings UI patterns, AppKit bridging, preview expectations, and lifecycle-sensitive UI implementation.
- Keep UI work aligned with Prisma's design-system components, native macOS behavior, accessibility awareness, and guidance validation.
- Route specialized problems to narrower skills instead of duplicating their deep rules here.

## Scope Boundary

Use this skill for:

- macOS interface implementation and UX polish
- SwiftUI view composition, state ownership, navigation, layout, rendering hygiene, and previews
- Settings UI structure, design-system component selection, and helper-copy reduction
- AppKit integration decisions for SwiftUI surfaces
- lifecycle-sensitive UI concerns such as settings windows, overlays, hotkeys, and startup/reopen behavior

Use specialist skills when the task is primarily about:

- `../accessibility-audit/SKILL.md` for VoiceOver, focus order, keyboard-only navigation, reduced-motion audits, non-color signals, overlays, and panel accessibility.
- `../localization/SKILL.md` for `.localized` usage, locale-file symmetry, localized accessibility copy, and orphaned key cleanup.
- `../menubar/SKILL.md` for `NSStatusItem`, `NSMenu`, `NSPopover`, status menus, and non-activating floating-panel behavior.
- `../debugging-diagnostics/SKILL.md` when jank, layout thrash, crashes, or flaky runtime behavior have an unclear root cause.
- `../swift-concurrency-expert/SKILL.md` for actor-isolation and `Sendable` compiler diagnostics.
- `../delivery-workflow/SKILL.md` for validation lane policy and merge gates.
- `../code-quality/SKILL.md` for language-agnostic simplification/refactoring.
- `../swift-conventions/SKILL.md` for Swift syntax, type-safety, lint-aligned style, and module conventions.

## When to Use

Use this skill when a task touches macOS UI/app behavior, including:

- building or refactoring SwiftUI views
- changing Settings pages, rows, controls, sidebar behavior, or internal navigation
- choosing design-system components or native macOS controls
- improving UX quality, visual hierarchy, spacing, typography, motion, or interaction behavior
- integrating SwiftUI with AppKit for windows, hosting views, overlays, or lifecycle hooks
- adding or updating SwiftUI previews

## Execution Sequence

1. **Classify risk first** using `AGENTS.md`.
2. **Scan reusable blocks** before creating new UI or platform helpers: reuse -> extend -> create.
3. **Set the UX acceptance criteria** before editing layout: primary action clarity, native feel, visual rhythm, state feedback, accessibility awareness, and redundant-copy removal.
4. **Implement in small slices** using existing design-system components and platform patterns.
5. **Validate with focused checks**: `make preview-check` for SwiftUI view changes, `make guidance-check` for guidance changes, and lane-specific gates through `delivery-workflow`.

## UI/UX Direction

- Primary actions and hierarchy should be understandable within a few seconds.
- Prefer semantic colors/materials and existing design-system tokens over hardcoded values.
- Keep layouts native-feeling and task-focused; avoid decorative wrappers when a standard macOS control communicates the job better.
- Use motion to clarify state changes, not as decoration.
- Keep motion local, deterministic, and easy to disable; avoid shader or matched-geometry machinery unless the product surface clearly earns it and a reduced-motion fallback exists.
- In settings and inspector-style screens, keep one primary explanation per cluster. Do not repeat the same title or description across page headers, section headers, cards, tooltips, and popovers.
- Treat popovers/help affordances as escalation. If nearby popovers explain the same concept or add little beyond visible copy, consolidate or remove them.
- Prefer one canonical primary window per workflow surface. Introduce auxiliary windows only when detached context materially improves the flow.
- Prefer in-window navigation, split view, sheet, or popover before adding another primary workflow surface.
- Preserve predictable keyboard ownership and window targeting when a flow can appear in multiple surfaces.

## SwiftUI Composition and State

- Own reference-type state with `@StateObject`; pass externally owned observable objects with `@ObservedObject` or environment as appropriate.
- Keep UI-bound state on the main actor.
- Keep computed view state cheap and deterministic.
- Avoid expensive formatting, filtering, sorting, localization lookup, or model transformation directly in `body`.
- Keep list/row identity stable, especially in dashboards, histories, Settings pages, and dynamic status surfaces.
- Extract complex row bodies into focused subviews when they repeat or become hard to scan.
- Use `NavigationStack`/typed routes where the surrounding code already uses them; do not introduce a parallel navigation model for a local page.
- Avoid copy-paste view composition. If a visual structure repeats, reuse or extend the nearest existing component first.

## Settings and Design System Patterns

Search existing UI blocks before adding new ones. Common reusable blocks include:

- `SettingsListGroup`
- `DSGroup`
- `DSCard`
- `DSToggleRow`
- `SettingsDrillDownListRow`
- `SettingsListDrillDownButtonRow`
- `DSCallout`
- `DSBadge`
- `DSMenuPicker`
- `DSThemePicker`

Use `SettingsListGroup` for plain settings lists: toggles, pickers, value rows, and drill-down rows that should share native list rhythm. `SettingsListGroup` owns row padding and separators.

Do not put `Divider()` inside `SettingsListGroup`. Do not add vertical row padding manually. Do not add a local `.settingsListRow()` modifier. If a row needs custom layout, make the row content itself a single view and let `SettingsListGroup` wrap it.

Use `DSGroup` for composed content: editors, tables, app pickers, model cards, dense status blocks, callouts plus action clusters, or content with internal grouping. `DSGroup` already wraps content in a settings card; content inside it should not add another card-like background.

Use drill-down rows consistently:

- Use `SettingsDrillDownListRow` for settings rows that navigate to secondary pages from a `NavigationStack`.
- Use `SettingsListDrillDownButtonRow` for button-driven drill-downs inside `SettingsListGroup`.
- Keep row anatomy stable: title, optional short subtitle, and disclosure indicator.

Use native picker anatomy for ordinary Settings values:

- Prefer `DSMenuPicker` or direct `Picker` with `.pickerStyle(.menu)`.
- Do not tint neutral menu controls with `.secondary`; it reads as disabled.
- Keep accent color scoped to primary actions, selection, status, and intentional highlights.
- Keep custom field-like menu controls local to dense dashboard/filter surfaces when native pickers do not fit.

Use boolean controls according to save semantics:

```swift
// Immediate-effect setting
DSToggleRow("Enable feature", isOn: $viewModel.isEnabled)

// Draft value committed by Save/Create
Toggle(isOn: $draftValue) {
    Text("Enable feature")
}
.toggleStyle(.checkbox)
```

Switches imply immediate effect. Checkbox-style controls fit deferred-save forms and sheets where changes are committed with a Save/Create action.

## Motion, Performance, and Rendering

- Use built-in SwiftUI transitions and simple springs before custom animation infrastructure.
- Honor reduced-motion behavior for motion-heavy surfaces.
- Keep recording, status, permission, and warning-state motion deterministic so previews and tests remain stable.
- Capture a repro and route through `debugging-diagnostics` before broad refactors when a performance symptom is not obviously structural.
- Prefer stable dimensions and row identity for fixed-format UI such as toolbars, counters, status pills, grids, and settings rows.

## macOS Platform Integration

- Prefer SwiftUI for view policy and AppKit for platform capabilities that SwiftUI cannot express well.
- Use AppKit bridging only when SwiftUI behavior is insufficient.
- Remember that SwiftUI's declarative layer often owns layout policy; imperative AppKit window/view tweaks can be overridden by SwiftUI content constraints.
- Prevent retain cycles in escaping closures.
- Release observers, taps, monitors, notifications, and file handles deterministically.
- Keep side effects bounded to lifecycle entry points.
- Respect sandbox and entitlement constraints.
- Check cancellation for long-running tasks.
- Avoid blocking primitives in async/await paths.

Lifecycle-sensitive UI changes must preserve these invariants:

1. Status item and hotkeys are registered exactly once at startup.
2. Settings open/close paths do not duplicate observers or callbacks.
3. `NSApp` activation behavior is explicit per flow.
4. Teardown unregisters transient handlers.
5. Shortcut capture flows recover cleanly after permissions or focus changes.
6. Floating overlays and indicators behave deterministically across first launch, restart, settings-open transitions, and background/foreground changes.

## Preview Requirements

- Every `struct ...: View` under `MeetingAssistantCoreUI` must include at least one `#Preview`, either inline or in a colocated preview file within the same owning-type directory.
- Add multiple previews for meaningful states such as idle, loading, success, error, collapsed, expanded, enabled, and disabled.
- Keep previews deterministic and side-effect free. Avoid network calls, model downloads, long-running tasks, and external services.
- Use `PreviewRuntime.isRunning` when a view would otherwise trigger startup work during previews.
- Use `PreviewStateContainer` when interactive bindings are needed.
- For AppKit controllers, preview the underlying SwiftUI rendering surface when possible.
- Verify preview coverage with `make preview-check`.

## Verification

Use the narrowest meaningful checks during iteration, then the lane gate required by `AGENTS.md` and `delivery-workflow`.

Common checks:

```bash
make preview-check
make guidance-check
make build-agent
make scope-check
```

Use `make preview-check` for SwiftUI view additions/refactors and `make guidance-check` after editing `.agents`, `AGENTS.md`, skill indexes, routing docs, or referenced command docs.

For lifecycle-sensitive UI changes, include one manual or automated note that covers the relevant flow, such as startup -> settings open -> close -> reopen, global shortcut after relaunch, or overlay show/update/hide.

## Related Skills

- `../accessibility-audit/SKILL.md`
- `../localization/SKILL.md`
- `../menubar/SKILL.md`
- `../debugging-diagnostics/SKILL.md`
- `../swift-concurrency-expert/SKILL.md`
- `../delivery-workflow/SKILL.md`
- `../code-quality/SKILL.md`
- `../swift-conventions/SKILL.md`
- `../architecture/SKILL.md`

## References

- `AGENTS.md`
- `.agents/SKILLS_INDEX.md`
- `.agents/docs/skill-routing.md`
- `references/design-system.md`
- `references/appkit-integration.md`
- `references/macos-polish.md`
- `references/swiftui-composition.md`
- `references/menu-bar-apps.md`
- `references/concurrency-patterns.md`
- `references/testing-debugging.md`

## Historical Progression Notes

- Settings consolidation should be treated as a user-job taxonomy problem, not a row-count exercise. Preserve distinct workflows while grouping low-frequency configuration.
- Legacy deep links and search routes should resolve before visible content moves, so navigation remains stable during sidebar reductions.
- After grouping pages, audit visible copy again; old child-tab descriptions often become redundant under a new parent label.
- Simple settings rows should default to native-feeling list rhythm and separators. Use `SettingsListGroup` for simple lists and `DSGroup` only for composed content.
- Avoid custom sidebar containers unless there is an explicit interaction, accessibility, keyboard, search, or layout reason and same-slice verification.
- Keep settings tabs as composition roots. Move reusable behavior into components or view models once a tab mixes unrelated concerns.
- When extracting tabs/components, update previews, settings search entries, and localized strings in the same slice.
