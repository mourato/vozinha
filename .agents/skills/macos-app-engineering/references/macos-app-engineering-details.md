# macOS App Engineering — Prisma implementation reference

Prisma-specific Settings, SwiftUI, AppKit, preview, and UX guidance. Role, scope, and routing live in `../SKILL.md`.

## Execution sequence

1. Classify risk using `AGENTS.md`.
2. Scan reusable blocks before creating UI helpers: reuse → extend → create.
3. Set UX acceptance criteria before editing layout.
4. Implement in small slices with existing design-system components.
5. Validate with focused checks: `make preview-check`, `make guidance-check`, and lane gates via `delivery-workflow`.

## UI/UX direction

- Primary actions and hierarchy should be understandable within a few seconds.
- Prefer semantic colors/materials and existing design-system tokens over hardcoded values.
- Keep layouts native-feeling and task-focused; avoid decorative wrappers when a standard macOS control communicates the job better.
- Use motion to clarify state changes, not as decoration.
- Keep motion local, deterministic, and easy to disable.
- In settings screens, keep one primary explanation per cluster. Do not repeat the same title or description across headers, cards, tooltips, and popovers.
- Treat popovers/help affordances as escalation; consolidate redundant copy.
- Prefer one canonical primary window per workflow surface.
- Prefer in-window navigation, split view, sheet, or popover before adding another primary surface.
- Preserve predictable keyboard ownership and window targeting.

## SwiftUI composition and state

- Own reference-type state with `@StateObject`; pass externally owned objects with `@ObservedObject` or environment.
- Keep UI-bound state on the main actor.
- Avoid expensive formatting, filtering, sorting, or localization lookup directly in `body`.
- Keep list/row identity stable in dashboards, histories, Settings pages, and status surfaces.
- Extract complex row bodies into focused subviews when they repeat.
- Use `NavigationStack`/typed routes where surrounding code already uses them.
- Avoid copy-paste view composition; reuse or extend the nearest existing component first.

## Settings and design-system patterns

Search existing UI blocks before adding new ones. Common reusable blocks:

- `SettingsListGroup`, `DSGroup`, `DSCard`, `DSToggleRow`
- `SettingsDrillDownListRow`, `SettingsListDrillDownButtonRow`
- `DSCallout`, `DSBadge`, `DSMenuPicker`, `DSThemePicker`

Use `SettingsListGroup` for plain settings lists. It owns row padding and separators. Do not put `Divider()` inside `SettingsListGroup`, add manual vertical row padding, or add a local `.settingsListRow()` modifier.

Use `DSGroup` for composed content: editors, tables, app pickers, model cards, dense status blocks. Content inside `DSGroup` should not add another card-like background.

Use drill-down rows consistently:

- `SettingsDrillDownListRow` for `NavigationStack` secondary pages.
- `SettingsListDrillDownButtonRow` for button-driven drill-downs inside `SettingsListGroup`.

Use native picker anatomy for ordinary Settings values:

- Inside a SwiftUI `Form`, prefer a direct native `Picker` with a visible label.
- Apply `.pickerStyle(.menu)` when the intended control is a menu.
- Do not use `.labelsHidden()` for ordinary `Form` settings rows.
- `DSMenuPicker` is valid outside `Form` for compact filters, dashboards, and fixed-width action rows — not as a substitute for a native `Form` picker.
- Do not tint neutral menu controls with `.secondary`; it reads as disabled.
- Keep accent color scoped to primary actions, selection, status, and intentional highlights.

Boolean controls by save semantics:

```swift
// Immediate-effect setting
DSToggleRow("Enable feature", isOn: $viewModel.isEnabled)

// Draft value committed by Save/Create
Toggle(isOn: $draftValue) { Text("Enable feature") }
.toggleStyle(.checkbox)
```

## Motion, performance, and rendering

- Use built-in SwiftUI transitions and simple springs before custom animation infrastructure.
- Honor reduced-motion behavior for motion-heavy surfaces.
- Keep recording, status, permission, and warning-state motion deterministic.
- Route unclear performance symptoms through `debugging-diagnostics` before broad refactors.
- Prefer stable dimensions and row identity for toolbars, counters, status pills, grids, and settings rows.

## macOS platform integration

- Prefer SwiftUI for view policy and AppKit for capabilities SwiftUI cannot express well.
- Use AppKit bridging only when SwiftUI behavior is insufficient.
- Prevent retain cycles in escaping closures; release observers, taps, monitors, and handles deterministically.
- Respect sandbox and entitlement constraints; check cancellation for long-running tasks.

Lifecycle-sensitive UI invariants:

1. Status item and hotkeys register exactly once at startup.
2. Settings open/close paths do not duplicate observers or callbacks.
3. `NSApp` activation behavior is explicit per flow.
4. Teardown unregisters transient handlers.
5. Shortcut capture flows recover cleanly after permissions or focus changes.
6. Floating overlays behave deterministically across launch, restart, settings transitions, and background/foreground changes.

## Preview requirements

- Every `struct ...: View` under `MeetingAssistantCoreUI` needs at least one `#Preview`.
- Add multiple previews for meaningful states: idle, loading, success, error, collapsed, expanded.
- Keep previews deterministic and side-effect free.
- Use `PreviewRuntime.isRunning` and `PreviewStateContainer` when needed.
- Verify with `make preview-check`.

## Verification

```bash
make preview-check
make guidance-check
make build-agent
```

Use `make preview-check` for SwiftUI view changes and `make guidance-check` after editing guidance docs. Final lane evidence is owned by `make validate-agent` (see `delivery-workflow`).

For lifecycle-sensitive UI, note the relevant flow: startup → settings open → close → reopen, shortcut after relaunch, or overlay show/update/hide.

## Historical progression notes

- Settings consolidation is a user-job taxonomy problem, not a row-count exercise.
- Legacy deep links and search routes should resolve before visible content moves.
- After grouping pages, audit visible copy for redundant parent/child labels.
- Simple settings rows default to native list rhythm via `SettingsListGroup`; use `DSGroup` only for composed content.
- Keep settings tabs as composition roots; extract reusable behavior into components or view models.
