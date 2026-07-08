---
name: swiftui-patterns
description: This skill should be used when the user asks to "build SwiftUI views", "improve state management", "refactor SwiftUI layouts", or "use design system components".
---

# SwiftUI Patterns

## Role

Use this skill as the canonical owner for SwiftUI composition, state handling, and layout patterns in Prisma.

- Own view composition, navigation, state wrappers, and reusable UI-block guidance.
- Keep SwiftUI implementation advice aligned with design-system reuse, preview expectations, motion restraint, and performance hygiene.
- Delegate UX direction to `native-app-designer` and unknown-root-cause runtime investigation to `debugging-strategies`.

## Scope Boundary

- Use this skill for building SwiftUI views, managing SwiftUI state, and structuring layouts.
- Use `../native-app-designer/SKILL.md` for UI/UX direction.
- Use `../debugging-strategies/SKILL.md` when jank, layout thrash, or excessive updates require investigation before refactoring.

## Overview

Recommended patterns for SwiftUI development in the Prisma project.

## Mandatory Pairing

For macOS/iOS interface tasks, consult `../native-app-designer/SKILL.md` first to define UX/UI direction and acceptance criteria.
Then use this skill to implement view composition, state handling, and layout patterns.

## When to Use

Activate this skill when working with:
- State property wrappers (`@State`, `@StateObject`, `@ObservedObject`)
- Navigation (`NavigationStack`, `NavigationView`)
- SwiftUI views and modifiers
- View lifecycle and composition
- Motion implementation and reduced-motion fallbacks
- Render/update performance hygiene when changing view structure

Keep motion implementation local, purposeful, and easy to disable. Do not introduce matched-geometry or shader machinery unless the product surface clearly earns it.

## Reusable Components First

Before writing new UI code, treat the interface as reusable blocks:

- Search existing design-system/UI blocks first (`SettingsListGroup`, `DSGroup`, `DSCard`, `DSToggleRow`, `DSCallout`, `DSBadge`, `DSModifierShortcutEditor`, `DSThemePicker` and related components).
- Apply `reuse -> extend -> create`:
  - **Reuse** when an existing component already fits.
  - **Extend** when the component can absorb the variant without breaking existing usage.
  - **Create** only when the pattern is genuinely new or cannot be represented coherently by extension.
- Avoid copy-paste view composition for repeated visual structures.

## Key Concepts

### State Management

```swift
// ✅ CORRECT - @StateObject for owned reference types
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
}

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()

    var body: some View {
        Button(action: viewModel.toggleRecording) {
            Text(viewModel.isRecording ? "Stop" : "Start")
        }
    }
}

// ❌ WRONG - @State for shared reference
struct BadView: View {
    @State private var sharedService = SharedService() // Violates ownership
}
```

### Navigation (iOS 16+)

Use `NavigationStack` for type-safe navigation:

```swift
// ✅ CORRECT - NavigationStack with typed path
struct AppNavigation: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    case .detail(let id):
                        DetailView(id: id)
                    }
                }
        }
    }
}

enum Route: Hashable {
    case settings
    case detail(id: String)
}
```

## Common Patterns

### View Modifiers

Group related modifiers and extract common chains:

```swift
// Group related modifiers
Text("Title")
    .font(.title)
    .fontWeight(.bold)
    .foregroundColor(.primary)

// Extract common chains
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}
```

### Performance Optimization

```swift
// Lazy loading for large lists
LazyVStack {
    ForEach(recordings) { recording in
        RecordingRow(recording: recording)
    }
}

// Identity for views that need redraw
struct ContentView: View {
    @State private var items: [Item] = []

    var body: some View {
        List($items) { $item in
            ItemRow(item: $item)
        }
        .id(items.id) // Force redraw when ID changes
    }
}
```

Performance hygiene:

- Keep computed view state cheap and deterministic.
- Avoid re-running expensive formatting, filtering, sorting, or localization lookups in `body`.
- For lists, dashboards, and settings pages, keep row identity stable and avoid rebuilding large derived arrays during every render.
- Extract complex row bodies into focused subviews when repeated or hard to scan.
- When a UI performance symptom is not obviously structural, capture a repro and route through `../debugging-strategies/SKILL.md` before broad refactoring.

### Motion

- Use animation to clarify state transitions, not as decoration.
- Honor reduced-motion settings on motion-heavy surfaces.
- Prefer built-in SwiftUI transitions and simple springs over custom shader or matched-geometry machinery.
- Keep recording, status, and permission-state motion deterministic so tests and previews remain stable.

## Settings UI Patterns

### Settings UX Consistency Checklist

- Use drill-down rows consistently for secondary settings pages.
- For any settings row that pushes a secondary page from a `NavigationStack`, reuse `SettingsDrillDownListRow`.
- For button-driven drill-downs inside `SettingsListGroup`, use `SettingsListDrillDownButtonRow`.
- Keep row anatomy stable: title, optional short subtitle, disclosure indicator.
- Avoid repeating the same title or description in the page header and again in the first settings card unless the card introduces materially new context.
- Prefer inline descriptive copy for the page-level explanation. Reserve info popovers/tooltips for secondary guidance, edge cases, or optional workflows.
- If two or more info affordances appear in the same local cluster, consolidate them into one helper surface unless each serves a clearly distinct purpose.
- Ensure keyboard navigation works (Tab/Arrow/Enter/Escape) across rows and detail pages.
- Surface explicit loading/empty/success/warning states in dynamic settings blocks.
- Keep destructive actions visually separated from neutral actions.
- Pair row title/description semantics for VoiceOver and include clear accessibility hints.
- Settings sidebar page-changing items should share one button row style, including the bottom Settings destination. Do not mix `NavigationLink` sidebar rows with custom buttons for equivalent page navigation.

### Design System

Use the project's Design System tokens/components to keep UI consistent and DRY:

- Tokens: `MeetingAssistantDesignSystem`
- List containers: `SettingsListGroup`
- Content containers: `DSGroup`, `DSCard`
- Rows and controls: `DSToggleRow`, `SettingsListDrillDownButtonRow`, `SettingsDrillDownListRow`, `DSCallout`, `DSBadge`, `DSModifierShortcutEditor`, `DSThemePicker`
- Always evaluate reusing/extending these components before introducing custom wrappers in feature views.
- Keyboard shortcut registration sections should use `MAShortcutSettingsSection` (instead of duplicating section layout). Keep a single consolidated helper affordance for shortcut context plus optional external remap guidance; do not stack multiple adjacent info popovers or repeat the same warning inline in each settings tab.
- In Settings, use `DSMenuPicker` for simple native `.menu` pickers and `DSMenuSelect` for field-like menu controls such as filters and shortcut selectors. Do not tint neutral menu controls with `.secondary`; it reads as disabled. Do not apply `AppDesignSystem.Colors.accent` as a broad container tint; keep accent scoped to primary actions, selection, status, and intentional highlights.

#### Settings list groups

Use `SettingsListGroup` for plain settings lists: toggles, pickers, value rows, and drill-down rows that should share native list rhythm. `SettingsListGroup` owns row padding and separators.

Do not put `Divider()` inside `SettingsListGroup`. Do not add vertical row padding manually. Do not add a local `.settingsListRow()` modifier. If a row needs custom layout, make the row content itself a single view and let `SettingsListGroup` wrap it.

Use `DSGroup` for content sections that are not simple lists: editors, tables, app pickers, model cards, dense status blocks, callouts plus action clusters, or content with internal grouping.

```swift
SettingsListGroup("Recording", icon: "recordingtape") {
    DSToggleRow(
        "Auto-start recording",
        description: "Optional description text",
        isOn: $viewModel.autoStart
    )

    SettingsListDrillDownButtonRow(
        title: "Advanced",
        subtitle: "Configure advanced recording options"
    ) {
        navigationState.open(.advanced)
    }

    HStack {
        Text("Format")
        Spacer()
        Picker("", selection: $format) { ... }
            .labelsHidden()
            .pickerStyle(.menu)
    }
}
```

```swift
DSGroup("Prompt editor", icon: "terminal.fill") {
    VStack(alignment: .leading, spacing: 12) {
        TextEditor(text: $prompt)
        DSCallout(kind: .info, title: title, message: message)
    }
}
```

#### Background hierarchy in DSGroup

`DSGroup` wraps content in `DSCard(style: .settings)`, which already provides the surface background (`.regularMaterial` or `settingsCardBackground(.subtle)` = `controlBackgroundColor`). **Content inside DSGroup must not add its own `.background()` modifier** — it inherits the card background.

```swift
// ✅ CORRECT — Content inherits DSGroup background
DSGroup("Leaderboard", icon: "list.number") {
    VStack(spacing: 0) {
        header
        rows
    }
}

// ❌ WRONG — Inner background stacks on top of card background,
//     creating visual density and reducing contrast
DSGroup("Leaderboard", icon: "list.number") {
    VStack(spacing: 0) {
        header
        rows
    }
    .background(
        AppDesignSystem.Colors.settingsCardBackground(intensity: .regular),
        in: RoundedRectangle(cornerRadius: 12)
    )
}
```

If sub-grouping is genuinely needed, use a separate `DSGroup`; do not stack `settingsCardBackground(.regular)` on top of `settingsCardBackground(.subtle)`.

### Toggle vs Checkbox

**Always use toggles (switches) instead of checkboxes** when there is no separate "Save" button:

```swift
// ✅ CORRECT - Toggle for immediate-effect settings
DSToggleRow("Enable feature", isOn: $viewModel.isEnabled)

// ❌ WRONG - Checkbox for settings without explicit save
Toggle(isOn: $isEnabled) {
    Text("Enable feature")
}
.toggleStyle(.checkbox) // Misleading UX
```

##### Rationale
Checkboxes imply form-based interaction where changes are batched and saved together. Toggles communicate immediate effect, matching SwiftUI's two-way binding behavior.

### Left-Aligned Layouts

Settings content should be **left-aligned**, not centered:

```swift
// ✅ CORRECT - Left-aligned content
VStack(alignment: .leading, spacing: 20) {
    section1
    section2
}
.padding()
.frame(maxWidth: .infinity, alignment: .leading)

// ❌ WRONG - Centered content
VStack {
    section1
    section2
}
.padding()
// Default center alignment
```

### Compound Buttons with Dropdown

Create unified buttons with integrated dropdown using custom Menu:

```swift
HStack(spacing: 0) {
    // Main action button
    Button { onStart(.all) } label: {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
            Text("Start Recording")
        }
        .frame(maxWidth: .infinity, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    
    // Divider
    Rectangle()
        .fill(Color.white.opacity(0.3))
        .frame(width: 1, height: 24)
    
    // Dropdown with hidden indicator
    Menu {
        // Menu items
    } label: {
        Color.clear
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
    .menuIndicator(.hidden)
    .overlay {
        Image(systemName: "chevron.down")
            .allowsHitTesting(false)
    }
}
.background(Color.blue)
.clipShape(Capsule())
```

## Common Pitfalls

1. **Shared state** - Use `@StateObject`, not `@State` for injection
2. **Old NavigationView** - Use `NavigationStack` on iOS 16+
3. **Deep nesting** - Extract subviews for clarity
4. **Bindings in loops** - Use `ForEach($items) { $item in }`
5. **Centered settings** - Use `.leading` alignment and `frame(maxWidth: .infinity, alignment: .leading)`
6. **Checkboxes for settings** - Use `SettingsToggle` or `.toggleStyle(.switch)`

## Preview Requirements

- Every SwiftUI `View` must include at least one `#Preview`.
- Add more than one preview when state variations are relevant.
- Keep previews deterministic and side-effect free.
- Use `PreviewRuntime.isRunning` for startup task suppression when needed.
- Use `PreviewStateContainer` when interactive bindings are required.
- Validate coverage with `make preview-check`.

## Related Skills

- `../native-app-designer/SKILL.md`
- `../debugging-strategies/SKILL.md`
- `../preview-coverage/SKILL.md`

## References

- [SettingsPage.swift](Packages/MeetingAssistantCore/Sources/UI/pages/settings/SettingsPage.swift)
- [TranscriptionStatusPage.swift](Packages/MeetingAssistantCore/Sources/UI/pages/transcription/TranscriptionStatusPage.swift)
- `.agents/skills/preview-coverage/SKILL.md`

## 2026-06-30 Progression Drill

### New Evidence

- `64723e9d` consolidated app-search UI into `AppSearchInlineSection` and renamed the sheet to the reusable `AppSearchSheet`.
- `b953d6ad` split the shortcut editor into focused components (`ShortcutRecorderController`, `ShortcutChipRow`, `ShortcutKeyCode`, `ModifierShortcutKeyTokenLabel`) and removed `DSModifierShortcutEditor`.
- `68dd959f` extracted `UserPromptsSettingsTab`, shrinking `DictationSettingsTab` and giving prompts their own settings composition.

### Skill Deepening Focus

1. Before adding settings UI, search for reusable inline sections and sheets; prefer extending `AppSearchInlineSection`/`AppSearchSheet` for app-picking flows.
2. Split complex control anatomy by responsibility: controller bridge, display token, chip row, and domain key-code model should not live in one SwiftUI view.
3. Keep settings tabs as composition roots. Move reusable behavior into components or view models once a tab starts mixing unrelated concerns.
4. When extracting tabs/components, update previews, settings search entries, and localized strings in the same slice.

## 2026-07-01 Progression Drill

### New Evidence

- `7c568e46` added `SettingsSection.visibleSections`, `visibleSection`, and `resolvedVisibleSection(for:)` so settings UI can reduce visible rows without breaking old raw values.
- Plans 011-013 explicitly require new container tabs (`ActivitySettingsTab`, `IntelligenceSettingsTab`, `SystemSettingsTab`) that reuse existing tab bodies instead of copying Dashboard, History, Models, Text & Context, Dictionary, General, Sound, or Permissions UI.
- Plan 014 calls out repeated helper copy and oversized settings tabs, including `AudioSettingsTab.swift` above the preferred size boundary.

### Skill Deepening Focus

1. For settings containers, add only the parent route/selector and pass bindings down; do not paste child tab bodies into the new parent.
2. Keep legacy section resolution centralized in `SettingsSection` and `SettingsPage` request handling; avoid one-off redirects in toolbar, search, or warning call sites.
3. Use one internal navigation pattern across Activity, Intelligence, and System unless the content shape clearly differs.
4. If consolidation touches an already-large tab, extract focused child components before adding more layout code.
