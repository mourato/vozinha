import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public enum EnhancementsSettingsRoute: Hashable {
    case systemGuidelines
}

public enum EnhancementsSettingsContent: Sendable {
    case all
    case protectedApps
    case postProcessing
}

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct EnhancementsSettingsTab: View {
    @StateObject private var postProcessingViewModel: PostProcessingSettingsViewModel
    @StateObject private var sensitiveAppsViewModel: InstalledAppsSelectionViewModel
    @Binding private var navigationState: SettingsSubpageNavigationState<EnhancementsSettingsRoute>
    @State private var systemGuidelinesDraft = ""
    @State private var showAppSearchSheet = false
    private let showsHeader: Bool
    private let content: EnhancementsSettingsContent

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<SettingsSubpageNavigationState<EnhancementsSettingsRoute>> = .constant(SettingsSubpageNavigationState()),
        showsHeader: Bool = true,
        content: EnhancementsSettingsContent = .all,
    ) {
        _postProcessingViewModel = StateObject(wrappedValue: PostProcessingSettingsViewModel(settings: settings))
        _sensitiveAppsViewModel = StateObject(
            wrappedValue: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: [],
                protectedBundleIdentifiers: TextContextExclusionPolicy.defaultBundleIDs,
                hasConfigured: { true },
                loadBundleIdentifiers: { settings.contextAwarenessExcludedBundleIDs },
                saveBundleIdentifiers: { settings.contextAwarenessExcludedBundleIDs = $0 },
            ),
        )
        _navigationState = navigationState
        self.showsHeader = showsHeader
        self.content = content
    }

    public var body: some View {
        switch navigationState.currentRoute {
        case nil:
            rootPage
        case .some(.systemGuidelines):
            systemGuidelinesPage
        }
    }

    // MARK: - Sections

    private var rootPage: some View {
        SettingsScrollableContent {
            if showsHeader {
                SettingsSectionHeader(
                    title: headerTitle,
                    description: "settings.text_context.description".localized,
                )
            }

            switch content {
            case .all:
                protectSensitiveAppsSection
                mainSection
            case .protectedApps:
                protectSensitiveAppsSection
            case .postProcessing:
                mainSection
            }
        }
    }

    private var headerTitle: String {
        switch content {
        case .all:
            "settings.section.ai".localized
        case .protectedApps:
            "settings.context_awareness.protect_sensitive_apps".localized
        case .postProcessing:
            "settings.post_processing.title".localized
        }
    }

    private var mainSection: some View {
        SettingsListGroup("settings.post_processing.title".localized, icon: "brain") {
            DSToggleRow(
                "settings.post_processing.enabled".localized,
                description: "settings.post_processing.description".localized,
                isOn: $postProcessingViewModel.settings.postProcessingEnabled,
            )

            SettingsListDrillDownButtonRow(
                title: "settings.post_processing.edit_system_prompt".localized,
                accessibilityHint: "settings.post_processing.system_guidelines.accessibility_hint".localized,
            ) {
                navigationState.open(.systemGuidelines)
            }
        }
    }

    private var protectSensitiveAppsSection: some View {
        DSGroup("settings.context_awareness.protect_sensitive_apps".localized, icon: "lock.shield") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
                Text("settings.context_awareness.protect_sensitive_apps_desc".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                InstalledAppsSelectionList(
                    emptyKey: "settings.context_awareness.excluded_apps_empty",
                    addButtonKey: "settings.context_awareness.excluded_apps_add",
                    removeButtonKey: "settings.context_awareness.excluded_apps_remove",
                    protectedBadgeKey: "settings.context_awareness.always_excluded_badge",
                    onAddApp: { showAppSearchSheet = true },
                    viewModel: sensitiveAppsViewModel,
                )
            }
        }
        .sheet(isPresented: $showAppSearchSheet) {
            AppSearchSheet(
                viewModel: sensitiveAppsViewModel,
                isPresented: $showAppSearchSheet,
                titleKey: "settings.context_awareness.protect_sensitive_apps",
                descriptionKey: "settings.context_awareness.protect_sensitive_apps_desc",
                addButtonKey: "settings.context_awareness.excluded_apps_add",
            )
        }
    }

    private var systemGuidelinesPage: some View {
        SettingsScrollableContent {
            DSGroup("settings.post_processing.system_prompt".localized, icon: "terminal.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SettingsTitleWithPopover(
                            title: "settings.post_processing.base_instructions".localized,
                            helperMessage: "prompt.instructions_hint".localized,
                            font: .subheadline,
                            fontWeight: .medium,
                        )
                        Spacer()
                        Button("settings.post_processing.restore_default".localized) {
                            restoreSystemGuidelines()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    TextEditor(text: $systemGuidelinesDraft)
                        .font(.body)
                        .frame(minHeight: 250)
                        .enhancementsEditorSurface(intensity: .strong)

                    HStack {
                        Spacer()
                        Button("common.save".localized) {
                            saveSystemGuidelines()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppDesignSystem.Colors.accent)
                        .disabled(systemGuidelinesDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            systemGuidelinesDraft = postProcessingViewModel.settings.systemPrompt
        }
    }

    private func restoreSystemGuidelines() {
        postProcessingViewModel.resetSystemPrompt()
        systemGuidelinesDraft = postProcessingViewModel.settings.systemPrompt
    }

    private func saveSystemGuidelines() {
        postProcessingViewModel.handleSaveSystemPrompt(systemGuidelinesDraft)
    }

}

private extension View {
    func enhancementsEditorSurface(
        intensity: AppDesignSystem.SettingsSurfaceIntensity = .subtle,
    ) -> some View {
        padding(AppDesignSystem.Layout.textAreaPadding)
            .background(AppDesignSystem.Colors.settingsInlineBackground(intensity: intensity))
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
    }
}

#Preview {
    EnhancementsSettingsTab()
}
