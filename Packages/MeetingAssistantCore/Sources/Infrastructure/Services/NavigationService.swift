import AppKit
import Combine
import MeetingAssistantCoreCommon

/// Service to handle navigation and window management across the app.
@MainActor
public class NavigationService: ObservableObject {
    public static let shared = NavigationService()

    @Published public var requestedSettingsSection: String?
    @Published public var requestedActivitySubroute: String?
    @Published public private(set) var settingsSidebarToggleRequestID: UInt64 = 0
    @Published public private(set) var isSettingsSidebarVisible = true
    private var openSettingsHandler: (@MainActor () -> Void)?
    private var openOnboardingHandler: (@MainActor () -> Void)?
    private var hasPendingOpenSettingsRequest = false

    private init() {}

    /// Registers an explicit settings opener provided by the app target.
    public func registerOpenSettingsHandler(_ handler: @escaping @MainActor () -> Void) {
        openSettingsHandler = handler

        guard hasPendingOpenSettingsRequest else { return }
        hasPendingOpenSettingsRequest = false

        DispatchQueue.main.async {
            handler()
        }
    }

    /// Registers an explicit onboarding opener provided by the app target.
    public func registerOpenOnboardingHandler(_ handler: @escaping @MainActor () -> Void) {
        openOnboardingHandler = handler
    }

    /// Opens the settings/dashboard window.
    public func openSettings() {
        if let openSettingsHandler {
            openSettingsHandler()
            return
        }

        // The SwiftUI settings window opener may register after AppDelegate launch work.
        // Queue one pending request instead of falling back to the legacy Settings scene API.
        hasPendingOpenSettingsRequest = true
    }

    /// Opens the settings window and requests a specific section.
    public func openSettings(section: String) {
        requestedSettingsSection = section
        openSettings()
    }

    public func openOnboarding() {
        openOnboardingHandler?()
    }

    public func requestSettingsSidebarToggle() {
        settingsSidebarToggleRequestID &+= 1
    }

    public func setSettingsSidebarVisible(_ isVisible: Bool) {
        guard isSettingsSidebarVisible != isVisible else { return }
        isSettingsSidebarVisible = isVisible
    }

    /// Shows the About alert.
    public func showAbout() {
        let alert = NSAlert()
        alert.messageText = "about.title".localized
        alert.informativeText =
            "about.version".localized(with: AppVersion.current) + "\n\n" +
            "about.description".localized + "\n\n" +
            "about.copyright".localized(with: 2_025)
        alert.alertStyle = .informational
        alert.icon = NSImage(
            systemSymbolName: "waveform.circle.fill",
            accessibilityDescription: "about.title".localized
        )
        alert.addButton(withTitle: "common.ok".localized)

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// Triggers a user-initiated update check via Sparkle.
    public func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }
}
