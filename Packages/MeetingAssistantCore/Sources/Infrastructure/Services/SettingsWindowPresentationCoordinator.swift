import AppKit
import Foundation

@MainActor
public final class SettingsWindowPresentationCoordinator {
    public typealias ActivationPolicyProvider = @MainActor () -> NSApplication.ActivationPolicy
    public typealias ActivationPolicySetter = @MainActor (NSApplication.ActivationPolicy) -> Void
    public typealias AppActivator = @MainActor () -> Void
    public typealias WindowOpener = @MainActor () -> Void
    public typealias WindowFocuser = @MainActor () -> Void

    private let activationPolicy: ActivationPolicyProvider
    private let setActivationPolicy: ActivationPolicySetter
    private let activateApp: AppActivator
    private let focusSettingsWindow: WindowFocuser

    private var openSettingsWindow: WindowOpener?
    private var hasPendingOpenRequest = false

    public init(
        activationPolicy: @escaping ActivationPolicyProvider,
        setActivationPolicy: @escaping ActivationPolicySetter,
        activateApp: @escaping AppActivator,
        focusSettingsWindow: @escaping WindowFocuser
    ) {
        self.activationPolicy = activationPolicy
        self.setActivationPolicy = setActivationPolicy
        self.activateApp = activateApp
        self.focusSettingsWindow = focusSettingsWindow
    }

    public func registerOpenWindowHandler(_ handler: @escaping WindowOpener) {
        openSettingsWindow = handler

        guard hasPendingOpenRequest else { return }
        hasPendingOpenRequest = false

        DispatchQueue.main.async { [weak self] in
            self?.openSettings()
        }
    }

    public func openSettings() {
        if activationPolicy() != .regular {
            setActivationPolicy(.regular)
        }

        activateApp()

        guard let openSettingsWindow else {
            hasPendingOpenRequest = true
            return
        }

        openSettingsWindow()
        focusSettingsWindow()
    }

    @discardableResult
    public func handleApplicationReopen(hasVisibleWindows: Bool) -> Bool {
        guard activationPolicy() == .regular, !hasVisibleWindows else {
            return false
        }

        openSettings()
        return true
    }

    public func settingsWindowDidClose(
        showInDock: Bool,
        hasOtherVisibleNormalWindow: Bool
    ) {
        guard !showInDock, !hasOtherVisibleNormalWindow else { return }
        guard activationPolicy() != .accessory else { return }

        setActivationPolicy(.accessory)
    }
}
