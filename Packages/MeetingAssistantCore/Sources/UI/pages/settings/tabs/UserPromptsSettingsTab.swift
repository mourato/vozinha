import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct UserPromptsSettingsTab: View {
    @StateObject private var viewModel: DictationPromptSettingsViewModel

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: DictationPromptSettingsViewModel(settings: settings))
    }

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.dictation.user_prompts.title".localized,
                description: "settings.dictation.user_prompts.description".localized
            )

            DSGroup("settings.dictation.user_prompts.title".localized, icon: "sparkles") {
                VStack(alignment: .leading, spacing: AppDesignSystem.Layout.cardPadding) {
                    HStack {
                        Text("settings.post_processing.choose_active".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            viewModel.editingPrompt = nil
                            viewModel.showPromptEditor = true
                        } label: {
                            Label(
                                "settings.post_processing.new_prompt".localized,
                                systemImage: "plus"
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    VStack(spacing: 8) {
                        noPostProcessingRow()
                        ForEach(viewModel.availablePrompts) { prompt in
                            promptRow(prompt: prompt)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: viewModel.editingPrompt,
                onSave: viewModel.handleSavePrompt,
                onCancel: { viewModel.showPromptEditor = false }
            )
        }
        .alert("settings.post_processing.delete_confirm_title".localized, isPresented: $viewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                viewModel.executeDelete()
            }
        } message: {
            if let prompt = viewModel.promptToDelete {
                Text("settings.post_processing.delete_confirm_message".localized(with: prompt.title))
            }
        }
    }

    // MARK: - Prompts

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isSelected = viewModel.effectiveSelectedPromptId == prompt.id

        return PromptSelectionRow(
            iconSystemName: prompt.icon,
            title: prompt.title,
            description: prompt.description,
            isSelected: isSelected,
            onSelect: {
                viewModel.selectPrompt(prompt.id, forceSelect: true)
            },
            onDoubleClick: {
                openPromptEditor(for: prompt)
            },
            menuAccessibilityLabel: "transcription.ai_actions".localized
        ) {
            promptMenuContent(prompt: prompt, isSelected: isSelected)
        }
    }

    @ViewBuilder
    private func promptMenuContent(prompt: PostProcessingPrompt, isSelected: Bool) -> some View {
        Button {
            viewModel.selectPrompt(prompt.id, forceSelect: true)
        } label: {
            Label("settings.post_processing.select".localized, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
        }

        Divider()

        Button {
            openPromptEditor(for: prompt)
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            viewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.confirmDeletePrompt(prompt)
        } label: {
            Label("settings.post_processing.delete".localized, systemImage: "trash")
        }
    }

    private func noPostProcessingRow() -> some View {
        let isSelected = viewModel.effectiveSelectedPromptId == AppSettingsStore.noPostProcessingPromptId

        return PromptSelectionRow(
            iconSystemName: "nosign",
            title: "recording_indicator.prompt.none".localized,
            description: "recording_indicator.prompt.none_desc".localized,
            isSelected: isSelected,
            onSelect: {
                viewModel.selectPrompt(AppSettingsStore.noPostProcessingPromptId, forceSelect: true)
            },
            showMenu: false,
            preserveMenuSpacing: true,
            menuAccessibilityLabel: "transcription.ai_actions".localized
        ) {
            EmptyView()
        }
    }

    private func openPromptEditor(for prompt: PostProcessingPrompt) {
        viewModel.editingPrompt = prompt
        viewModel.showPromptEditor = true
    }
}

#Preview {
    UserPromptsSettingsTab()
}
