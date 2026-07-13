import SwiftUI

public struct ActivitySettingsTab: View {
    @StateObject private var viewModel = MetricsDashboardViewModel()
    @Binding private var navigationState: ActivitySettingsNavigationState
    @Binding private var transcriptionsSearchText: String

    @MainActor
    public init(
        navigationState: Binding<ActivitySettingsNavigationState> = .constant(ActivitySettingsNavigationState()),
        transcriptionsSearchText: Binding<String> = .constant(""),
    ) {
        _navigationState = navigationState
        _transcriptionsSearchText = transcriptionsSearchText
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        switch navigationState.activeRoute {
        case .root:
            rootPage
        case .history:
            TranscriptionsSettingsTab(
                searchText: $transcriptionsSearchText,
                navigationHistory: $navigationState.transcriptionsNavigationHistory,
            )
        case .modelPerformance, .moreInsights, .eventDetail:
            MetricsDashboardSettingsTab(navigationState: $navigationState.metricsNavigationState)
        }
    }

    private var rootPage: some View {
        ActivityDashboardRootPage(
            viewModel: viewModel,
            openHistory: { navigationState.open(.history) },
            openMoreInsights: { navigationState.open(.moreInsights) },
            openPerformance: { navigationState.open(.modelPerformance) },
            openEventDetail: { navigationState.open(.eventDetail($0)) },
        )
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingAssistantTranscriptionSaved)) { notification in
            Task {
                await viewModel.handleTranscriptionSaved(notification)
            }
        }
    }
}

#Preview {
    ActivitySettingsTab()
        .frame(width: 900, height: 620)
}
