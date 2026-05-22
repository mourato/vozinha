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
    @Binding private var navigationState: MeetingSettingsNavigationState
    @StateObject private var meetingViewModel: MeetingSettingsViewModel
    @StateObject private var shortcutsViewModel = ShortcutSettingsViewModel()
    @StateObject private var monitoredAppsViewModel: InstalledAppsSelectionViewModel
    @StateObject private var webTargetsViewModel: WebMeetingTargetsViewModel
    @State private var showSummaryTemplateEditor = false
    @State private var selectedWebTargetID: UUID?

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<MeetingSettingsNavigationState> = .constant(MeetingSettingsNavigationState())
    ) {
        _navigationState = navigationState
        _meetingViewModel = StateObject(wrappedValue: MeetingSettingsViewModel(settings: settings))
        _monitoredAppsViewModel = StateObject(
            wrappedValue: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: AppSettingsStore.defaultMonitoredMeetingBundleIdentifiers,
                hasConfigured: { settings.hasConfiguredMonitoredMeetingApps },
                loadBundleIdentifiers: { settings.monitoredMeetingBundleIdentifiers },
                saveBundleIdentifiers: { settings.monitoredMeetingBundleIdentifiers = $0 }
            )
        )
        _webTargetsViewModel = StateObject(wrappedValue: WebMeetingTargetsViewModel(settings: settings))
    }

    public var body: some View {
        Group {
            switch navigationState.currentRoute {
            case .root:
                mainPage
            case .monitoringTargets:
                monitoringTargetsPage
            }
        }
        .sheet(isPresented: $meetingViewModel.showPromptEditor) {
            PromptEditorSheet(
                prompt: meetingViewModel.editingPrompt,
                onSave: meetingViewModel.handleSavePrompt,
                onCancel: { meetingViewModel.showPromptEditor = false }
            )
        }
        .sheet(isPresented: $showSummaryTemplateEditor) {
            SummaryTemplateEditorSheet(
                initialTemplate: meetingViewModel.settings.summaryTemplate,
                onSave: { updatedTemplate in
                    meetingViewModel.settings.summaryTemplate = updatedTemplate
                    showSummaryTemplateEditor = false
                },
                onCancel: { showSummaryTemplateEditor = false }
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
        case (.monitoringTargets, .root):
            navigationState.forwardRoute = .monitoringTargets
        case (.root, .monitoringTargets):
            navigationState.forwardRoute = nil
        default:
            navigationState.forwardRoute = nil
        }

        navigationState.currentRoute = route
    }

    private var mainPage: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.meetings".localized,
                description: "settings.shortcuts.meeting_desc".localized
            )

            DSGroup("settings.capabilities.title".localized, icon: "switch.2") {
                DSToggleRow(
                    "settings.capabilities.meeting_transcription".localized,
                    description: "settings.capabilities.meeting_transcription_desc".localized,
                    isOn: $meetingViewModel.settings.isMeetingTranscriptionEnabled
                )
            }

            if meetingViewModel.settings.isMeetingTranscriptionEnabled {
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
                                conflictMessage: shortcutsViewModel.meetingModifierConflictMessage
                            )
                        }
                    }
                )

                DSGroup("settings.meetings.monitoring_access.title".localized, icon: "app.badge") {
                    SettingsDrillDownButtonRow(
                        title: "settings.meetings.monitoring_access.button".localized,
                        subtitle: "settings.meetings.monitoring_access.desc".localized,
                        accessibilityHint: "settings.meetings.monitoring_access.accessibility_hint".localized
                    ) {
                        updateNavigationState(to: .monitoringTargets)
                    }
                }

                DSGroup("settings.meetings.workflow".localized, icon: "bolt.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        DSToggleRow(
                            "settings.general.auto_start".localized,
                            isOn: $meetingViewModel.settings.autoStartRecording
                        )

                        Divider()

                        DSToggleRow(
                            "settings.general.merge_audio".localized,
                            isOn: $meetingViewModel.settings.shouldMergeAudioFiles
                        )
                    }
                }

                meetingIntelligenceSection

                DSGroup("settings.meetings.speaker_identification".localized, icon: "person.wave.2.fill") {
                    SpeakerIdentificationSettingsSection(settings: meetingViewModel.settings)
                }

                DSGroup("settings.meetings.notes_typography.title".localized, icon: "textformat.size") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SettingsTitleWithPopover(
                                title: "settings.meetings.notes_typography.font_family".localized,
                                helperTitle: "settings.meetings.notes_typography.title".localized,
                                helperMessage: "settings.meetings.notes_typography.desc".localized
                            )
                            Spacer()
                            Picker("", selection: $meetingViewModel.settings.meetingNotesFontFamilyKey) {
                                Text("settings.meetings.notes_typography.font_system".localized)
                                    .tag(MeetingNotesTypographyDefaults.systemFontFamilyKey)
                                ForEach(availableMeetingNotesFontFamilies, id: \.self) { family in
                                    Text(family).tag(family)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        Divider()

                        HStack {
                            Text("settings.meetings.notes_typography.font_size".localized)
                            Spacer()
                            Picker("", selection: $meetingViewModel.settings.meetingNotesFontSize) {
                                ForEach(MeetingNotesTypographyDefaults.supportedFontSizes, id: \.self) { size in
                                    Text("\(Int(size))").tag(size)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                }

                DSGroup("settings.meetings.export".localized, icon: "folder.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        DSToggleRow(
                            "settings.meetings.auto_export".localized,
                            description: "settings.meetings.auto_export_desc".localized,
                            isOn: $meetingViewModel.settings.autoExportSummaries
                        )

                        if meetingViewModel.settings.autoExportSummaries {
                            Divider()

                            HStack {
                                SettingsTitleWithPopover(
                                    title: "settings.meetings.export_location".localized,
                                    helperMessage: "settings.meetings.export_location_desc".localized
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

                            DSToggleRow(
                                "settings.meetings.template_enabled".localized,
                                description: "settings.meetings.template_enabled_desc".localized,
                                isOn: $meetingViewModel.settings.summaryTemplateEnabled
                            )

                            Divider()

                            HStack {
                                SettingsTitleWithPopover(
                                    title: "settings.meetings.export_safety_policy".localized,
                                    helperMessage: "settings.meetings.export_safety_policy_desc".localized
                                )
                                Spacer()
                                Picker("", selection: $meetingViewModel.settings.summaryExportSafetyPolicyLevel) {
                                    ForEach(SummaryExportSafetyPolicyLevel.allCases, id: \.self) { level in
                                        Text(exportSafetyPolicyLabel(level)).tag(level)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            if meetingViewModel.settings.summaryExportFolder == nil {
                                Text("settings.meetings.export_location_required".localized)
                                    .font(.caption)
                                    .foregroundStyle(AppDesignSystem.Colors.error)
                            }

                            if meetingViewModel.settings.summaryTemplateEnabled {
                                Divider()

                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(AppDesignSystem.Colors.iconHighlight)
                                    SettingsTitleWithPopover(
                                        title: "settings.meetings.template".localized,
                                        helperMessage: "settings.meetings.template_desc".localized,
                                        font: .subheadline,
                                        fontWeight: .semibold
                                    )
                                }

                                HStack {
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
                    }
                }

                DSGroup("settings.meetings.prompts".localized, icon: "sparkles") {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Layout.cardPadding) {
                        HStack {
                            SettingsTitleWithPopover(
                                title: "settings.meetings.summary_output_language".localized,
                                helperMessage: "settings.meetings.summary_output_language_desc".localized
                            )
                            Spacer()
                            Picker("", selection: $meetingViewModel.settings.meetingSummaryOutputLanguage) {
                                ForEach(DictationOutputLanguage.allCases, id: \.self) { language in
                                    Text(meetingSummaryOutputLanguageLabel(language))
                                        .tag(language)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        Divider()

                        DSToggleRow(
                            "settings.meetings.autodetect_type".localized,
                            description: "settings.meetings.autodetect_type_desc".localized,
                            isOn: $meetingViewModel.settings.meetingTypeAutoDetectEnabled
                        )

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
                                    systemImage: "plus"
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }

                        VStack(spacing: 8) {
                            noPostProcessingRow()
                            ForEach(meetingViewModel.availablePrompts) { prompt in
                                promptRow(prompt: prompt)
                            }
                        }
                    }
                }
            }
        }
    }

    private var meetingIntelligenceSection: some View {
        DSGroup("settings.enhancements.meeting_intelligence_model".localized, icon: "bubble.left.and.bubble.right.fill") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
                DSToggleRow(
                    "transcription.qa.title".localized,
                    description: "settings.enhancements.qa_enabled_desc".localized,
                    isOn: $meetingViewModel.settings.meetingQnAEnabled
                )

                if !meetingViewModel.settings.isEnhancementsInferenceReady {
                    Divider()
                    DSCallout(
                        kind: .info,
                        title: "settings.enhancements.selector.moved_title".localized,
                        message: "settings.enhancements.selector.moved_message".localized
                    )
                }
            }
        }
    }

    private var monitoringTargetsPage: some View {
        SettingsScrollableContent {
            DSCallout(
                kind: .info,
                title: "settings.meetings.monitoring_access.context_title".localized,
                message: "settings.meetings.monitoring_access.context_desc".localized
            )

            InstalledAppsSelectionSection(
                titleKey: "settings.general.monitored_apps",
                descriptionKey: "settings.general.monitored_apps_desc",
                emptyKey: "settings.general.monitored_apps_empty",
                addButtonKey: "settings.general.monitored_apps_add",
                icon: "app.badge",
                viewModel: monitoredAppsViewModel
            )

            webTargetsSection
        }
        .sheet(isPresented: $webTargetsViewModel.showEditor) {
            WebMeetingTargetEditorSheet(
                target: webTargetsViewModel.editingTarget,
                onSave: webTargetsViewModel.handleSave,
                onCancel: { webTargetsViewModel.showEditor = false }
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

    private var webTargetsSection: some View {
        DSGroup("settings.meetings.web_targets.title".localized, icon: "globe", headerAccessory: {
            DSInfoPopoverButton(
                title: "settings.meetings.web_targets.title".localized,
                message: "settings.meetings.web_targets.desc".localized
            )
        }) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsInlineList(
                    items: webTargetsViewModel.targets,
                    emptyText: "settings.meetings.web_targets.empty".localized,
                    containerStyle: .plain
                ) { target in
                    webTargetRow(target)
                }

                HStack {
                    Spacer()
                    Button {
                        webTargetsViewModel.addTarget()
                    } label: {
                        Label("settings.meetings.web_targets.add".localized, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private func webTargetRow(_ target: WebMeetingTarget) -> some View {
        HStack(spacing: 12) {
            SettingsRowClickSurface(
                onSingleClick: {
                    selectedWebTargetID = target.id
                },
                onDoubleClick: {
                    selectedWebTargetID = target.id
                    webTargetsViewModel.editTarget(target)
                }
            ) {
                HStack(spacing: 12) {
                    Image(systemName: target.app.icon)
                        .font(.title3)
                        .foregroundStyle(target.app.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(target.urlPatterns.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(browserNames(from: target.browserBundleIdentifiers))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            SettingsContextMenuButton(accessibilityLabel: "settings.rules_per_app.actions".localized) {
                Button {
                    selectedWebTargetID = target.id
                    webTargetsViewModel.editTarget(target)
                } label: {
                    Label("settings.meetings.web_targets.edit".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    selectedWebTargetID = target.id
                    webTargetsViewModel.confirmDelete(target)
                } label: {
                    Label("settings.meetings.web_targets.delete".localized, systemImage: "trash")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectionBackground(isSelected: selectedWebTargetID == target.id))
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
        .contextMenu {
            Button {
                selectedWebTargetID = target.id
                webTargetsViewModel.editTarget(target)
            } label: {
                Label("settings.meetings.web_targets.edit".localized, systemImage: "pencil")
            }

            Button(role: .destructive) {
                selectedWebTargetID = target.id
                webTargetsViewModel.confirmDelete(target)
            } label: {
                Label("settings.meetings.web_targets.delete".localized, systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(webTargetAccessibilityLabel(for: target))
        .accessibilityHint("settings.rules_per_app.actions".localized)
    }

    private func browserNames(from bundleIdentifiers: [String]) -> String {
        WebTargetBrowserNamesFormatter.formattedNames(
            bundleIdentifiers: bundleIdentifiers,
            fallbackBundleIdentifiers: meetingViewModel.settings.effectiveWebTargetBrowserBundleIdentifiers,
            localizedListKey: "settings.meetings.web_targets.browsers"
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

    @ViewBuilder
    private func selectionBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                .fill(AppDesignSystem.Colors.selectionFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius)
                        .stroke(AppDesignSystem.Colors.selectionStroke, lineWidth: 1)
                )
        } else {
            Color.clear
        }
    }

    private func deleteSelectedWebTarget() {
        guard let selectedWebTargetID,
              let target = webTargetsViewModel.targets.first(where: { $0.id == selectedWebTargetID })
        else {
            return
        }
        webTargetsViewModel.confirmDelete(target)
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
            menuAccessibilityLabel: "transcription.ai_actions".localized
        ) {
            promptMenuContent(prompt: prompt, isSelected: isSelected, isAutoDetectEnabled: isAutoDetectEnabled)
        }
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

    private func noPostProcessingRow() -> some View {
        let isAutoDetectEnabled = meetingViewModel.settings.meetingTypeAutoDetectEnabled
        let isSelected = !isAutoDetectEnabled && meetingViewModel.selectedPromptId == AppSettingsStore.noPostProcessingPromptId

        return PromptSelectionRow(
            iconSystemName: "nosign",
            title: "recording_indicator.prompt.none".localized,
            description: "recording_indicator.prompt.none_desc".localized,
            isSelected: isSelected,
            onSelect: isAutoDetectEnabled ? nil : {
                meetingViewModel.selectPrompt(AppSettingsStore.noPostProcessingPromptId, forceSelect: true)
            },
            unselectedStrokeColor: AppDesignSystem.Colors.settingsCardStroke,
            showMenu: false,
            preserveMenuSpacing: true,
            menuAccessibilityLabel: "transcription.ai_actions".localized
        ) {
            EmptyView()
        }
    }

    private func webTargetAccessibilityLabel(for target: WebMeetingTarget) -> String {
        [target.displayName, target.urlPatterns.joined(separator: ", "), browserNames(from: target.browserBundleIdentifiers)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func openPromptEditor(for prompt: PostProcessingPrompt) {
        meetingViewModel.editingPrompt = prompt
        meetingViewModel.showPromptEditor = true
    }
}

#Preview {
    MeetingSettingsTab()
}
