# Plan 040: Migrate UI state to Observation at stable boundaries

> **Executor instructions**: This is a staged architecture migration. Do not convert all 47 `ObservableObject` types in one pass. Every stage needs focused tests and a thermo review before the next boundary is migrated.
>
> **Drift check**: `git diff --stat 80ed5788..HEAD -- Packages/MeetingAssistantCore/Sources/UI App/MeetingAssistantApp.swift Packages/MeetingAssistantCore/Sources/Infrastructure/Models/AppSettingsStore Packages/MeetingAssistantCore/Tests plans/README.md`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/039-align-swift6-concurrency-baseline.md
- **Category**: migration
- **Planned at**: commit `80ed5788`, 2026-07-12

## Why this matters

Prisma's SwiftUI layer uses `ObservableObject`/`@Published` across 47 production files and has no `@Observable` production types. That is a significant gap from the modern Observation data-flow model and makes ownership, bindings, and actor isolation harder to reason about. The migration must preserve Combine/AppKit integration boundaries rather than force a risky repository-wide rewrite.

## Current state

- `SettingsView` owns `@StateObject private var navigationService` in `SettingsPage.swift:42`.
- `AppSettingsStore`, `NavigationService`, and many UI ViewModels publish mutable state through Combine.
- `AssistantVoiceCommandService` is already `@MainActor`, a useful exemplar for UI-bound state ownership.
- Existing tests instantiate ViewModels directly, so initialization and dependency injection seams can be preserved.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Focused settings tests | `swift test --package-path Packages/MeetingAssistantCore --filter 'SettingsSectionTests|SettingsSearchIndexTests|AppSettingsStoreCapabilityTests|AppSettingsDictationStylesTests'` | exit 0 |
| Preview coverage | `make preview-check` | exit 0 |
| Build | `make build-agent` | exit 0 |
| Full gates | `make lint && make build-test` | exit 0, with baseline classified |

## Scope

**In scope**:

- One migration slice of settings/navigation UI state, selected from `NavigationService`, `SettingsView`, and one directly owned settings ViewModel.
- `Observation` imports/macros, `@State`, `@Bindable`, and `@Environment` wiring for that slice.
- Tests covering state ownership, bindings, navigation requests, and ViewModel lifecycle.
- `plans/README.md`

**Out of scope**:

- Audio callbacks, Core Data managed objects, XPC services, and model runtimes.
- Removing Combine from services that still expose publisher-based integration contracts.
- Converting singleton ownership without a replacement dependency-injection seam.
- A mass mechanical replacement of property wrappers.

## Steps

### Step 1: Select and characterize one UI boundary

Choose the smallest coherent settings/navigation boundary. Document who creates the observable state, who observes it, and which bindings cross into child views. Add characterization tests before changing wrappers if the current behavior lacks coverage.

**Verify**: focused settings tests -> all existing and new characterization tests pass.

### Step 2: Convert ownership and bindings

Use the modern shape:

```swift
@MainActor
@Observable
final class ExampleViewModel { ... }

struct ExampleView: View {
    @State private var viewModel = ExampleViewModel()
}
```

Use a local `@Bindable` only where a child control needs bindings. Use `@Environment` for shared app-scoped state only after ownership is explicit. Keep Combine adapters at the boundary when AppKit or legacy services require them.

**Verify**: `make build-agent && make preview-check` -> both exit 0.

### Step 3: Add regression tests and review

Test initial state, external navigation requests, binding writes, cancellation, and teardown. Run thermo review focused on ownership, duplicate instances, view lifetime, stale bindings, and accidental singleton retention. Correct all Critical/Medium findings.

**Verify**: focused tests pass and the review has no unresolved Critical/Medium findings.

### Step 4: Decide the next migration slice

Record the migrated boundary and remaining Combine integration points in the plan ledger or a follow-up plan. Do not migrate another subsystem in the same change.

**Verify**: `git diff --stat` shows only the selected boundary and its tests.

## Done criteria

- [x] One coherent UI boundary uses `@Observable` with explicit `@MainActor` ownership.
- [x] Child bindings use `@Bindable` or direct state bindings; no new manual `Binding(get:set:)` was added.
- [x] Existing navigation/settings behavior and previews remain covered.
- [x] Focused tests, `make build-agent`, and `make preview-check` pass.
- [x] Thermo review has no unresolved Critical/Medium findings.
- [x] No audio, persistence, XPC, or model runtime types were migrated.
- [x] `plans/README.md` status row updated.

## STOP conditions

- The selected boundary requires changing a public service protocol or Core Data object.
- Observation causes duplicate state instances or loses a deep-link/navigation event.
- A ViewModel cannot be isolated without changing an audio, persistence, or XPC callback contract.

## Completed slice

- Migrated `GeneralSettingsViewModel` to `@MainActor @Observable`.
- Updated `GeneralSettingsTab`, `AudioSettingsTab`, and `DictationSettingsTab` to own the model with `@State`.
- Kept `Combine` only for the existing `AudioDeviceManager` publisher integration, marked as an Observation boundary.
- Added `GeneralSettingsObservationTests` covering observed state changes; remaining settings ViewModels and integration seams stay on `ObservableObject` for later slices.

## Maintenance notes

Future migrations should follow the same boundary-first approach. `ObservableObject` remains acceptable at integration seams until the seam itself has a replacement. Reviewers should reject a migration whose only benefit is changing property-wrapper names without improving ownership.
