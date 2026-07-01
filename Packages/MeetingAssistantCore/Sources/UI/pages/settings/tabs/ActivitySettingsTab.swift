import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

public enum ActivitySettingsRoute: Hashable {
    case dashboard
    case history
}

public struct ActivitySettingsTab: View {
    @Binding private var activeRoute: ActivitySettingsRoute
    @Binding private var metricsNavigationState: SettingsSubpageNavigationState<MetricsDashboardRoute>
    @Binding private var transcriptionsNavigationHistory: TranscriptionsNavigationHistory
    @Binding private var transcriptionsSearchText: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    public init(
        activeRoute: Binding<ActivitySettingsRoute> = .constant(.dashboard),
        metricsNavigationState: Binding<SettingsSubpageNavigationState<MetricsDashboardRoute>> = .constant(SettingsSubpageNavigationState()),
        transcriptionsNavigationHistory: Binding<TranscriptionsNavigationHistory> = .constant(TranscriptionsNavigationHistory()),
        transcriptionsSearchText: Binding<String> = .constant("")
    ) {
        _activeRoute = activeRoute
        _metricsNavigationState = metricsNavigationState
        _transcriptionsNavigationHistory = transcriptionsNavigationHistory
        _transcriptionsSearchText = transcriptionsSearchText
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack {
            Picker("", selection: $activeRoute) {
                Text("settings.section.metrics".localized)
                    .tag(ActivitySettingsRoute.dashboard)
                Text("settings.section.history".localized)
                    .tag(ActivitySettingsRoute.history)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
            .padding(.leading, 24)

            Spacer()
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch activeRoute {
        case .dashboard:
            MetricsDashboardSettingsTab(navigationState: $metricsNavigationState)
        case .history:
            TranscriptionsSettingsTab(
                searchText: $transcriptionsSearchText,
                navigationHistory: $transcriptionsNavigationHistory
            )
        }
    }
}

#Preview {
    ActivitySettingsTab()
        .frame(width: 900, height: 620)
}
