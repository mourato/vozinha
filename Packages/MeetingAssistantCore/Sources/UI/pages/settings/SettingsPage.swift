import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

// MARK: - Settings View

// MARK: - Layout Constants

private enum LayoutConstants {
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 640
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 260
}

// MARK: - Settings View

/// Settings view for app configuration.
/// Uses sidebar navigation pattern similar to macOS System Settings.
public struct SettingsView: View {
    fileprivate enum ChromeMode {
        case automatic
        case toolbar
        case embedded
        case none
    }

    private let chromeMode: ChromeMode
    private let settingsStore = AppSettingsStore.shared
    @State private var selectedSection: SettingsSection = .activity
    @State private var settingsSearchText = ""
    @State private var activityNavigationState = ActivitySettingsNavigationState()
    @State private var systemRoute: SystemSettingsRoute = .root
    @State private var expandProtectedApps = false
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var navigationService = NavigationService.shared
    @State private var requestedModesSubroute: DictationStyleRoute?

    @MainActor
    public init() {
        chromeMode = .automatic
        _columnVisibility = State(initialValue: AppSettingsStore.shared.isSettingsSidebarVisible ? .all : .detailOnly)
    }

    @MainActor
    fileprivate init(chromeMode: ChromeMode) {
        self.chromeMode = chromeMode
        _columnVisibility = State(initialValue: AppSettingsStore.shared.isSettingsSidebarVisible ? .all : .detailOnly)
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            ZStack(alignment: .topLeading) {
                SettingsWindowBackground()

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .modifier(SettingsDetailChromeModifier(
                legacyHeader: detailNavigationBar,
                usesToolbarChrome: usesToolbarChrome,
            ))
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(settingsNavigationTitle)
        .toolbarTitleDisplayMode(.inline)
        .modifier(SettingsToolbarBackgroundModifier(usesToolbarChrome: usesToolbarChrome))
        .background(SettingsWindowConfigurator())
        .frame(minWidth: LayoutConstants.windowWidth, minHeight: LayoutConstants.windowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            persistSidebarVisibility(columnVisibility)
            if let sectionId = navigationService.requestedSettingsSection,
               let destination = SettingsSection.resolvedDestination(for: sectionId)
            {
                selectDestination(destination)
                navigationService.requestedSettingsSection = nil
            }
            consumePendingActivityRoute()
        }
        .onChange(of: columnVisibility) { _, newValue in
            persistSidebarVisibility(newValue)
        }
        .onChange(of: navigationService.requestedSettingsSection) { _, sectionId in
            guard let sectionId else { return }
            if let destination = SettingsSection.resolvedDestination(for: sectionId) {
                selectDestination(destination)
            }
            navigationService.requestedSettingsSection = nil
            consumePendingActivityRoute()
        }
        .onChange(of: navigationService.settingsSidebarToggleRequestID) { _, _ in
            toggleSidebar()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        SettingsSidebarView(
            selectedSection: $selectedSection,
            searchText: $settingsSearchText,
            onSelectDestination: selectDestination,
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth,
        )
    }

}

private extension SettingsView {

    // MARK: - Detail View

    var usesToolbarChrome: Bool {
        switch chromeMode {
        case .toolbar:
            return true
        case .embedded, .none:
            return false
        case .automatic:
            guard #available(macOS 26.0, *) else {
                return false
            }
            return true
        }
    }

    var settingsNavigationTitle: String {
        usesToolbarChrome ? selectedSection.title : ""
    }

    @ViewBuilder
    private var detailNavigationBar: some View {
        if shouldShowLegacyChrome {
            legacyDetailNavigationBar
        }
    }

    private var shouldShowLegacyChrome: Bool {
        switch chromeMode {
        case .none, .toolbar:
            false
        case .embedded, .automatic:
            true
        }
    }

    private var legacyDetailNavigationBar: some View {
        HStack(spacing: 12) {
            if !navigationService.isSettingsSidebarVisible {
                legacySidebarToggleButton
            }

            Text(selectedSection.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            SettingsTitleBarMaterialBackground(usesBottomFade: false)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var legacySidebarToggleButton: some View {
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

    private func selectDestination(_ destination: SettingsDestination) {
        selectedSection = destination.section
        activityNavigationState.apply(destination.activityRoute)
        activityNavigationState.pendingSheet = destination.activityPendingSheet
        expandProtectedApps = destination.expandProtectedApps
        if destination.section == .system {
            systemRoute = destination.systemRoute ?? .root
        }
        if destination.section == .modes || destination.section == .assistant || destination.section == .integrations {
            requestedModesSubroute = destination.modesSubroute
        }
        consumePendingActivityRoute()
    }

    private func consumePendingActivityRoute() {
        guard selectedSection == .activity,
              let subroute = navigationService.requestedActivitySubroute
        else { return }
        navigationService.requestedActivitySubroute = nil
        switch subroute {
        case .history:
            activityNavigationState.apply(.history)
        }
    }

    private func toggleSidebar() {
        columnVisibility = navigationService.isSettingsSidebarVisible ? .detailOnly : .all
    }

    private func persistSidebarVisibility(_ visibility: NavigationSplitViewVisibility) {
        let isVisible = visibility != .detailOnly
        settingsStore.isSettingsSidebarVisible = isVisible
        navigationService.setSettingsSidebarVisible(isVisible)
    }

    private var sidebarToggleHelpText: String {
        let key = navigationService.isSettingsSidebarVisible
            ? "commands.view.hide_sidebar"
            : "commands.view.show_sidebar"
        return key.localized
    }

    @MainActor
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .metrics, .activity, .transcriptions:
            ActivitySettingsTab(navigationState: $activityNavigationState)
        case .general:
            GeneralSettingsTab()
        case .models:
            ModelsSettingsTab()
        case .vocabulary:
            VocabularySettingsTab()
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

private struct SettingsDetailChromeModifier<LegacyHeader: View>: ViewModifier {
    let legacyHeader: LegacyHeader
    let usesToolbarChrome: Bool

    func body(content: Content) -> some View {
        if !SettingsChromeLayoutPolicy.usesLegacyHeader(usesToolbarChrome: usesToolbarChrome) {
            // The native SwiftUI toolbar already reserves its own safe-area.
            // Adding the legacy 44pt boundary here creates a second vertical gap.
            content
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                legacyHeader
            }
        }
    }
}

private struct SettingsToolbarBackgroundModifier: ViewModifier {
    let usesToolbarChrome: Bool

    func body(content: Content) -> some View {
        content
    }
}

private struct SettingsToolbarChromePreview: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("settings.section.activity".localized)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 900, alignment: .leading)
    }
}

#Preview("Toolbar", traits: .sizeThatFitsLayout) {
    SettingsToolbarChromePreview()
}

#Preview("Settings Content") {
    SettingsView(chromeMode: .none)
}

#Preview("Settings Content (Toolbar)") {
    SettingsView(chromeMode: .toolbar)
}
