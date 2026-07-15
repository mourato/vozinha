import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

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
    @State private var showAppSearchSheet = false
    private let showsHeader: Bool
    private let content: EnhancementsSettingsContent

    public init(
        settings: AppSettingsStore = .shared,
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
        self.showsHeader = showsHeader
        self.content = content
    }

    public var body: some View {
        rootPage
    }

    // MARK: - Sections

    private var rootPage: some View {
        SettingsFormPage {
            VStack(alignment: .leading, spacing: 4) {
                SettingsFormSectionHeader(title: headerTitle, icon: "brain")
                if showsHeader {
                    Text("settings.text_context.description".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } content: {
            switch content {
            case .all:
                mainSection
                protectSensitiveAppsSection
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
        Section {
            DSToggleRow(
                "settings.post_processing.enabled".localized,
                description: "settings.post_processing.description".localized,
                isOn: $postProcessingViewModel.settings.postProcessingEnabled,
            )

        } header: {
            SettingsFormSectionHeader(title: "settings.post_processing.title".localized, icon: "brain")
        }
    }

    private var protectSensitiveAppsSection: some View {
        Section {
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
        } header: {
            SettingsFormSectionHeader(title: "settings.context_awareness.protect_sensitive_apps".localized, icon: "lock.shield")
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
