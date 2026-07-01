import AppKit
import CoreGraphics
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

// MARK: - AI Settings Tab

/// Tab for configuring AI post-processing settings.
public struct EnhancementsSettingsTab: View {
    @StateObject private var postProcessingViewModel: PostProcessingSettingsViewModel
    @StateObject private var sensitiveAppsViewModel: InstalledAppsSelectionViewModel
    @Binding private var navigationState: SettingsSubpageNavigationState<EnhancementsSettingsRoute>
    @State private var supportStatus: TextContextSupportStatus = .unknown
    @State private var hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    @State private var systemGuidelinesDraft = ""
    @State private var showAppSearchSheet = false
    private let supportChecker = TextContextSupportChecker()

    public init(
        settings: AppSettingsStore = .shared,
        navigationState: Binding<SettingsSubpageNavigationState<EnhancementsSettingsRoute>> = .constant(SettingsSubpageNavigationState())
    ) {
        _postProcessingViewModel = StateObject(wrappedValue: PostProcessingSettingsViewModel(settings: settings))
        _sensitiveAppsViewModel = StateObject(
            wrappedValue: InstalledAppsSelectionViewModel(
                defaultBundleIdentifiers: [],
                protectedBundleIdentifiers: TextContextExclusionPolicy.defaultBundleIDs,
                hasConfigured: { true },
                loadBundleIdentifiers: { settings.contextAwarenessExcludedBundleIDs },
                saveBundleIdentifiers: { settings.contextAwarenessExcludedBundleIDs = $0 }
            )
        )
        _navigationState = navigationState
    }

    public var body: some View {
        Group {
            switch navigationState.currentRoute {
            case nil:
                rootPage
            case .some(.systemGuidelines):
                systemGuidelinesPage
            }
        }
    }

    // MARK: - Sections

    private var rootPage: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.ai".localized,
                description: "settings.text_context.description".localized
            )

            protectSensitiveAppsSection
            contextAwarenessSection
            mainSection
        }
    }

    private var mainSection: some View {
        DSGroup("settings.post_processing.title".localized, icon: "brain") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
                DSToggleRow(
                    "settings.post_processing.enabled".localized,
                    description: "settings.post_processing.description".localized,
                    isOn: $postProcessingViewModel.settings.postProcessingEnabled
                )

                VStack(alignment: .leading, spacing: 0) {

                    Divider()

                    SettingsDrillDownButtonRow(
                        title: "settings.post_processing.edit_system_prompt".localized,
                        accessibilityHint: "settings.post_processing.system_guidelines.accessibility_hint".localized
                    ) {
                        navigationState.open(.systemGuidelines)
                    }

                    Divider()
                }
            }
        }
    }

    private var contextAwarenessSection: some View {
        DSGroup("settings.context_awareness.title".localized, icon: "text.viewfinder") {
            VStack(alignment: .leading, spacing: AppDesignSystem.Layout.itemSpacing) {
                DSToggleRow(
                    "settings.context_awareness.enabled".localized,
                    description: "settings.context_awareness.enabled_desc".localized,
                    isOn: $postProcessingViewModel.settings.contextAwarenessEnabled
                )

                if postProcessingViewModel.settings.contextAwarenessEnabled {
                    DSToggleRow(
                        "settings.context_awareness.accessibility_text".localized,
                        description: "settings.context_awareness.accessibility_text_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeAccessibilityText
                    )

                    if postProcessingViewModel.settings.contextAwarenessIncludeAccessibilityText {
                        contextAwarenessSupportStatus
                    }

                    Divider()

                    DSToggleRow(
                        "settings.context_awareness.clipboard".localized,
                        description: "settings.context_awareness.clipboard_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeClipboard
                    )

                    DSToggleRow(
                        "settings.context_awareness.window_ocr".localized,
                        description: "settings.context_awareness.window_ocr_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessIncludeWindowOCR
                    )

                    if postProcessingViewModel.settings.contextAwarenessIncludeWindowOCR {
                        screenRecordingSupportStatus
                    }

                    DSToggleRow(
                        "settings.context_awareness.redact_sensitive_data".localized,
                        description: "settings.context_awareness.redact_sensitive_data_desc".localized,
                        isOn: $postProcessingViewModel.settings.contextAwarenessRedactSensitiveData
                    )

                }
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
                    viewModel: sensitiveAppsViewModel
                )
            }
        }
        .sheet(isPresented: $showAppSearchSheet) {
            AppSearchSheet(
                viewModel: sensitiveAppsViewModel,
                isPresented: $showAppSearchSheet,
                titleKey: "settings.context_awareness.protect_sensitive_apps",
                descriptionKey: "settings.context_awareness.protect_sensitive_apps_desc",
                addButtonKey: "settings.context_awareness.excluded_apps_add"
            )
        }
    }

    private var contextAwarenessSupportStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch supportStatus {
            case .permissionDenied:
                DSCallout(
                    kind: .warning,
                    title: "settings.context_awareness.permission_title".localized,
                    message: "settings.context_awareness.permission_desc".localized
                )

                HStack(spacing: 8) {
                    Button("permissions.request".localized) {
                        AccessibilityPermissionService.requestPermission()
                        Task { await refreshSupportStatus() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button("permissions.configure".localized) {
                        AccessibilityPermissionService.openSystemSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

            case .noActiveApp, .supported, .unknown, .noFocusedElement, .unsupported:
                EmptyView()
            }
        }
        .task { await refreshSupportStatus() }
    }

    private var screenRecordingSupportStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hasScreenRecordingPermission {
                DSCallout(
                    kind: .warning,
                    title: "settings.context_awareness.screen_permission_title".localized,
                    message: "settings.context_awareness.screen_permission_desc".localized
                )

                HStack(spacing: 8) {
                    Button("permissions.request".localized) {
                        CGRequestScreenCaptureAccess()
                        refreshScreenRecordingPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button("permissions.configure".localized) {
                        openScreenRecordingSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
        .task { refreshScreenRecordingPermission() }
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
                            fontWeight: .medium
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

    @MainActor
    private func refreshSupportStatus() async {
        supportStatus = await supportChecker.checkSupport()
    }

    private func refreshScreenRecordingPermission() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private extension View {
    func enhancementsEditorSurface(
        intensity: AppDesignSystem.SettingsSurfaceIntensity = .subtle
    ) -> some View {
        padding(AppDesignSystem.Layout.textAreaPadding)
            .background(AppDesignSystem.Colors.settingsInlineBackground(intensity: intensity))
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.Layout.smallCornerRadius))
    }
}

#Preview {
    EnhancementsSettingsTab()
}
