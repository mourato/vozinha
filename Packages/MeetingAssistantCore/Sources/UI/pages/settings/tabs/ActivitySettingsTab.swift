import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import SwiftUI

public struct ActivitySettingsTab: View {
    @Binding private var navigationState: ActivitySettingsNavigationState
    @Binding private var transcriptionsSearchText: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    public init(
        navigationState: Binding<ActivitySettingsNavigationState> = .constant(ActivitySettingsNavigationState()),
        transcriptionsSearchText: Binding<String> = .constant("")
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
                navigationHistory: $navigationState.transcriptionsNavigationHistory
            )
        case .modelPerformance, .moreInsights:
            MetricsDashboardSettingsTab(navigationState: $navigationState.metricsNavigationState)
        }
    }

    private var rootPage: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.activity".localized,
                description: "settings.activity.description".localized
            )

            DSGroup("settings.section.activity".localized, icon: "chart.line.uptrend.xyaxis") {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsDrillDownButtonRow(
                        title: "settings.activity.recording_history.title".localized,
                        subtitle: "settings.activity.recording_history.subtitle".localized,
                        accessibilityHint: "settings.activity.recording_history.accessibility_hint".localized
                    ) {
                        navigationState.open(.history)
                    }

                    Divider()

                    SettingsDrillDownButtonRow(
                        title: "metrics.performance.link.title".localized,
                        subtitle: "settings.activity.model_performance.subtitle".localized,
                        accessibilityHint: "metrics.performance.link.accessibility_hint".localized
                    ) {
                        navigationState.open(.modelPerformance)
                    }

                    Divider()

                    SettingsDrillDownButtonRow(
                        title: "metrics.more_insights.title".localized,
                        subtitle: "settings.activity.more_insights.subtitle".localized,
                        accessibilityHint: "metrics.more_insights.accessibility_hint".localized
                    ) {
                        navigationState.open(.moreInsights)
                    }
                }
            }
        }
    }
}

#Preview {
    ActivitySettingsTab()
        .frame(width: 900, height: 620)
}
