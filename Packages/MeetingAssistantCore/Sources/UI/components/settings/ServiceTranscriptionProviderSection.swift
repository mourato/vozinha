import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct ServiceTranscriptionProviderSection: View {
    @ObservedObject private var viewModel: ServiceSettingsViewModel

    public init(viewModel: ServiceSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSGroup("settings.models.routing.title".localized, icon: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.models.routing.description".localized)
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
                            set: { viewModel.updateDictationProvider(rawValue: $0) },
                        ),
                    ) {
                        ForEach(viewModel.availableDictationProviders, id: \.rawValue) { provider in
                            Text(viewModel.displayName(for: provider)).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("settings.models.routing.active_model".localized)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Text(viewModel.activeDictationTargetSummary)
                        .fontWeight(.medium)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("settings.service.transcription_provider.input_language".localized)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    DSMenuPicker(
                        selection: Binding(
                            get: { viewModel.selectedInputLanguageHintRawValue },
                            set: { viewModel.updateTranscriptionInputLanguageHint(rawValue: $0) },
                        ),
                    ) {
                        ForEach(viewModel.availableInputLanguageHints, id: \.rawValue) { hint in
                            Text(hint.displayName).tag(hint.rawValue)
                        }
                    }
                }

                Text("settings.service.transcription_provider.input_language.help".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ServiceTranscriptionProviderSection(viewModel: ServiceSettingsViewModel())
        .padding()
        .frame(width: 760)
}
