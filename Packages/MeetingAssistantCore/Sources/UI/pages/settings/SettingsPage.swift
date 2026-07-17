import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Layout Constants

private enum LayoutConstants {
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 640
    static let sidebarWidth: CGFloat = 220
    /// Clears traffic lights under the transparent titlebar (VoiceInk AppScreenHeader pattern).
    static let titlebarClearance: CGFloat = 20
}

// MARK: - Settings View

/// Settings view for app configuration.
/// Custom HStack sidebar + detail shell (no NavigationSplitView / SwiftUI toolbar).
public struct SettingsView: View {
    private let settingsStore = AppSettingsStore.shared
    @State private var selectedSection: SettingsSection = .activity
    @State private var settingsSearchText = ""
    @State private var activityNavigationState = ActivitySettingsNavigationState()
    @State private var transcriptionsNavigationHistory = TranscriptionsNavigationHistory()
    @State private var systemRoute: SystemSettingsRoute = .root
    @State private var expandProtectedApps = false
    @State private var isSidebarVisible: Bool
    @State private var navigationService = NavigationService.shared
    @State private var requestedModesSubroute: DictationStyleRoute?
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.settingsReduceTransparencyPreview) private var reduceTransparencyPreview

    @MainActor
    public init() {
        _isSidebarVisible = State(initialValue: AppSettingsStore.shared.isSettingsSidebarVisible)
    }

    public var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebarColumn
            }

            detailColumn
        }
        .background(SettingsWindowConfigurator())
        .frame(minWidth: LayoutConstants.windowWidth, minHeight: LayoutConstants.windowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            syncSidebarVisibilityFromStore()
            if let sectionId = navigationService.requestedSettingsSection,
               let destination = SettingsSection.resolvedDestination(for: sectionId)
            {
                selectDestination(destination)
                navigationService.requestedSettingsSection = nil
            }
        }
        .onChange(of: navigationService.requestedSettingsSection) { _, sectionId in
            guard let sectionId else { return }
            if let destination = SettingsSection.resolvedDestination(for: sectionId) {
                selectDestination(destination)
            }
            navigationService.requestedSettingsSection = nil
        }
        .onChange(of: navigationService.settingsSidebarToggleRequestID) { _, _ in
            toggleSidebar()
        }
    }

    private var sidebarColumn: some View {
        ZStack(alignment: .trailing) {
            sidebarBackground
            sidebarDivider
            SettingsSidebarView(
                selectedSection: $selectedSection,
                searchText: $settingsSearchText,
                onSelectDestination: selectDestination,
            )
            .padding(.top, LayoutConstants.titlebarClearance)
        }
        .frame(width: LayoutConstants.sidebarWidth)
        .frame(maxHeight: .infinity)
    }

    private var effectiveReduceTransparency: Bool {
        accessibilityReduceTransparency
            || reduceTransparencyPreview
            || AppDesignSystem.Accessibility.reduceTransparency
    }

    private var sidebarBackground: some View {
        Group {
            if effectiveReduceTransparency {
                AppDesignSystem.Colors.settingsCanvasBackground
            } else {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .accessibilityHidden(true)
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(AppDesignSystem.Colors.separator.opacity(colorSchemeContrast == .increased ? 0.78 : 0.42))
            .frame(width: 1)
            .ignoresSafeArea(.container, edges: .top)
            .accessibilityHidden(true)
    }

    private var detailColumn: some View {
        ZStack(alignment: .topLeading) {
            SettingsWindowBackground()

            VStack(spacing: 0) {
                if !isSidebarVisible {
                    collapsedSidebarChrome
                }

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Transparent inset for the sidebar toggle when chrome is collapsed — no opaque title strip.
    private var collapsedSidebarChrome: some View {
        HStack(spacing: 12) {
            sidebarToggleButton
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, LayoutConstants.titlebarClearance)
        .padding(.bottom, 10)
    }

    private var sidebarToggleButton: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(sidebarToggleHelpText)
        .accessibilityLabel(sidebarToggleHelpText)
    }
}

private extension SettingsView {

    private func selectDestination(_ destination: SettingsDestination) {
        selectedSection = destination.section
        activityNavigationState.pendingSheet = destination.activityPendingSheet
        expandProtectedApps = destination.expandProtectedApps
        if destination.section == .system {
            systemRoute = destination.systemRoute ?? .root
        }
        if destination.section == .dictionary {
            systemRoute = .root
        }
        if destination.section == .modes || destination.section == .assistant || destination.section == .integrations {
            requestedModesSubroute = destination.modesSubroute
        }
    }

    private func toggleSidebar() {
        let next = !isSidebarVisible
        isSidebarVisible = next
        persistSidebarVisibility(next)
    }

    private func syncSidebarVisibilityFromStore() {
        let visible = settingsStore.isSettingsSidebarVisible
        isSidebarVisible = visible
        navigationService.setSettingsSidebarVisible(visible)
    }

    private func persistSidebarVisibility(_ isVisible: Bool) {
        settingsStore.isSettingsSidebarVisible = isVisible
        navigationService.setSettingsSidebarVisible(isVisible)
    }

    private var sidebarToggleHelpText: String {
        let key = isSidebarVisible
            ? "commands.view.hide_sidebar"
            : "commands.view.show_sidebar"
        return key.localized
    }

    @MainActor
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .metrics, .activity:
            ActivitySettingsTab(navigationState: $activityNavigationState)
        case .history, .transcriptions:
            TranscriptionsSettingsTab(navigationHistory: $transcriptionsNavigationHistory)
        case .general:
            GeneralSettingsTab()
        case .models:
            ModelsSettingsTab()
        case .vocabulary, .dictionary:
            DictionarySettingsTab()
        case .dictation, .modes:
            ModesSettingsTab(initialRoute: $requestedModesSubroute)
        case .meetings:
            MeetingSettingsTab()
        case .assistant, .integrations:
            ModesSettingsTab(initialRoute: $requestedModesSubroute)
        case .audio:
            SystemSettingsTab(route: .constant(.sound))
        case .enhancements:
            EnhancementsSettingsTab()
        case .permissions:
            PermissionsSettingsTab()
        case .intelligence:
            SystemSettingsTab(route: .constant(.models))
        case .system:
            SystemSettingsTab(
                route: $systemRoute,
                expandProtectedApps: $expandProtectedApps,
            )
        }
    }

}

#Preview("Settings Content") {
    SettingsView()
}
