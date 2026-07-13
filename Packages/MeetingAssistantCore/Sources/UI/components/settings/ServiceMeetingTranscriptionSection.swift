import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct ServiceMeetingTranscriptionSection: View {
    @ObservedObject private var viewModel: ServiceSettingsViewModel

    public init(viewModel: ServiceSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSGroup("settings.models.meeting_transcription.title".localized, icon: "waveform.and.person.filled") {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.models.meeting_transcription.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("settings.service.model".localized)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    DSMenuPicker(
                        selection: Binding(
                            get: { viewModel.selectedMeetingLocalModel },
                            set: { viewModel.updateMeetingLocalModel($0) },
                        ),
                    ) {
                        ForEach(viewModel.localModels) { localModel in
                            Text(localModel.displayName).tag(localModel.model)
                        }
                    }
                }

                if viewModel.shouldShowMeetingDiarizationAutoDisableWarning {
                    DSCallout(
                        kind: .warning,
                        title: "settings.service.transcription_provider.meeting_diarization_warning.title".localized,
                        message: "settings.service.transcription_provider.meeting_diarization_warning.message".localized(
                            with: viewModel.meetingLocalModelDisplayName,
                        ),
                    )
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("settings.service.diarization_model_name".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("settings.models.meeting_transcription.diarization_description".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            viewModel.isDiarizationLoaded
                                ? "settings.service.installed".localized
                                : "settings.service.not_installed".localized,
                        )
                        .font(.caption2)
                        .foregroundStyle(viewModel.isDiarizationLoaded ? AppDesignSystem.Colors.success : .secondary)
                    }

                    Spacer()

                    if viewModel.isDiarizationLoaded {
                        Button(role: .destructive) {
                            viewModel.deleteDiarizationModels()
                        } label: {
                            Label("settings.models.local_models.remove".localized, systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            viewModel.downloadDiarizationModels()
                        } label: {
                            Label("settings.models.local_models.download".localized, systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

#Preview {
    ServiceMeetingTranscriptionSection(viewModel: ServiceSettingsViewModel())
        .padding()
        .frame(width: 760)
}
