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
    @StateObject private var viewModel: ServiceSettingsViewModel
    @StateObject private var aiSettingsViewModel: AISettingsViewModel
    @StateObject private var postProcessingViewModel: PostProcessingSettingsViewModel

    @MainActor
    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: ServiceSettingsViewModel(settings: settings))
        _aiSettingsViewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
        _postProcessingViewModel = StateObject(wrappedValue: PostProcessingSettingsViewModel(settings: settings))
    }

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.models".localized,
                description: "settings.models.description".localized
            )

            modelHubSectionIntro(
                title: "settings.models.ai_provider_models".localized,
                description: "settings.models.ai_provider_models_desc".localized,
                icon: "sparkles"
            )

            EnhancementsProviderModelsPage(
                viewModel: aiSettingsViewModel,
                postProcessingViewModel: postProcessingViewModel
            )

            modelHubSectionIntro(
                title: "settings.models.transcription_models".localized,
                description: "settings.models.transcription_models_desc".localized,
                icon: "waveform"
            )

            ServiceSettingsContent(
                viewModel: viewModel,
                includeTranscriptionProviderSection: false,
                includeMeetingTranscriptionSection: false
            )
        }
    }

    private func modelHubSectionIntro(title: String, description: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }
}

#Preview {
    ModelsSettingsTab()
}
