import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Models Settings Tab

/// Tab for configuring transcription provider and local model settings.
public struct ModelsSettingsTab: View {
    @MainActor
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.sectionSpacing) {
                SettingsSectionHeader(
                    title: "settings.section.models".localized,
                    description: "settings.models.description".localized
                )

                ServiceSettingsContent()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ModelsSettingsTab()
}
