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
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.models".localized,
                description: "settings.models.description".localized
            )

            ServiceSettingsContent(
                includeTranscriptionProviderSection: false,
                includeMeetingTranscriptionSection: false
            )
        }
    }
}

#Preview {
    ModelsSettingsTab()
}
