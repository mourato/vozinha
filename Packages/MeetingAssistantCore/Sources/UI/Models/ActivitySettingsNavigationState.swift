import MeetingAssistantCoreDomain

public enum ActivitySettingsRoute: Hashable, Sendable {
    case root
    case history
    case modelPerformance
    case moreInsights
    case eventDetail(MeetingCalendarEventSnapshot)
}

public struct ActivitySettingsNavigationState: Equatable {
    public var activeRoute: ActivitySettingsRoute
    public var forwardRoute: ActivitySettingsRoute?
    public var metricsNavigationState: SettingsSubpageNavigationState<MetricsDashboardRoute>
    public var transcriptionsNavigationHistory: TranscriptionsNavigationHistory

    public init(
        activeRoute: ActivitySettingsRoute = .root,
        forwardRoute: ActivitySettingsRoute? = nil,
        metricsNavigationState: SettingsSubpageNavigationState<MetricsDashboardRoute> = SettingsSubpageNavigationState(),
        transcriptionsNavigationHistory: TranscriptionsNavigationHistory = TranscriptionsNavigationHistory(),
    ) {
        self.activeRoute = activeRoute
        self.forwardRoute = forwardRoute
        self.metricsNavigationState = metricsNavigationState
        self.transcriptionsNavigationHistory = transcriptionsNavigationHistory
    }

    public var isShowingHistoryList: Bool {
        activeRoute == .history && transcriptionsNavigationHistory.currentRoute == .list
    }

    public var canGoBack: Bool {
        switch activeRoute {
        case .root:
            false
        case .history:
            true
        case .modelPerformance, .moreInsights, .eventDetail:
            true
        }
    }

    public var canGoForward: Bool {
        switch activeRoute {
        case .root:
            forwardRoute != nil
        case .history:
            transcriptionsNavigationHistory.canGoForward
        case .modelPerformance, .moreInsights, .eventDetail:
            metricsNavigationState.canGoForward
        }
    }

    public mutating func apply(_ route: ActivitySettingsRoute?) {
        guard let route else { return }
        open(route)
    }

    public mutating func open(_ route: ActivitySettingsRoute) {
        guard activeRoute != route else { return }
        if let metricsRoute = metricsRoute(for: route) {
            metricsNavigationState.open(metricsRoute)
        }
        activeRoute = route
        forwardRoute = nil
    }

    public mutating func goBack() {
        switch activeRoute {
        case .root:
            return
        case .history:
            if transcriptionsNavigationHistory.canGoBack {
                _ = transcriptionsNavigationHistory.goBack()
            } else {
                forwardRoute = activeRoute
                activeRoute = .root
            }
        case .modelPerformance, .moreInsights, .eventDetail:
            if metricsNavigationState.canGoBack, metricsNavigationState.currentRoute != topLevelMetricsRoute {
                _ = metricsNavigationState.goBack()
            } else {
                forwardRoute = activeRoute
                activeRoute = .root
            }
        }
    }

    public mutating func goForward() {
        switch activeRoute {
        case .root:
            guard let forwardRoute else { return }
            open(forwardRoute)
        case .history:
            _ = transcriptionsNavigationHistory.goForward()
        case .modelPerformance, .moreInsights, .eventDetail:
            _ = metricsNavigationState.goForward()
        }
    }

    private var topLevelMetricsRoute: MetricsDashboardRoute? {
        metricsRoute(for: activeRoute)
    }

    private func metricsRoute(for route: ActivitySettingsRoute) -> MetricsDashboardRoute? {
        switch route {
        case .modelPerformance:
            .performance
        case .moreInsights:
            .moreInsights
        case let .eventDetail(event):
            .eventDetail(event)
        case .root, .history:
            nil
        }
    }
}
