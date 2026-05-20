---
name: macos-development
description: This skill should be used when the user asks to "implement a macOS feature", "integrate SwiftUI with AppKit", "fix macOS lifecycle issues", or "apply platform-specific patterns".
---

# macOS Development Standards

## Role

Use this skill as the canonical implementation reference for macOS Swift/SwiftUI/AppKit work in this repository.

## Scope Boundary

- This skill owns implementation guidance for platform lifecycle, architecture usage, UI integration, and system APIs.
- This skill does not replace specialist skills:
  - `native-app-designer` for primary UI/UX direction and experience analysis
  - `quality-assurance` for verification lanes and merge gates
  - `swift-concurrency-expert` for Swift 6.2 diagnostics/remediation
  - `swiftui-performance-audit` for SwiftUI runtime bottlenecks
  - `swiftui-animation` for advanced animation systems

## Core Standards

### Memory and Lifecycle

- Use value/reference semantics intentionally (`struct` vs `class`).
- Prevent retain cycles in escaping closures.
- Release observers, taps, and file handles deterministically.
- Keep side effects bounded to lifecycle entry points.

### Platform Integration

- Follow native macOS interaction patterns.
- Keep accessibility labels/actions complete for interactive UI.
- Respect sandbox and entitlement constraints.
- Use AppKit bridging only where SwiftUI is insufficient.

### Swift Concurrency Baseline

- Protect shared mutable state with actors.
- Keep UI-bound state under `@MainActor`.
- Check cancellation for long-running tasks.
- Avoid blocking primitives with async/await code paths.

## Implementation Workflow

1. Reusable-block scan first: `reuse -> extend -> create`.
2. Implement in small, verifiable slices.
3. Run scoped checks during development (`make scope-check`, targeted tests, `make build-agent` when needed).
4. Apply required merge gates through `quality-assurance`.

## Command Baseline

```bash
make scope-check
make build-agent
make test-smoke
```

For final merge in Medium/High risk work:

```bash
make build-test
make lint
```

## Related Skills

- `../build-macos-apps/SKILL.md` (intake/router)
- `../native-app-designer/SKILL.md` (primary UI/UX direction)
- `../quality-assurance/SKILL.md` (verification policy)
- `../swiftui-patterns/SKILL.md`
- `../menubar/SKILL.md`
- `../audio-realtime/SKILL.md`
- `../localization/SKILL.md`
- `../swift-package-manager/SKILL.md`

## Reference Index

Use detailed references under `references/` for architecture, system APIs, testing, design system, and packaging topics.

## 2026-03 Operational Update

### Lifecycle Contract: Menubar + Hotkeys + Settings

When changes touch app lifecycle, enforce this contract:

1. Status item and hotkeys are registered exactly once at startup.
2. Settings window open/close paths do not duplicate observers or callbacks.
3. NSApp activation rules are explicit per flow (show panel vs background action).
4. Teardown always unregisters transient handlers (notifications, taps, monitors).
5. Shortcut capture flows recover cleanly after permissions or focus changes.

### Verification Focus

- Validate startup -> settings open -> close -> reopen cycle.
- Validate global shortcut after onboarding and after app relaunch.
- Validate menubar interactions without forcing unexpected app activation.

## 2026-03-04 Progression Drill

### New Evidence

- `3d04791` changed shortcut behavior (Enter/Return blocked), touching lifecycle/controller/settings paths.
- Recurrent edits across `AssistantShortcutController` and shortcut settings view models indicate lifecycle fragility.

### Skill Deepening Focus

1. Maintain a single source of truth for shortcut key filtering rules across controller + settings UI.
2. Add lifecycle checkpoints for startup, settings open/close, and post-onboarding hotkey readiness.
3. Require explicit activation-policy assertions for shortcut-triggered UI flows.
4. Track teardown symmetry for every observer/monitor added in lifecycle code.

## 2026-03-05 Progression Drill

### New Evidence

- `1134cd6` reduced static initializer pressure across onboarding/settings lifecycle code.
- `3cc603f` and `05b114a` iterated rapidly on floating recording indicator behavior.
- `0c32f13` removed sendable overlay callback patterns to satisfy actor-isolation constraints.

### Skill Deepening Focus

1. Add an overlay-lifecycle checklist: initialization cost, actor ownership, teardown symmetry, and callback isolation.
2. For floating indicator changes, require one verification pass that covers open/close/reopen and background foreground transitions.
3. Treat static-initializer changes in UI support types as lifecycle-sensitive and verify no startup regressions.
4. Explicitly route actor-isolation diagnostics in UI components to `swift-concurrency-expert` when compiler errors appear.

## 2026-03-06 Progression Drill

### New Evidence

- `094d280` and `918243b` both modified `App/AppDelegate/AppDelegateLifecycle.swift` for launch recovery and prewarm sequencing.
- `f7243e0` and `166643c` repeatedly touched AppDelegate menu bar/recording UI surfaces to stabilize status and floating-indicator behavior.
- File-frequency since last run shows `App/AppDelegate/AppDelegateLifecycle.swift` as the top hotspot (4 commits).

### Skill Deepening Focus

1. Require a lifecycle sequencing checklist for AppDelegate edits: startup registration, initial visibility, deferred prewarm, and teardown symmetry.
2. For floating-indicator lifecycle changes, verify deterministic behavior across first launch, restart, and settings-open transitions.
3. Treat any AppDelegate visibility recovery change as Medium risk minimum and route verification through Full-lane checks.
4. Document one regression guard per lifecycle patch in the task notes (what state failed before, what invariant is now enforced).
