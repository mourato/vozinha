import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct ServiceTranscriptionProviderSection: View {
    @ObservedObject private var viewModel: ServiceSettingsViewModel
    @ObservedObject private var settings: AppSettingsStore

    public init(
        viewModel: ServiceSettingsViewModel,
        settings: AppSettingsStore = .shared
    ) {
        self.viewModel = viewModel
        _settings = ObservedObject(wrappedValue: settings)
    }

    public var body: some View {
        DSGroup("settings.models.transcription_provider.title".localized, icon: "network") {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.service.transcription_provider.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("settings.service.transcription_provider.provider".localized)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.selectedDictationProviderRawValue },
                            set: { viewModel.updateDictationProvider(rawValue: $0) }
                        )
                    ) {
                        ForEach(viewModel.availableDictationProviders, id: \.rawValue) { provider in
                            Text(displayName(for: provider)).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("settings.service.transcription_provider.model".localized)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.selectedDictationModel },
                            set: { viewModel.updateDictationModel($0) }
                        )
                    ) {
                        ForEach(viewModel.availableDictationModels, id: \.self) { modelID in
                            Text(viewModel.displayName(forModelID: modelID)).tag(modelID)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("settings.service.transcription_provider.input_language".localized)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Picker(
                        "",
                        selection: Binding(
                            get: { viewModel.selectedInputLanguageHintRawValue },
                            set: { viewModel.updateTranscriptionInputLanguageHint(rawValue: $0) }
                        )
                    ) {
                        ForEach(viewModel.availableInputLanguageHints, id: \.rawValue) { hint in
                            Text(hint.displayName).tag(hint.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text("settings.service.transcription_provider.input_language.help".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.shouldShowRemoteTranscriptionAPIKeyActions {
                    if viewModel.isDictationProviderReady {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(AppDesignSystem.Colors.success)
                            Text("settings.ai.keychain_secure".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                viewModel.removeTranscriptionAPIKey()
                            } label: {
                                Text("settings.ai.remove_key".localized)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppDesignSystem.Colors.error)
                            .controlSize(.regular)
                        }
                    } else {
                        DSCallout(
                            kind: .warning,
                            title: "settings.service.transcription_provider.missing_key.title".localized(
                                with: viewModel.selectedRemoteProviderDisplayName
                            ),
                            message: "settings.service.transcription_provider.missing_key.message".localized(
                                with: viewModel.selectedRemoteProviderDisplayName
                            )
                        )
                    }

                    if viewModel.shouldShowInlineTranscriptionAPIKeyInput {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("settings.ai.api_key".localized)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)

                            SecureField(
                                "settings.ai.api_key_placeholder".localized,
                                text: Binding(
                                    get: { viewModel.transcriptionAPIKeyInput },
                                    set: { viewModel.transcriptionAPIKeyInput = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            Button("common.save".localized) {
                                viewModel.saveTranscriptionAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(!viewModel.hasPendingTranscriptionAPIKeyInput)
                        }

                        if let keyError = viewModel.transcriptionAPIKeyErrorMessage,
                           !keyError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        {
                            DSCallout(
                                kind: .error,
                                title: "common.error".localized,
                                message: keyError
                            )
                        }
                    }

                    if let url = viewModel.selectedRemoteProviderGetAPIKeyURL {
                        Button(
                            "settings.service.transcription_provider.get_api_key".localized(
                                with: viewModel.selectedRemoteProviderDisplayName
                            )
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }

                DSCallout(
                    kind: .info,
                    title: "settings.service.transcription_provider.meeting_local.title".localized,
                    message: "settings.service.transcription_provider.meeting_local.message".localized(with: viewModel.meetingLocalModelDisplayName)
                )

                if settings.isMeetingTranscriptionEnabled,
                   viewModel.shouldShowMeetingDiarizationAutoDisableWarning
                {
                    DSCallout(
                        kind: .warning,
                        title: "settings.service.transcription_provider.meeting_diarization_warning.title".localized,
                        message: "settings.service.transcription_provider.meeting_diarization_warning.message".localized(with: viewModel.meetingLocalModelDisplayName)
                    )
                }

                if viewModel.isMeetingLocalCohereSelected, !viewModel.isMeetingLocalCohereInstalled {
                    DSCallout(
                        kind: .warning,
                        title: "settings.service.transcription_provider.local_cohere_unavailable.title".localized,
                        message: "settings.service.transcription_provider.local_cohere_unavailable.message".localized
                    )

                    Button("settings.service.transcription_provider.download_cohere_coming_soon".localized) {
                        viewModel.downloadMeetingLocalCohereModel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(viewModel.isASRDownloadInProgress)
                    .help("settings.service.transcription_provider.download_cohere_coming_soon.help".localized)

                    if let errorMessage = viewModel.cohereDownloadErrorMessage {
                        DSCallout(
                            kind: .error,
                            title: "settings.service.transcription_provider.cohere_download_failed.title".localized,
                            message: errorMessage
                        )
                    }
                }
            }
        }
    }

    private func displayName(for provider: MeetingAssistantCoreInfrastructure.TranscriptionProvider) -> String {
        switch provider {
        case .local:
            "settings.service.transcription_provider.option.local".localized
        case .groq:
            "settings.service.transcription_provider.option.groq".localized
        case .elevenLabs:
            "settings.service.transcription_provider.option.elevenlabs".localized
        }
    }
}

#Preview {
    ServiceTranscriptionProviderSection(viewModel: ServiceSettingsViewModel())
        .padding()
        .frame(width: 760)
}
