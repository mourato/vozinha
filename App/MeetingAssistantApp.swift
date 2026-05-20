import AppKit
import Combine
import KeyboardShortcuts
import MeetingAssistantCore
import os
import SwiftUI

/// Main entry point for the Prisma app.
/// Runs as a menu bar application without a dock icon.
@main
struct MeetingAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        clearLegacyLanguageOverrideIfNeeded()
    }

    var body: some Scene {
        Settings {
            SettingsSceneBridgeView()
        }
        .commands {
            MeetingAssistantCommands()
        }
    }
}

private func clearLegacyLanguageOverrideIfNeeded() {
    let defaults = UserDefaults.standard
    let selectedLanguage = defaults.string(forKey: "selectedLanguage")

    // Keep system language behavior stable across launches, even if a stale override exists.
    if selectedLanguage == nil || selectedLanguage == "system" {
        defaults.removeObject(forKey: "AppleLanguages")
    }
}

private struct SettingsSceneBridgeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasForwarded = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
            .task {
                guard !hasForwarded else { return }
                hasForwarded = true

                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.settingsWindowController.showSettingsWindow()
                }

                dismiss()
            }
    }
}

private struct AppCommandKeyboardShortcut {
    let key: KeyEquivalent
    let modifiers: EventModifiers
}

private struct OptionalCommandKeyboardShortcutModifier: ViewModifier {
    let shortcut: AppCommandKeyboardShortcut?

    func body(content: Content) -> some View {
        if let shortcut {
            content.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
        } else {
            content
        }
    }
}

private enum AppCommandShortcutDisplaySource {
    case inHouse(ShortcutDefinition)
    case preset
    case custom(KeyboardShortcuts.Shortcut)
    case none
}

@MainActor
final class AppCommandRouter: ObservableObject {
    struct Handlers {
        let toggleDictation: () -> Void
        let toggleMeeting: () -> Void
        let toggleAssistant: () -> Void
        let cancelCapture: () -> Void
        let openSettings: () -> Void
        let openHistory: () -> Void
        let openOnboarding: () -> Void
        let checkForUpdates: () -> Void
        let quit: () -> Void
    }

    static let shared = AppCommandRouter()

    @Published private(set) var state = AppCommandState()

    private var toggleDictationHandler: (() -> Void)?
    private var toggleMeetingHandler: (() -> Void)?
    private var toggleAssistantHandler: (() -> Void)?
    private var cancelCaptureHandler: (() -> Void)?
    private var openSettingsHandler: (() -> Void)?
    private var openHistoryHandler: (() -> Void)?
    private var openOnboardingHandler: (() -> Void)?
    private var checkForUpdatesHandler: (() -> Void)?
    private var quitHandler: (() -> Void)?

    private init() {}

    func registerHandlers(_ handlers: Handlers) {
        toggleDictationHandler = handlers.toggleDictation
        toggleMeetingHandler = handlers.toggleMeeting
        toggleAssistantHandler = handlers.toggleAssistant
        cancelCaptureHandler = handlers.cancelCapture
        openSettingsHandler = handlers.openSettings
        openHistoryHandler = handlers.openHistory
        openOnboardingHandler = handlers.openOnboarding
        checkForUpdatesHandler = handlers.checkForUpdates
        quitHandler = handlers.quit
    }

    func update(state: AppCommandState) {
        guard self.state != state else { return }
        self.state = state
    }

    func toggleDictation() {
        toggleDictationHandler?()
    }

    func toggleMeeting() {
        toggleMeetingHandler?()
    }

    func toggleAssistant() {
        toggleAssistantHandler?()
    }

    func cancelCapture() {
        cancelCaptureHandler?()
    }

    func openSettings() {
        if let openSettingsHandler {
            openSettingsHandler()
        } else {
            NavigationService.shared.openSettings()
        }
    }

    func toggleSettingsSidebar() {
        openSettings()
        NavigationService.shared.requestSettingsSidebarToggle()
    }

    func openHistory() {
        if let openHistoryHandler {
            openHistoryHandler()
        } else {
            NavigationService.shared.openSettings(section: SettingsSection.transcriptions.rawValue)
        }
    }

    func openOnboarding() {
        if let openOnboardingHandler {
            openOnboardingHandler()
        } else {
            NavigationService.shared.openOnboarding()
        }
    }

    func checkForUpdates() {
        if let checkForUpdatesHandler {
            checkForUpdatesHandler()
        } else {
            NavigationService.shared.checkForUpdates()
        }
    }

    func bringAllToFront() {
        NSApp.arrangeInFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func quit() {
        quitHandler?()
    }
}

struct MeetingAssistantCommands: Commands {
    @ObservedObject private var commandRouter = AppCommandRouter.shared
    @ObservedObject private var navigationService = NavigationService.shared

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("menubar.settings".localized) {
                commandRouter.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .appInfo) {
            Divider()

            Button("menubar.check_updates".localized) {
                commandRouter.checkForUpdates()
            }
        }

        CommandMenu("commands.capture.title".localized) {
            if commandRouter.state.showsDictationAction {
                Button(commandRouter.state.dictationTitleKey.localized) {
                    commandRouter.toggleDictation()
                }
                .modifier(OptionalCommandKeyboardShortcutModifier(shortcut: appCommandKeyboardShortcut(for: .dictationToggle)))
            }

            if commandRouter.state.showsMeetingAction {
                Button(commandRouter.state.meetingTitleKey.localized) {
                    commandRouter.toggleMeeting()
                }
                .modifier(OptionalCommandKeyboardShortcutModifier(shortcut: appCommandKeyboardShortcut(for: .meetingToggle)))
            }

            if commandRouter.state.showsAssistantAction {
                Button(commandRouter.state.assistantTitleKey.localized) {
                    commandRouter.toggleAssistant()
                }
                .modifier(OptionalCommandKeyboardShortcutModifier(shortcut: appCommandKeyboardShortcut(for: .assistantCommand)))
            }

            if commandRouter.state.showsCancelAction {
                Divider()

                Button(commandRouter.state.cancelTitleKey.localized) {
                    commandRouter.cancelCapture()
                }
                .modifier(
                    OptionalCommandKeyboardShortcutModifier(
                        shortcut: appCommandKeyboardShortcut(for: commandRouter.state.cancelRecordingShortcutDefinition)
                    )
                )
            }
        }

        CommandGroup(replacing: .sidebar) {
            Button(sidebarTitle) {
                commandRouter.toggleSettingsSidebar()
            }
            .keyboardShortcut("S", modifiers: [.command, .control])
        }

        CommandGroup(after: .sidebar) {
            Button("menubar.history".localized) {
                commandRouter.openHistory()
            }
        }

        CommandGroup(after: .windowArrangement) {
            Button("commands.window.bring_all_to_front".localized) {
                commandRouter.bringAllToFront()
            }
        }

        CommandGroup(after: .help) {
            Button("menubar.onboarding".localized) {
                commandRouter.openOnboarding()
            }
        }
    }

    private var sidebarTitle: String {
        let key = navigationService.isSettingsSidebarVisible
            ? "commands.view.hide_sidebar"
            : "commands.view.show_sidebar"
        return key.localized
    }
}

extension ShortcutDefinition {
    var menuDisplayString: String {
        let modifierSymbols = modifiers.map { modifier in
            switch modifier {
            case .leftCommand, .rightCommand, .command: "⌘"
            case .leftShift, .rightShift, .shift: "⇧"
            case .leftOption, .rightOption, .option: "⌥"
            case .leftControl, .rightControl, .control: "⌃"
            case .fn: "Fn"
            }
        }

        var tokens = modifierSymbols
        if let primaryKey {
            tokens.append(primaryKey.display)
        } else if trigger == .doubleTap, let first = modifierSymbols.first {
            tokens.append(first)
        }

        return tokens.joined()
    }
}

@MainActor
private func appCommandShortcutDisplaySource(
    for shortcutName: KeyboardShortcuts.Name
) -> AppCommandShortcutDisplaySource {
    let settings = AppSettingsStore.shared

    switch shortcutName {
    case .dictationToggle:
        return resolveShortcutDisplaySource(
            definition: settings.dictationShortcutDefinition,
            hasModifierShortcut: settings.dictationModifierShortcutGesture != nil,
            selectedPresetKey: settings.dictationSelectedPresetKey,
            fallbackShortcutName: shortcutName
        )
    case .assistantCommand:
        return resolveShortcutDisplaySource(
            definition: settings.assistantShortcutDefinition,
            hasModifierShortcut: settings.assistantModifierShortcutGesture != nil,
            selectedPresetKey: settings.assistantSelectedPresetKey,
            fallbackShortcutName: shortcutName
        )
    case .meetingToggle:
        return resolveShortcutDisplaySource(
            definition: settings.meetingShortcutDefinition,
            hasModifierShortcut: settings.meetingModifierShortcutGesture != nil,
            selectedPresetKey: settings.meetingSelectedPresetKey,
            fallbackShortcutName: shortcutName
        )
    default:
        guard let shortcut = KeyboardShortcuts.Shortcut(name: shortcutName) else {
            return .none
        }
        return .custom(shortcut)
    }
}

private func resolveShortcutDisplaySource(
    definition: ShortcutDefinition?,
    hasModifierShortcut: Bool,
    selectedPresetKey: PresetShortcutKey,
    fallbackShortcutName: KeyboardShortcuts.Name
) -> AppCommandShortcutDisplaySource {
    if let definition {
        return .inHouse(definition)
    }

    if hasModifierShortcut {
        return .none
    }

    if selectedPresetKey != .custom, selectedPresetKey != .notSpecified {
        return .preset
    }

    guard let shortcut = KeyboardShortcuts.Shortcut(name: fallbackShortcutName) else {
        return .none
    }
    return .custom(shortcut)
}

@MainActor
private func appCommandKeyboardShortcut(for shortcutName: KeyboardShortcuts.Name) -> AppCommandKeyboardShortcut? {
    switch appCommandShortcutDisplaySource(for: shortcutName) {
    case let .inHouse(shortcut):
        appCommandKeyboardShortcut(for: shortcut)
    case let .custom(shortcut):
        appCommandKeyboardShortcut(forCustomShortcut: shortcut)
    case .preset, .none:
        nil
    }
}

@MainActor
private func appCommandKeyboardShortcut(for shortcutDefinition: ShortcutDefinition?) -> AppCommandKeyboardShortcut? {
    guard let shortcutDefinition else { return nil }
    guard shortcutDefinition.trigger == .singleTap, let primaryKey = shortcutDefinition.primaryKey else {
        return nil
    }
    guard let keyEquivalent = keyEquivalent(for: primaryKey) else {
        return nil
    }
    return AppCommandKeyboardShortcut(
        key: keyEquivalent,
        modifiers: eventModifiers(from: shortcutDefinition.modifiers)
    )
}

@MainActor
private func appCommandKeyboardShortcut(forCustomShortcut shortcut: KeyboardShortcuts.Shortcut) -> AppCommandKeyboardShortcut? {
    let normalizedKey = normalizedShortcutKey(from: shortcut.description)
    guard let keyEquivalent = keyEquivalent(from: normalizedKey) else { return nil }
    return AppCommandKeyboardShortcut(
        key: keyEquivalent,
        modifiers: EventModifiers(shortcut.modifiers)
    )
}

private func normalizedShortcutKey(from description: String) -> String {
    let modifierSymbols = ["⌘", "⌥", "⌃", "⇧"]
    var cleanKey = description
    for symbol in modifierSymbols {
        cleanKey = cleanKey.replacingOccurrences(of: symbol, with: "")
    }
    return cleanKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

private func keyEquivalent(for primaryKey: ShortcutPrimaryKey) -> KeyEquivalent? {
    switch primaryKey.kind {
    case .space:
        KeyEquivalent.space
    case .function:
        nil
    default:
        keyEquivalent(from: primaryKey.display.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

private func keyEquivalent(from normalizedKey: String) -> KeyEquivalent? {
    switch normalizedKey {
    case "space":
        return KeyEquivalent.space
    case "return", "enter":
        return KeyEquivalent.return
    case "tab":
        return KeyEquivalent.tab
    case "backspace", "delete":
        return KeyEquivalent.delete
    case "escape", "esc":
        return KeyEquivalent.escape
    case "left":
        return KeyEquivalent.leftArrow
    case "right":
        return KeyEquivalent.rightArrow
    case "up":
        return KeyEquivalent.upArrow
    case "down":
        return KeyEquivalent.downArrow
    default:
        guard let character = normalizedKey.first, normalizedKey.count == 1 else {
            return nil
        }
        return KeyEquivalent(character)
    }
}

private func eventModifiers(from modifiers: [ModifierShortcutKey]) -> EventModifiers {
    modifiers.reduce(into: EventModifiers()) { partialResult, modifier in
        switch modifier {
        case .leftCommand, .rightCommand, .command:
            partialResult.insert(.command)
        case .leftShift, .rightShift, .shift:
            partialResult.insert(.shift)
        case .leftOption, .rightOption, .option:
            partialResult.insert(.option)
        case .leftControl, .rightControl, .control:
            partialResult.insert(.control)
        case .fn:
            break
        }
    }
}

private extension EventModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.command) {
            insert(.command)
        }
        if flags.contains(.shift) {
            insert(.shift)
        }
        if flags.contains(.option) {
            insert(.option)
        }
        if flags.contains(.control) {
            insert(.control)
        }
    }
}

/// App delegate for menu bar setup and lifecycle management.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    struct RecordingUIRenderState: Equatable {
        let isRecording: Bool
        let isStarting: Bool
        let isTranscribing: Bool
        let isAssistantRecording: Bool
        let isAssistantProcessing: Bool
        let meetingTypeRawValue: String?
        let isMeetingNotesPanelVisible: Bool
    }

    let logger = Logger(subsystem: AppIdentity.logSubsystem, category: "AppDelegate")
    var statusItem: NSStatusItem?
    var contextMenu: NSMenu?
    var dictateMenuItem: NSMenuItem?
    var recordMeetingMenuItem: NSMenuItem?
    var assistantMenuItem: NSMenuItem?
    var cancelRecordingMenuItem: NSMenuItem?
    lazy var recordingManager: RecordingManager = .shared
    let settingsStore = AppSettingsStore.shared
    let localModelResidencyCoordinator = LocalModelResidencyCoordinator.shared
    lazy var floatingIndicatorController = FloatingRecordingIndicatorController()
    lazy var meetingNotesPanelController = MeetingNotesFloatingPanelController()
    lazy var globalShortcutController = GlobalShortcutController(recordingManager: RecordingManager.shared)
    lazy var assistantVoiceCommandService = AssistantVoiceCommandService(
        indicator: floatingIndicatorController
    )
    lazy var assistantShortcutController = AssistantShortcutController(
        assistantService: assistantVoiceCommandService
    )
    lazy var recordingCancelShortcutController = RecordingCancelShortcutController(
        stateProvider: { [weak self] in
            guard let self else {
                return RecordingCancelShortcutState(
                    isRecordingManagerCaptureActive: false,
                    isAssistantCaptureActive: false
                )
            }
            return RecordingCancelShortcutState(
                isRecordingManagerCaptureActive: recordingManager.isRecording || recordingManager.isStartingRecording,
                isAssistantCaptureActive: assistantVoiceCommandService.isRecording
            )
        },
        cancelRecordingManagerCapture: { [weak self] in
            await self?.recordingManager.cancelRecording()
        },
        cancelAssistantCapture: { [weak self] in
            await self?.assistantVoiceCommandService.cancelRecording()
        }
    )
    lazy var onboardingController = OnboardingWindowController()
    lazy var settingsWindowController = SettingsWindowController()
    var cancellables = Set<AnyCancellable>()
    var dockObserver: AnyCancellable?
    var hasConfiguredCapabilityObservers = false
    var lastRecordingUIRenderState: RecordingUIRenderState?
}

@MainActor
final class SettingsWindowController {
    private enum Layout {
        static let defaultContentSize = NSSize(width: 900, height: 640)
        static let sidebarWidthRange: ClosedRange<CGFloat> = 220...260
        static let frameMargin: CGFloat = 12
    }

    private var window: NSWindow?

    func showSettingsWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.setContentSize(Layout.defaultContentSize)
        settingsWindow.contentMinSize = Layout.defaultContentSize
        settingsWindow.styleMask.insert(.fullSizeContentView)
        settingsWindow.title = "settings.title".localized
        settingsWindow.titleVisibility = .hidden
        settingsWindow.titlebarAppearsTransparent = true
        settingsWindow.toolbarStyle = .unified
        settingsWindow.toolbar = NSToolbar(identifier: NSToolbar.Identifier(AppIdentity.settingsToolbarIdentifier))
        settingsWindow.isOpaque = false
        settingsWindow.backgroundColor = .clear
        settingsWindow.isMovableByWindowBackground = false
        settingsWindow.tabbingMode = .disallowed
        if #available(macOS 11.0, *) {
            settingsWindow.titlebarSeparatorStyle = .none
        }

        let layoutEvaluation = evaluatePersistedLayoutState()
        resetPersistedLayoutIfNeeded(using: layoutEvaluation)

        settingsWindow.setFrameAutosaveName(AppIdentity.settingsWindowAutosaveName)
        settingsWindow.isReleasedWhenClosed = false
        let hostingController = NSHostingController(rootView: SettingsView())
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        settingsWindow.contentViewController = hostingController
        settingsWindow.contentView?.wantsLayer = true
        settingsWindow.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        if layoutEvaluation.shouldCenterWindow {
            settingsWindow.center()
        }

        if layoutEvaluation.requiresFrameClamp {
            clampWindowFrameIfNeeded(settingsWindow)
        }

        settingsWindow.makeKeyAndOrderFront(nil)

        if layoutEvaluation.requiresFrameClamp {
            clampWindowFrameIfNeeded(settingsWindow)
        }

        window = settingsWindow
        NSApp.activate(ignoringOtherApps: true)
    }

    private func evaluatePersistedLayoutState() -> SettingsWindowLayoutStateEvaluation {
        SettingsWindowLayoutStateEvaluator.evaluate(
            visibleScreenFrames: NSScreen.screens.map(\.visibleFrame),
            defaultContentSize: Layout.defaultContentSize,
            sidebarWidthRange: Layout.sidebarWidthRange
        )
    }

    private func resetPersistedLayoutIfNeeded(using evaluation: SettingsWindowLayoutStateEvaluation) {
        guard evaluation.shouldResetPersistedLayout else {
            return
        }

        let defaults = UserDefaults.standard
        for key in evaluation.keysToReset {
            defaults.removeObject(forKey: key)
        }
    }

    private func clampWindowFrameIfNeeded(_ window: NSWindow) {
        guard let targetScreenFrame = bestVisibleFrame(for: window.frame) else {
            return
        }

        let clampedFrame = clampedFrame(for: window.frame, within: targetScreenFrame)
        guard !window.frame.equalTo(clampedFrame) else {
            return
        }

        window.setFrame(clampedFrame, display: false)
    }

    private func bestVisibleFrame(for frame: NSRect) -> NSRect? {
        let midpoint = NSPoint(x: frame.midX, y: frame.midY)

        if let midpointScreen = NSScreen.screens.first(where: { $0.visibleFrame.contains(midpoint) }) {
            return midpointScreen.visibleFrame
        }

        if let mainScreenFrame = NSScreen.main?.visibleFrame {
            return mainScreenFrame
        }

        return NSScreen.screens.first?.visibleFrame
    }

    private func clampedFrame(for frame: NSRect, within visibleFrame: NSRect) -> NSRect {
        let availableWidth = max(visibleFrame.width - (Layout.frameMargin * 2), 0)
        let availableHeight = max(visibleFrame.height - (Layout.frameMargin * 2), 0)

        let width = min(frame.width, availableWidth)
        let height = min(frame.height, availableHeight)

        let maxX = visibleFrame.maxX - Layout.frameMargin - width
        let maxY = visibleFrame.maxY - Layout.frameMargin - height

        let originX = min(max(frame.minX, visibleFrame.minX + Layout.frameMargin), maxX)
        let originY = min(max(frame.minY, visibleFrame.minY + Layout.frameMargin), maxY)

        return NSRect(x: originX, y: originY, width: width, height: height)
    }
}
