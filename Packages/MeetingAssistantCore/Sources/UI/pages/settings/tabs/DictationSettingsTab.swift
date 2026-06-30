import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public enum DictationSettingsRoute: Hashable {
    case modes
    case userPrompts
}

// MARK: - Dictation Settings Tab

/// Tab for dictation-specific settings like auto-copy/paste and shortcuts.
public struct DictationSettingsTab: View {
    @Binding private var navigationState: SettingsSubpageNavigationState<DictationSettingsRoute>
    @StateObject private var viewModel: GeneralSettingsViewModel
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var serviceViewModel: ServiceSettingsViewModel
    @StateObject private var aiSettingsViewModel: AISettingsViewModel
    private let settings: AppSettingsStore

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<SettingsSubpageNavigationState<DictationSettingsRoute>> = .constant(SettingsSubpageNavigationState())
    ) {
        _navigationState = navigationState
        _viewModel = StateObject(wrappedValue: GeneralSettingsViewModel(settingsStore: settings))
        _serviceViewModel = StateObject(wrappedValue: ServiceSettingsViewModel(settings: settings))
        _aiSettingsViewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
        self.settings = settings
    }

    public var body: some View {
        Group {
            switch navigationState.currentRoute {
            case nil:
                rootPage
            case .some(.modes):
                StylesSettingsTab()
            case .some(.userPrompts):
                UserPromptsSettingsTab()
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

            DSGroup("settings.dictation.modes_and_prompts.title".localized, icon: "paintpalette") {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsDrillDownButtonRow(
                        title: "settings.dictation.modes.title".localized,
                        subtitle: "settings.dictation.modes.description".localized,
                        accessibilityHint: "settings.dictation.modes.accessibility_hint".localized
                    ) {
                        navigationState.open(.modes)
                    }

                    Divider()
                        .padding(.leading, 0)

                    SettingsDrillDownButtonRow(
                        title: "settings.dictation.user_prompts.title".localized,
                        subtitle: "settings.dictation.user_prompts.description".localized,
                        accessibilityHint: "settings.dictation.user_prompts.accessibility_hint".localized
                    ) {
                        navigationState.open(.userPrompts)
                    }
                }
            }

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
                }
            }

            ServiceTranscriptionProviderSection(viewModel: serviceViewModel)

            DSGroup("settings.dictation.post_processing_model".localized, icon: "sparkles") {
                EnhancementsModelSelectionControl(
                    target: .dictation,
                    viewModel: aiSettingsViewModel,
                    settings: settings
                )
            }
        }
    }
}

#Preview {
    DictationSettingsTab()
}
