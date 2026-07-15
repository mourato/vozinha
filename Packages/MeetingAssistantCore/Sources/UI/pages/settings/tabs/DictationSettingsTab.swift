import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Dictation Settings Tab

/// Tab for dictation-specific settings like auto-copy/paste and shortcuts.
public struct DictationSettingsTab: View {
    @State private var viewModel: GeneralSettingsViewModel
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var serviceViewModel: ServiceSettingsViewModel

    public init(
        settings: AppSettingsStore = .shared,
    ) {
        _viewModel = State(wrappedValue: GeneralSettingsViewModel(settingsStore: settings))
        _serviceViewModel = StateObject(wrappedValue: ServiceSettingsViewModel(settings: settings))
    }

    public var body: some View {
        rootPage
    }

    private var rootPage: some View {
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 4) {
                SettingsFormSectionHeader(title: "settings.section.dictation".localized, icon: "mic.fill")
                Text("settings.dictation.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } content: {
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
                            conflictMessage: shortcutsViewModel.dictationModifierConflictMessage,
                        )
                    }
                },
            )

            Section {
                Toggle(isOn: $viewModel.autoCopyTranscriptionToClipboard) {
                    VStack(alignment: .leading) {
                        Text("settings.general.auto_copy_transcription".localized)
                        Text("settings.general.auto_copy_transcription_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle("settings.general.auto_paste_transcription".localized, isOn: $viewModel.autoPasteTranscriptionToActiveApp)
                    .toggleStyle(.checkbox)

                Toggle(isOn: $viewModel.smartSpacingAndCapitalizationEnabled) {
                    VStack(alignment: .leading) {
                        Text("settings.dictation.smart_spacing".localized)
                        Text("settings.dictation.smart_spacing_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $viewModel.smartParagraphsEnabled) {
                    VStack(alignment: .leading) {
                        Text("settings.dictation.smart_paragraphs".localized)
                        Text("settings.dictation.smart_paragraphs_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            } header: {
                SettingsFormSectionHeader(title: "settings.dictation.text_handling".localized, icon: "cpu")
            }

            ServiceTranscriptionProviderSection(viewModel: serviceViewModel)
        }
    }
}

#Preview {
    DictationSettingsTab()
}
