import AppKit
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Meeting Settings Tab

/// Tab for meeting-specific settings like app monitoring and automation.
public struct MeetingSettingsTab: View {
    private enum CapabilityLayout {
        static let disabledOpacity = 0.58
    }

    @Binding private var navigationState: MeetingSettingsNavigationState
    @StateObject var meetingViewModel: MeetingSettingsViewModel
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var serviceViewModel: ServiceSettingsViewModel
    @StateObject private var aiSettingsViewModel: AISettingsViewModel
    @StateObject private var monitoredAppsViewModel: InstalledAppsSelectionViewModel
    @StateObject var webTargetsViewModel: WebMeetingTargetsViewModel
    private let settings: AppSettingsStore
    @State private var showSummaryTemplateEditor = false
    @State private var showMonitoredAppSearchSheet = false
    @State var selectedWebTargetID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<MeetingSettingsNavigationState> = .constant(MeetingSettingsNavigationState()),
    ) {
        _navigationState = navigationState
        _meetingViewModel = StateObject(wrappedValue: MeetingSettingsViewModel(settings: settings))
        _serviceViewModel = StateObject(wrappedValue: ServiceSettingsViewModel(settings: settings))
        _aiSettingsViewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
        _monitoredAppsViewModel = StateObject(
            wrappedValue: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: AppSettingsStore.defaultMonitoredMeetingBundleIdentifiers,
                hasConfigured: { settings.hasConfiguredMonitoredMeetingApps },
                loadBundleIdentifiers: { settings.monitoredMeetingBundleIdentifiers },
                saveBundleIdentifiers: { settings.monitoredMeetingBundleIdentifiers = $0 },
            ),
        )
        _webTargetsViewModel = StateObject(wrappedValue: WebMeetingTargetsViewModel(settings: settings))
        self.settings = settings
    }

    public var body: some View {
        Group {
            switch navigationState.currentRoute {
            case .root:
                mainPage
            case .monitoringTargets:
                monitoringTargetsPage
            case .meetingPrompts:
                meetingPromptsPage
            case .export:
                exportPage
            }
        }
        .sheet(isPresented: $meetingViewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: meetingViewModel.editingPrompt,
                onSave: meetingViewModel.handleSavePrompt,
                onCancel: { meetingViewModel.showPromptEditor = false },
            )
        }
        .sheet(isPresented: $showSummaryTemplateEditor) {
            SummaryTemplateEditorSheet(
                initialTemplate: meetingViewModel.settings.summaryTemplate,
                onSave: { updatedTemplate in
                    meetingViewModel.settings.summaryTemplate = updatedTemplate
                    showSummaryTemplateEditor = false
                },
                onCancel: { showSummaryTemplateEditor = false },
            )
        }
        .alert("settings.post_processing.delete_confirm_title".localized, isPresented: $meetingViewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                meetingViewModel.executeDelete()
            }
        } message: {
            if let prompt = meetingViewModel.promptToDelete {
                Text("settings.post_processing.delete_confirm_message".localized(with: prompt.title))
            }
        }
        .onDeleteCommand(perform: deleteSelectedWebTarget)
    }

    private func updateNavigationState(to route: MeetingSettingsNavigationRoute) {
        let previousRoute = navigationState.currentRoute
        guard previousRoute != route else { return }

        switch (previousRoute, route) {
        case (_, .root):
            navigationState.forwardRoute = previousRoute == .root ? nil : previousRoute
        case (.root, _):
            navigationState.forwardRoute = nil
        default:
            navigationState.forwardRoute = nil
        }

        navigationState.currentRoute = route
    }

    private var mainPage: some View {
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 4) {
                SettingsFormSectionHeader(title: "settings.section.meetings".localized, icon: "person.2.fill")
                Text("settings.meetings.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } content: {
            ShortcutSettingsSection(
                groupTitle: "settings.shortcuts.meeting".localized,
                descriptionText: "settings.shortcuts.meeting_desc".localized,
                settingsContent: {
                    VStack(alignment: .leading, spacing: 12) {
                        if let healthPresentation = shortcutsViewModel.shortcutCaptureHealthPresentation {
                            ShortcutCaptureHealthStatusView(presentation: healthPresentation) {
                                shortcutsViewModel.openShortcutCaptureHealthAction()
                            }
                        }

                        DSModifierShortcutEditor(
                            shortcut: $shortcutsViewModel.meetingShortcutDefinition,
                            conflictMessage: shortcutsViewModel.meetingModifierConflictMessage,
                        )
                    }
                },
            )

            Section {
                Toggle("settings.general.auto_start".localized, isOn: $meetingViewModel.settings.autoStartRecording)
                    .toggleStyle(.switch)
                Picker(
                    "settings.general.auto_start_confirmation_delay".localized,
                    selection: $meetingViewModel.settings.automaticAutomaticMeetingRecordingConfirmationDelay,
                ) {
                    ForEach(AppSettingsStore.AutomaticMeetingRecordingConfirmationDelay.allCases, id: \.self) { delay in
                        Text(delay.localizedTitle).tag(delay)
                    }
                }
                .pickerStyle(.menu)
                SettingsListDrillDownButtonRow(
                    title: "settings.meetings.monitoring_access.button".localized,
                    subtitle: "settings.meetings.monitoring_access.desc".localized,
                    accessibilityHint: "settings.meetings.monitoring_access.accessibility_hint".localized,
                ) { updateNavigationState(to: .monitoringTargets) }
                Toggle("settings.general.merge_audio".localized, isOn: $meetingViewModel.settings.shouldMergeAudioFiles)
                    .toggleStyle(.switch)
                SettingsListDrillDownButtonRow(
                    title: "settings.meetings.export".localized,
                    subtitle: "settings.meetings.export_drilldown_desc".localized,
                    accessibilityHint: "settings.meetings.export_drilldown_accessibility_hint".localized,
                ) { updateNavigationState(to: .export) }
            } header: {
                SettingsFormSectionHeader(title: "settings.meetings.workflow".localized, icon: "bolt.fill")
            }

            ServiceMeetingTranscriptionSection(viewModel: serviceViewModel)
            meetingIntelligenceSection

            Section {
                SpeakerIdentificationSettingsSection(settings: meetingViewModel.settings)
            } header: {
                SettingsFormSectionHeader(title: "settings.meetings.speaker_identification".localized, icon: "person.wave.2.fill")
            }

            Section {
                Picker(
                    "settings.meetings.notes_typography.font_family".localized,
                    selection: $meetingViewModel.settings.meetingNotesFontFamilyKey,
                ) {
                    Text("settings.meetings.notes_typography.font_system".localized)
                        .tag(MeetingNotesTypographyDefaults.systemFontFamilyKey)
                    ForEach(availableMeetingNotesFontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                .pickerStyle(.menu)
                Picker(
                    "settings.meetings.notes_typography.font_size".localized,
                    selection: $meetingViewModel.settings.meetingNotesFontSize,
                ) {
                    ForEach(MeetingNotesTypographyDefaults.supportedFontSizes, id: \.self) { size in
                        Text("\(Int(size))").tag(size)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                SettingsFormSectionHeader(title: "settings.meetings.notes_typography.title".localized, icon: "textformat.size")
            }
        }
        .disabled(!meetingViewModel.settings.isMeetingTranscriptionEnabled)
        .opacity(meetingViewModel.settings.isMeetingTranscriptionEnabled ? 1 : CapabilityLayout.disabledOpacity)
        .animation(
            SettingsMotion.sectionAnimation(reduceMotion: reduceMotion),
            value: meetingViewModel.settings.isMeetingTranscriptionEnabled,
        )
    }

    private var meetingIntelligenceSection: some View {
        Section {
            Toggle("settings.meetings.post_processing_enabled".localized, isOn: meetingPostProcessingBinding)
                .toggleStyle(.switch)

            EnhancementsModelSelectionControl(
                target: .meeting,
                viewModel: aiSettingsViewModel,
                settings: settings,
            )

            Toggle("transcription.qa.title".localized, isOn: $meetingViewModel.settings.meetingQnAEnabled)
                .toggleStyle(.switch)

            SettingsListDrillDownButtonRow(
                title: "settings.meetings.prompts".localized,
                subtitle: "settings.meetings.prompts_drilldown_desc".localized,
                accessibilityHint: "settings.meetings.prompts_drilldown_accessibility_hint".localized,
            ) {
                updateNavigationState(to: .meetingPrompts)
            }
            .disabled(!meetingViewModel.isMeetingPostProcessingEnabled)
            .opacity(meetingViewModel.isMeetingPostProcessingEnabled ? 1 : CapabilityLayout.disabledOpacity)
        } header: {
            SettingsFormSectionHeader(title: "settings.enhancements.meeting_intelligence_model".localized, icon: "bubble.left.and.bubble.right.fill")
        }
    }

    private var meetingPostProcessingBinding: Binding<Bool> {
        Binding(
            get: { meetingViewModel.isMeetingPostProcessingEnabled },
            set: { meetingViewModel.setMeetingPostProcessingEnabled($0) },
        )
    }

    private var monitoringTargetsPage: some View {
        SettingsScrollableContent {
            DSCallout(
                kind: .info,
                title: "settings.meetings.monitoring_access.context_title".localized,
                message: "settings.meetings.monitoring_access.context_desc".localized,
            )

            InstalledAppsSelectionSection(
                titleKey: "settings.general.monitored_apps",
                descriptionKey: "settings.general.monitored_apps_desc",
                emptyKey: "settings.general.monitored_apps_empty",
                addButtonKey: "settings.general.monitored_apps_add",
                icon: "app.badge",
                onAddApp: { showMonitoredAppSearchSheet = true },
                viewModel: monitoredAppsViewModel,
            )

            webTargetsSection
        }
        .disabled(!meetingViewModel.settings.isMeetingTranscriptionEnabled)
        .opacity(meetingViewModel.settings.isMeetingTranscriptionEnabled ? 1 : CapabilityLayout.disabledOpacity)
        .animation(
            SettingsMotion.sectionAnimation(reduceMotion: reduceMotion),
            value: meetingViewModel.settings.isMeetingTranscriptionEnabled,
        )
        .sheet(isPresented: $webTargetsViewModel.showEditor) {
            WebMeetingTargetEditorSheet(
                target: webTargetsViewModel.editingTarget,
                onSave: webTargetsViewModel.handleSave,
                onCancel: { webTargetsViewModel.showEditor = false },
            )
        }
        .sheet(isPresented: $showMonitoredAppSearchSheet) {
            AppSearchSheet(
                viewModel: monitoredAppsViewModel,
                isPresented: $showMonitoredAppSearchSheet,
                titleKey: "settings.general.monitored_apps",
                descriptionKey: "settings.general.monitored_apps_desc",
                addButtonKey: "settings.general.monitored_apps_add",
            )
        }
        .alert("settings.meetings.web_targets.delete_confirm_title".localized, isPresented: $webTargetsViewModel.showDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.delete".localized, role: .destructive) {
                webTargetsViewModel.executeDelete()
            }
        } message: {
            if let target = webTargetsViewModel.targetToDelete {
                Text("settings.meetings.web_targets.delete_confirm_message".localized(with: target.displayName))
            }
        }
    }

    private var exportPage: some View {
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 4) {
                SettingsFormSectionHeader(title: "settings.meetings.export".localized, icon: "folder.fill")
                Text("settings.meetings.export_drilldown_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } content: {
            Section {
                Toggle(isOn: $meetingViewModel.settings.autoExportSummaries) {
                    VStack(alignment: .leading) {
                        Text("settings.meetings.auto_export".localized)
                        Text("settings.meetings.auto_export_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if meetingViewModel.settings.autoExportSummaries {
                    Divider()

                    HStack {
                        SettingsTitleWithPopover(
                            title: "settings.meetings.export_location".localized,
                            helperMessage: "settings.meetings.export_location_desc".localized,
                        )
                        Spacer()
                        if let url = meetingViewModel.settings.summaryExportFolder {
                            Text(url.lastPathComponent)
                                .foregroundStyle(.secondary)
                                .truncationMode(.middle)
                        } else {
                            Text("settings.meetings.no_folder_selected".localized)
                                .foregroundStyle(.secondary)
                        }
                        Button("common.select".localized) {
                            meetingViewModel.selectExportFolder()
                        }
                    }

                    Divider()

                    Toggle(isOn: $meetingViewModel.settings.summaryTemplateEnabled) {
                        VStack(alignment: .leading) {
                            Text("settings.meetings.template_enabled".localized)
                            Text("settings.meetings.template_enabled_desc".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    Picker(
                        "settings.meetings.export_safety_policy".localized,
                        selection: $meetingViewModel.settings.summaryExportSafetyPolicyLevel,
                    ) {
                        ForEach(SummaryExportSafetyPolicyLevel.allCases, id: \.self) { level in
                            Text(exportSafetyPolicyLabel(level)).tag(level)
                        }
                    }
                    .pickerStyle(.menu)

                    if meetingViewModel.settings.summaryExportFolder == nil {
                        Text("settings.meetings.export_location_required".localized)
                            .font(.caption)
                            .foregroundStyle(AppDesignSystem.Colors.error)
                    }

                    if meetingViewModel.settings.summaryTemplateEnabled {
                        Divider()

                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                                SettingsTitleWithPopover(
                                    title: "settings.meetings.template".localized,
                                    helperMessage: "settings.meetings.template_desc".localized,
                                    font: .subheadline,
                                    fontWeight: .semibold,
                                )
                            }

                            Spacer()

                            Button {
                                showSummaryTemplateEditor = true
                            } label: {
                                Label("settings.meetings.template.edit".localized, systemImage: "pencil")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                }
            } header: {
                Text("settings.meetings.export".localized)
            }
        }
        .disabled(!meetingViewModel.settings.isMeetingTranscriptionEnabled)
        .opacity(meetingViewModel.settings.isMeetingTranscriptionEnabled ? 1 : CapabilityLayout.disabledOpacity)
        .animation(
            SettingsMotion.sectionAnimation(reduceMotion: reduceMotion),
            value: meetingViewModel.settings.isMeetingTranscriptionEnabled,
        )
    }

    private var meetingPromptsPage: some View {
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 4) {
                SettingsFormSectionHeader(title: "settings.meetings.prompts".localized, icon: "sparkles")
                Text("settings.meetings.prompts_drilldown_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } content: {
            Section {
                Picker(
                    "settings.meetings.summary_output_language".localized,
                    selection: $meetingViewModel.settings.meetingSummaryOutputLanguage,
                ) {
                    ForEach(DictationOutputLanguage.allCases, id: \.self) { language in
                        Text(meetingSummaryOutputLanguageLabel(language)).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                Toggle(isOn: $meetingViewModel.settings.meetingTypeAutoDetectEnabled) {
                    VStack(alignment: .leading) {
                        Text("settings.meetings.autodetect_type".localized)
                        Text("settings.meetings.autodetect_type_desc".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                HStack {
                    Text("settings.post_processing.choose_active".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        meetingViewModel.editingPrompt = nil
                        meetingViewModel.showPromptEditor = true
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
                    ForEach(meetingViewModel.availablePrompts) { prompt in
                        promptRow(prompt: prompt)
                    }
                }
            } header: {
                Text("settings.meetings.prompts".localized)
            }
        }
        .disabled(!meetingViewModel.settings.isMeetingTranscriptionEnabled || !meetingViewModel.isMeetingPostProcessingEnabled)
        .opacity(
            meetingViewModel.settings.isMeetingTranscriptionEnabled && meetingViewModel.isMeetingPostProcessingEnabled
                ? 1
                : CapabilityLayout.disabledOpacity,
        )
        .animation(
            SettingsMotion.sectionAnimation(reduceMotion: reduceMotion),
            value: meetingViewModel.settings.isMeetingTranscriptionEnabled,
        )
        .animation(
            SettingsMotion.sectionAnimation(reduceMotion: reduceMotion),
            value: meetingViewModel.isMeetingPostProcessingEnabled,
        )
    }

    private func exportSafetyPolicyLabel(_ level: SummaryExportSafetyPolicyLevel) -> String {
        switch level {
        case .permissive:
            "settings.meetings.export_safety_policy.permissive".localized
        case .standard:
            "settings.meetings.export_safety_policy.standard".localized
        case .strict:
            "settings.meetings.export_safety_policy.strict".localized
        }
    }

    private var availableMeetingNotesFontFamilies: [String] {
        NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func meetingSummaryOutputLanguageLabel(_ language: DictationOutputLanguage) -> String {
        if language == .original {
            return "\(language.flagEmoji) \("settings.meetings.summary_output_language.option.meeting_spoken".localized)"
        }
        return language.displayName
    }

    // MARK: - Prompt Row

    private func promptRow(prompt: PostProcessingPrompt) -> some View {
        let isAutoDetectEnabled = meetingViewModel.settings.meetingTypeAutoDetectEnabled
        let isSelected = !isAutoDetectEnabled && meetingViewModel.selectedPromptId == prompt.id

        return PromptSelectionRow(
            iconSystemName: prompt.icon,
            title: prompt.title,
            description: prompt.description,
            isSelected: isSelected,
            onSelect: isAutoDetectEnabled ? nil : {
                meetingViewModel.selectPrompt(prompt.id)
            },
            onDoubleClick: {
                openPromptEditor(for: prompt)
            },
            unselectedStrokeColor: AppDesignSystem.Colors.separator.opacity(0.4),
            menuAccessibilityLabel: "transcription.ai_actions".localized,
            menuContent: {
                promptMenuContent(prompt: prompt, isSelected: isSelected, isAutoDetectEnabled: isAutoDetectEnabled)
            },
        )
    }

    @ViewBuilder
    private func promptMenuContent(prompt: PostProcessingPrompt, isSelected: Bool, isAutoDetectEnabled: Bool) -> some View {
        if !isAutoDetectEnabled {
            Button {
                meetingViewModel.selectPrompt(prompt.id, forceSelect: true)
            } label: {
                Label("settings.post_processing.select".localized, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
            }

            Divider()
        }

        Button {
            openPromptEditor(for: prompt)
        } label: {
            Label("settings.post_processing.edit".localized, systemImage: "pencil")
        }

        Button {
            meetingViewModel.prepareCopy(of: prompt, asDuplicate: true)
        } label: {
            Label("settings.post_processing.duplicate".localized, systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            meetingViewModel.confirmDeletePrompt(prompt)
        } label: {
            Label("settings.post_processing.delete".localized, systemImage: "trash")
        }
    }

    private func openPromptEditor(for prompt: PostProcessingPrompt) {
        meetingViewModel.editingPrompt = prompt
        meetingViewModel.showPromptEditor = true
    }
}

#Preview {
    MeetingSettingsTab()
}
