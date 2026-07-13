import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Post-Processing Settings Tab

/// Settings tab for configuring AI post-processing prompts.
public struct PostProcessingSettingsTab: View {
    @StateObject private var viewModel = PostProcessingSettingsViewModel()

    public init() {}

    public var body: some View {
        SettingsScrollableContent {
            enableToggleSection

            if viewModel.settings.postProcessingEnabled {
                Group {
                    if viewModel.settings.resolvedEnhancementsAIConfiguration.isValid {
                        systemPromptSection
                        userPromptsSection
                    } else {
                        connectionWarningSection
                    }
                }
                .transition(SettingsMotion.sectionTransition())
            }
        }
        .sheet(isPresented: $viewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: viewModel.editingPrompt,
                onSave: viewModel.handleSavePrompt,
                onCancel: { viewModel.showPromptEditor = false },
            )
        }
        .sheet(isPresented: $viewModel.showSystemPromptEditor) {
            SystemPromptEditorSheet(
                initialPrompt: viewModel.settings.systemPrompt,
                onSave: viewModel.handleSaveSystemPrompt,
                onCancel: { viewModel.showSystemPromptEditor = false },
                onRestoreDefault: { viewModel.resetSystemPrompt() },
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

    // MARK: - Sections

    private var enableToggleSection: some View {
        DSCard {
            DSToggleRow(
                "settings.post_processing.enabled".localized,
                description: "settings.post_processing.description".localized,
                isOn: $viewModel.settings.postProcessingEnabled.animated(),
            )
        }
    }

    private var connectionWarningSection: some View {
        DSCallout(
            kind: .warning,
            title: "settings.post_processing.warning_title".localized,
            message: "settings.post_processing.warning_desc".localized,
        )
    }

    private var systemPromptSection: some View {
        DSGroup("settings.post_processing.system_prompt".localized, icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.post_processing.base_instructions".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(viewModel.settings.systemPrompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        viewModel.showSystemPromptEditor = true
                    } label: {
                        Label(
                            "settings.post_processing.edit_system_guidelines".localized,
                            systemImage: "pencil",
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private var userPromptsSection: some View {
        DSGroup("settings.post_processing.prompts".localized, icon: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
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
                            systemImage: "plus",
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                VStack(spacing: 8) {
                    ForEach(viewModel.settings.allPrompts) { prompt in
                        promptRow(prompt: prompt)
                    }
                }
            }
        }
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isSelected = viewModel.settings.selectedPromptId == prompt.id

        return PromptSelectionRow(
            iconSystemName: prompt.icon,
            title: prompt.title,
            description: prompt.description,
            isSelected: isSelected,
            onSelect: {
                viewModel.selectPrompt(prompt.id)
            },
            onDoubleClick: {
                openPromptEditor(for: prompt)
            },
            menuAccessibilityLabel: "transcription.ai_actions".localized,
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

    private func openPromptEditor(for prompt: PostProcessingPrompt) {
        if prompt.isPredefined {
            viewModel.prepareCopy(of: prompt, asDuplicate: false)
        } else {
            viewModel.editingPrompt = prompt
            viewModel.showPromptEditor = true
        }
    }
}

#Preview {
    PostProcessingSettingsTab()
}
