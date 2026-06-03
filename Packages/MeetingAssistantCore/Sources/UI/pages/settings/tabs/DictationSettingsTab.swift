import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public enum DictationSettingsRoute: Hashable {
    case styles
}

// MARK: - Dictation Settings Tab

/// Tab for dictation-specific settings like auto-copy/paste and shortcuts.
public struct DictationSettingsTab: View {
    @Binding private var navigationState: SettingsSubpageNavigationState<DictationSettingsRoute>
    @StateObject private var viewModel: GeneralSettingsViewModel
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var promptViewModel: DictationPromptSettingsViewModel
    @StateObject private var serviceViewModel: ServiceSettingsViewModel

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<SettingsSubpageNavigationState<DictationSettingsRoute>> = .constant(SettingsSubpageNavigationState())
    ) {
        _navigationState = navigationState
        _viewModel = StateObject(wrappedValue: GeneralSettingsViewModel(settingsStore: settings))
        _promptViewModel = StateObject(wrappedValue: DictationPromptSettingsViewModel(settings: settings))
        _serviceViewModel = StateObject(wrappedValue: ServiceSettingsViewModel(settings: settings))
    }

    public var body: some View {
        Group {
            switch navigationState.currentRoute {
            case nil:
                rootPage
            case .some(.styles):
                StylesSettingsTab()
            }
        }
        .sheet(isPresented: $promptViewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: promptViewModel.editingPrompt,
                onSave: promptViewModel.handleSavePrompt,
                onCancel: { promptViewModel.showPromptEditor = false }
            )
        }
        .alert("settings.post_processing.delete_confirm_title".localized, isPresented: $promptViewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                promptViewModel.executeDelete()
            }
        } message: {
            if let prompt = promptViewModel.promptToDelete {
                Text("settings.post_processing.delete_confirm_message".localized(with: prompt.title))
            }
        }
    }

    private var rootPage: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.dictation".localized,
                description: "settings.shortcuts.header_desc".localized
            )

            ShortcutSettingsSection(
                groupTitle: "settings.shortcuts.dictation".localized,
                descriptionText: "settings.shortcuts.dictation_desc".localized,
                settingsContent: {
                    VStack(alignment: .leading, spacing: 12) {
                        if let healthPresentation = shortcutsViewModel.shortcutCaptureHealthPresentation {
                            ShortcutCaptureHealthStatusView(presentation: healthPresentation) {
                                shortcutsViewModel.openShortcutCaptureHealthAction()
                            }
                        }

                        DSModifierShortcutEditor(
                            shortcut: $shortcutsViewModel.dictationShortcutDefinition,
                            conflictMessage: shortcutsViewModel.dictationModifierConflictMessage
                        )
                    }
                }
            )

            ServiceTranscriptionProviderSection(viewModel: serviceViewModel)

            DSGroup("settings.dictation.text_handling".localized, icon: "cpu") {
                VStack(alignment: .leading, spacing: 16) {
                    DSToggleRow(
                        "settings.general.auto_copy_transcription".localized,
                        description: "settings.general.auto_copy_transcription_desc".localized,
                        isOn: $viewModel.autoCopyTranscriptionToClipboard
                    )

                    Divider()

                    DSToggleRow(
                        "settings.general.auto_paste_transcription".localized,
                        isOn: $viewModel.autoPasteTranscriptionToActiveApp
                    )

                    Divider()

                    DSToggleRow(
                        "settings.dictation.smart_spacing".localized,
                        description: "settings.dictation.smart_spacing_desc".localized,
                        isOn: $viewModel.smartSpacingAndCapitalizationEnabled
                    )

                    Divider()

                    DSToggleRow(
                        "settings.dictation.smart_paragraphs".localized,
                        description: "settings.dictation.smart_paragraphs_desc".localized,
                        isOn: $viewModel.smartParagraphsEnabled
                    )

                    Divider()

                    SettingsDrillDownButtonRow(
                        title: "settings.styles.title".localized,
                        subtitle: "settings.styles.description".localized,
                        accessibilityHint: "settings.dictation.styles.accessibility_hint".localized
                    ) {
                        navigationState.open(.styles)
                    }
                }
            }

            DSGroup("settings.dictation.prompts".localized, icon: "sparkles") {
                VStack(alignment: .leading, spacing: AppDesignSystem.Layout.cardPadding) {
                    HStack {
                        Text("settings.post_processing.choose_active".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            promptViewModel.editingPrompt = nil
                            promptViewModel.showPromptEditor = true
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
                        ForEach(promptViewModel.availablePrompts) { prompt in
                            promptRow(prompt: prompt)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Prompts

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isSelected = promptViewModel.effectiveSelectedPromptId == prompt.id

        return PromptSelectionRow(
            iconSystemName: prompt.icon,
            title: prompt.title,
            description: prompt.description,
            isSelected: isSelected,
            onSelect: {
                promptViewModel.selectPrompt(prompt.id, forceSelect: true)
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
            promptViewModel.selectPrompt(prompt.id, forceSelect: true)
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
            promptViewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            promptViewModel.confirmDeletePrompt(prompt)
        } label: {
            Label("settings.post_processing.delete".localized, systemImage: "trash")
        }
    }

    private func noPostProcessingRow() -> some View {
        let isSelected = promptViewModel.effectiveSelectedPromptId == AppSettingsStore.noPostProcessingPromptId

        return PromptSelectionRow(
            iconSystemName: "nosign",
            title: "recording_indicator.prompt.none".localized,
            description: "recording_indicator.prompt.none_desc".localized,
            isSelected: isSelected,
            onSelect: {
                promptViewModel.selectPrompt(AppSettingsStore.noPostProcessingPromptId, forceSelect: true)
            },
            showMenu: false,
            preserveMenuSpacing: true,
            menuAccessibilityLabel: "transcription.ai_actions".localized
        ) {
            EmptyView()
        }
    }

    private func openPromptEditor(for prompt: PostProcessingPrompt) {
        promptViewModel.editingPrompt = prompt
        promptViewModel.showPromptEditor = true
    }
}

#Preview {
    DictationSettingsTab()
}
