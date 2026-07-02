---
name: menubar
description: This skill should be used when the user asks to "build menu bar behavior", "configure NSStatusItem", "implement popover", or "manage non-activating floating panels".
---

# Menu Bar Applications

## Role

Use this skill as the canonical owner for menu-bar-specific UI patterns in Prisma.

- Own `NSStatusItem`, popover, status-menu, and non-activating menu-bar interaction guidance.
- Keep menu-bar behavior aligned with macOS-native patterns and app lifecycle expectations.
- Delegate general macOS implementation and broader UI/UX direction to their specialist owners.

## Scope Boundary

- Use this skill for status-item behavior, menu-bar menus, popovers, and floating-panel interaction patterns.
- Use `../macos-development/SKILL.md` for general platform lifecycle and integration concerns.
- Use `../native-app-designer/SKILL.md` for native interaction quality and broader experience design decisions.

## Overview

Specific patterns for macOS menu bar applications using NSStatusItem.

## When to Use

Activate this skill when working with:
- `NSStatusItem`
- `NSStatusBar`
- `NSMenu`
- `NSStatusBarButton`
- `NSPopover`
- Menu bar app development

## Key Concepts

### Context Menu Behavior

**Right-click** on `NSStatusItem` should show context menu:

```swift
class MenuBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }

    @objc private func handleRightClick(_ sender: NSStatusBarButton) {
        closePopover() // Close popover before showing menu
        showContextMenu(sender)
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = createContextMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
```

### Dynamic Menu Items

Store references to update titles dynamically:

```swift
class MenuBarController {
    private var startStopMenuItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var isRecording = false

    func createMenu() {
        startStopMenuItem = createMenuItem(
            key: "menubar.recording.toggle",
            action: #selector(toggleRecording)
        )
        statusMenuItem = createMenuItem(
            key: "menubar.status",
            action: nil
        )

        let menu = NSMenu()
        menu.addItem(startStopMenuItem)
        menu.addItem(statusMenuItem)
        statusItem.menu = menu
    }

    private func createMenuItem(key: String, action: Selector?) -> NSMenuItem {
        NSMenuItem(
            title: key.localized,
            action: action,
            keyEquivalent: ""
        )
    }

    func updateUIState(isRecording: Bool) {
        self.isRecording = isRecording
        let titleKey = isRecording ? "menubar.recording.stop" : "menubar.recording.start"
        startStopMenuItem.title = titleKey.localized
        updateStatusIcon(isRecording: isRecording)
    }
}
```

### State Reflection

Update UI state together with icon and tooltip:

```swift
func updateStatusIcon(isRecording: Bool) {
    let iconName = isRecording ? "record.circle.fill" : "circle"
    statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    statusItem.button?.toolTip = isRecording ?
        "recording.in_progress".localized : nil
}
```

## Common Patterns

### Menu Bar with Popover

```swift
final class MeetingAssistantMenuBar {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var recordingManager: RecordingManager

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        setup()
    }

    private func setup() {
        popover.contentViewController = MenuBarViewController()
        popover.behavior = .transient

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: nil)
            button.action = #selector(togglePopover)
            button.target = self

            // Right-click for context menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
}
```

## Floating Panel Patterns

### Always-Visible Recording Indicator

Create floating panels that remain visible above all windows:

```swift
final class FloatingRecordingIndicatorController {
    private var panel: NSPanel?
    
    func show(with hostingView: NSView) {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Critical settings for always-visible behavior
        panel.level = .screenSaver       // Above full-screen apps
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false           // SwiftUI handles shadows
        
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel
    }
    
    func updatePosition(_ position: IndicatorPosition) {
        guard let screen = NSScreen.main, let panel = panel else { return }
        let screenFrame = screen.visibleFrame
        // Calculate position and set panel frame...
    }
}
```

### Window Level Reference

From lowest to highest priority:
1. `.normal` - Standard app windows
2. `.floating` - Utility panels, inspectors
3. `.statusBar` - Menu bar level
4. `.modalPanel` - Modal sheets
5. `.screenSaver` - ⭐ **Best for always-visible indicators**

## Reactive State Observation

### Observing Recording State

Use Combine to reactively show/hide floating indicators:

```swift
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var recordingManager: RecordingManager!
    private var indicatorController: FloatingRecordingIndicatorController!
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        observeRecordingState()
    }
    
    private func observeRecordingState() {
        recordingManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if isRecording {
                    self?.showFloatingIndicator()
                } else {
                    self?.hideFloatingIndicator()
                }
            }
            .store(in: &cancellables)
    }
}
```

### Critical Pattern: Decouple Trigger from UI

The recording can start from multiple sources (menu bar, shortcut, API). The floating indicator should **observe state**, not be triggered directly:

```swift
// ❌ WRONG - Indicator tied to specific trigger
func menuBarStartRecording() {
    recordingManager.startRecording()
    showFloatingIndicator()  // Missed if recording starts via shortcut!
}

// ✅ CORRECT - Indicator observes state reactively
init() {
    recordingManager.$isRecording
        .sink { [weak self] isRecording in
            isRecording ? self?.show() : self?.hide()
        }
        .store(in: &cancellables)
}
```

## Common Pitfalls

1. **Stuck popover** - Always call `closePopover()` before other actions
2. **Menu doesn't update** - Keep references to dynamic menu items
3. **Click outside** - Configure `popover.behavior = .transient`
4. **Memory leaks** - Use `[weak self]` in closures
5. **Indicator not visible** - Use `.screenSaver` window level, not `.floating`
6. **Indicator tied to trigger** - Observe state reactively via Combine

## Related Skills

- `../macos-development/SKILL.md`
- `../native-app-designer/SKILL.md`

## References

- [MenuBar.swift](App/AppDelegate/MenuBar.swift)
- [FloatingRecordingIndicatorView.swift](Packages/MeetingAssistantCore/Sources/UI/components/recording/FloatingRecordingIndicatorView/FloatingRecordingIndicatorView.swift)
- [Apple Status Bar Guide](https://developer.apple.com/documentation/appkit/nsstatusitem)

## 2026-03-06 Progression Drill

### New Evidence

- `f7243e0` improved status bar reliability and floating indicator layout via AppDelegate menu bar wiring.
- `166643c` refactored shared recording UI state used by menu bar + lifecycle flows.
- `094d280` launch visibility recovery indicates menu bar presence/activation is still a fragile startup concern.

### Skill Deepening Focus

1. Add a startup visibility checklist for `NSStatusItem`: creation timing, icon/title fallback, and post-launch verification path.
2. Require one explicit state-flow diagram in task notes when menu bar and floating panel share recording state.
3. Validate left-click/right-click parity after lifecycle refactors to avoid regressions in popover/menu behavior.
4. Enforce localized tooltip/title verification whenever status-item fallback text or state labels change.
