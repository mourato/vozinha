import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public enum EnhancementsModelSelectionTarget: String, Identifiable {
    case meeting
    case dictation

    public var id: String {
        rawValue
    }

    var mode: IntelligenceKernelMode {
        switch self {
        case .meeting: .meeting
        case .dictation: .dictation
        }
    }

    var titleKey: String {
        switch self {
        case .meeting: "settings.enhancements.selector.meeting.title"
        case .dictation: "settings.enhancements.selector.dictation.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .meeting: "settings.enhancements.selector.meeting.subtitle"
        case .dictation: "settings.enhancements.selector.dictation.subtitle"
        }
    }
}

public struct EnhancementsModelSelectionControl: View {
    private let target: EnhancementsModelSelectionTarget
    @ObservedObject private var viewModel: AISettingsViewModel
    private let settings: AppSettingsStore
    @State private var isShowingModelSelection = false

    public init(
        target: EnhancementsModelSelectionTarget,
        viewModel: AISettingsViewModel,
        settings: AppSettingsStore
    ) {
        self.target = target
        self.viewModel = viewModel
        self.settings = settings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(target.titleKey.localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(target.subtitleKey.localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(selectionSummary) {
                    isShowingModelSelection = true
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoadingEnhancementsProviderModels || viewModel.enhancementsProviderModels.isEmpty)

                Button {
                    viewModel.refreshEnhancementsProviderModelsManually()
                } label: {
                    if viewModel.isLoadingEnhancementsProviderModels {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("settings.ai.model_refresh".localized)
                .disabled(viewModel.isLoadingEnhancementsProviderModels)
            }

            if viewModel.enhancementsProviderModels.isEmpty, !viewModel.isLoadingEnhancementsProviderModels {
                Text("settings.enhancements.model_selector.empty".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            viewModel.refreshEnhancementsProviderModelsManually()
        }
        .sheet(isPresented: $isShowingModelSelection) {
            EnhancementsModelSelectionSheet(
                options: viewModel.enhancementsProviderModels,
                isSelected: isSelectedOption,
                onSelect: selectOption,
                onCancel: {
                    isShowingModelSelection = false
                }
            )
        }
    }

    private var selection: EnhancementsAISelection {
        switch target {
        case .meeting:
            settings.enhancementsAISelection
        case .dictation:
            settings.enhancementsDictationAISelection
        }
    }

    private var selectionSummary: String {
        let providerName = settings.enhancementsProviderDisplayName(for: selection)
        let model = selection.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return "settings.enhancements.provider_models.summary.no_model".localized(with: providerName)
        }
        return "settings.enhancements.provider_models.summary".localized(with: providerName, model)
    }

    private func isSelectedOption(_ option: EnhancementsProviderModelOption) -> Bool {
        if let selectedRegistrationID = selection.registrationID,
           let optionRegistrationID = option.registrationID
        {
            return selectedRegistrationID == optionRegistrationID
                && selection.selectedModel == option.modelID
        }

        return selection.provider == option.provider && selection.selectedModel == option.modelID
    }

    private func selectOption(_ option: EnhancementsProviderModelOption) {
        if let registrationID = option.registrationID {
            settings.updateEnhancementsSelection(
                registrationID: registrationID,
                model: option.modelID,
                for: target.mode
            )
        } else {
            settings.updateEnhancementsSelection(
                provider: option.provider,
                model: option.modelID,
                for: target.mode
            )
        }
        isShowingModelSelection = false
    }
}
