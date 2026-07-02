import Foundation

public enum MeetingSettingsNavigationRoute: Hashable, Equatable {
    case root
    case monitoringTargets
    case meetingPrompts
    case export
}

public struct MeetingSettingsNavigationState: Equatable {
    public var currentRoute: MeetingSettingsNavigationRoute
    public var forwardRoute: MeetingSettingsNavigationRoute?

    public init(
        currentRoute: MeetingSettingsNavigationRoute = .root,
        forwardRoute: MeetingSettingsNavigationRoute? = nil
    ) {
        self.currentRoute = currentRoute
        self.forwardRoute = forwardRoute
    }

    public var canGoBack: Bool {
        currentRoute != .root
    }

    public var canGoForward: Bool {
        forwardRoute != nil
    }

    public mutating func open(_ route: MeetingSettingsNavigationRoute) {
        guard currentRoute != route else { return }
        currentRoute = route
        forwardRoute = nil
    }

    @discardableResult
    public mutating func goBack() -> MeetingSettingsNavigationRoute? {
        guard canGoBack else { return nil }
        forwardRoute = currentRoute
        currentRoute = .root
        return currentRoute
    }

    @discardableResult
    public mutating func goForward() -> MeetingSettingsNavigationRoute? {
        guard let forwardRoute else { return nil }
        currentRoute = forwardRoute
        self.forwardRoute = nil
        return currentRoute
    }
}
