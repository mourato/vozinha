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
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 260
}

// MARK: - Settings View

/// Settings view for app configuration.
/// Uses sidebar navigation pattern similar to macOS System Settings.
public struct SettingsView: View {
    private enum ToolbarLayout {
        static let transcriptionsSearchWidth: CGFloat = 230
    }

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
    @State private var transcriptionsSearchText = ""
    @State private var meetingNavigationState = MeetingSettingsNavigationState()
    @State private var dictationNavigationState = SettingsSubpageNavigationState<DictationSettingsRoute>()
    @State private var enhancementsNavigationState = SettingsSubpageNavigationState<EnhancementsSettingsRoute>()
    @State private var intelligenceRoute: IntelligenceSettingsRoute = .models
    @State private var intelligenceTextContextNavigationState = SettingsSubpageNavigationState<EnhancementsSettingsRoute>()
    @State private var columnVisibility: NavigationSplitViewVisibility
    @StateObject private var navigationService = NavigationService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                usesToolbarChrome: usesToolbarChrome
            ))
            .tint(AppDesignSystem.Colors.accent)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(settingsNavigationTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if usesToolbarChrome {
                settingsToolbarContent
            }
        }
        .modifier(SettingsToolbarBackgroundModifier(usesToolbarChrome: usesToolbarChrome))
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
        .onReceive(navigationService.$requestedSettingsSection.compactMap(\.self)) { sectionId in
            if let destination = SettingsSection.resolvedDestination(for: sectionId) {
                selectDestination(destination)
            }
            navigationService.requestedSettingsSection = nil
            consumePendingActivityRoute()
        }
        .onReceive(navigationService.$settingsSidebarToggleRequestID.dropFirst()) { _ in
            toggleSidebar()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        SettingsSidebarView(
            selectedSection: $selectedSection,
            searchText: $settingsSearchText,
            onSelectDestination: selectDestination
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationSplitViewColumnWidth(
            min: LayoutConstants.sidebarMinWidth,
            ideal: LayoutConstants.sidebarIdealWidth,
            max: LayoutConstants.sidebarMaxWidth
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

    @ToolbarContentBuilder
    private var settingsToolbarContent: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) {
                toolbarNavigationControlGroup
            }

            if shouldShowTranscriptionsSearch {
                ToolbarItem(placement: .primaryAction) {
                    transcriptionsToolbarSearchField
                }
            }

            if showsCapabilityToolbarAccessory {
                ToolbarItem(placement: .automatic) {
                    capabilityToolbarAccessory
                }
            }
        }
    }

    @ViewBuilder
    private var detailNavigationBar: some View {
        if #available(macOS 26.0, *), showsEmbeddedTahoeChrome {
            tahoeDetailNavigationBar
        } else if shouldShowLegacyChrome {
            legacyDetailNavigationBar
        }
    }

    private var showsEmbeddedTahoeChrome: Bool {
        guard #available(macOS 26.0, *) else {
            return false
        }

        switch chromeMode {
        case .embedded:
            return true
        case .automatic:
            return !usesToolbarChrome
        case .toolbar, .none:
            return false
        }
    }

    private var shouldShowLegacyChrome: Bool {
        switch chromeMode {
        case .none, .toolbar:
            false
        case .embedded, .automatic:
            !showsEmbeddedTahoeChrome
        }
    }

    private var shouldShowTranscriptionsSearch: Bool {
        selectedSection == .activity && activityNavigationState.isShowingHistoryList
    }

    @available(macOS 26.0, *)
    private var tahoeDetailNavigationBar: some View {
        HStack {
            toolbarNavigationControlGroup
            if shouldShowTranscriptionsSearch {
                Spacer()
                transcriptionsToolbarSearchField
            } else if showsCapabilityToolbarAccessory {
                Spacer()
                capabilityToolbarAccessory
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    @available(macOS 26.0, *)
    private var toolbarNavigationControlGroup: some View {
        ControlGroup {
            Button(action: navigateBack) {
                Label("transcription.qa.navigation.back".localized, systemImage: "chevron.left")
            }
            .help("transcription.qa.navigation.back".localized)
            .accessibilityLabel("transcription.qa.navigation.back".localized)
            .disabled(!canNavigateBack)

            Button(action: navigateForward) {
                Label("transcription.qa.navigation.forward".localized, systemImage: "chevron.right")
            }
            .help("transcription.qa.navigation.forward".localized)
            .accessibilityLabel("transcription.qa.navigation.forward".localized)
            .disabled(!canNavigateForward)
        }
        .controlGroupStyle(.navigation)
    }

    private var legacyDetailNavigationBar: some View {
        HStack(spacing: 12) {
            if !navigationService.isSettingsSidebarVisible {
                legacySidebarToggleButton
            }

            HStack(spacing: 6) {
                legacyNavigationHistoryButton(
                    systemImage: "chevron.left",
                    helpKey: "transcription.qa.navigation.back",
                    isEnabled: canNavigateBack,
                    action: navigateBack
                )

                legacyNavigationHistoryButton(
                    systemImage: "chevron.right",
                    helpKey: "transcription.qa.navigation.forward",
                    isEnabled: canNavigateForward,
                    action: navigateForward
                )
            }

            Text(selectedSection.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)

            if shouldShowTranscriptionsSearch {
                transcriptionsSearchField
                    .frame(width: ToolbarLayout.transcriptionsSearchWidth)
            } else if showsCapabilityToolbarAccessory {
                capabilityToolbarAccessory
            }
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

    @available(macOS 26.0, *)
    private var transcriptionsToolbarSearchField: some View {
        transcriptionsSearchField
            .frame(width: ToolbarLayout.transcriptionsSearchWidth)
    }

    private var transcriptionsSearchField: some View {
        SettingsSearchField(
            text: $transcriptionsSearchText,
            placeholder: "settings.transcriptions.search_placeholder".localized
        )
    }

    private var showsCapabilityToolbarAccessory: Bool {
        selectedSection == .meetings || selectedSection == .integrations
    }

    @ViewBuilder
    private var capabilityToolbarAccessory: some View {
        switch selectedSection {
        case .meetings:
            makeCapabilityToolbarToggle(
                title: "settings.capabilities.meeting_transcription".localized,
                isOn: Binding(
                    get: { settingsStore.isMeetingTranscriptionEnabled },
                    set: { settingsStore.isMeetingTranscriptionEnabled = $0 }
                )
            )
        case .integrations:
            makeCapabilityToolbarToggle(
                title: "settings.capabilities.assistant_integrations".localized,
                isOn: Binding(
                    get: { settingsStore.isAssistantIntegrationsEnabled },
                    set: { settingsStore.isAssistantIntegrationsEnabled = $0 }
                )
            )
        default:
            EmptyView()
        }
    }

    private func makeCapabilityToolbarToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn.animated(using: SettingsMotion.sectionAnimation))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel(title)
            .animation(SettingsMotion.sectionAnimation(reduceMotion: reduceMotion), value: isOn.wrappedValue)
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

    private func legacyNavigationHistoryButton(
        systemImage: String,
        helpKey: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .foregroundStyle(isEnabled ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.secondary.opacity(0.75)))
        .opacity(isEnabled ? 1 : 0.65)
        .help(helpKey.localized)
        .accessibilityLabel(helpKey.localized)
        .disabled(!isEnabled)
    }

    private func navigateBack() {
        switch selectedSection {
        case .activity:
            activityNavigationState.goBack()
        case .meetings where meetingNavigationState.canGoBack:
            _ = meetingNavigationState.goBack()
        case .dictation where dictationNavigationState.canGoBack:
            _ = dictationNavigationState.goBack()
        case .enhancements where enhancementsNavigationState.canGoBack:
            _ = enhancementsNavigationState.goBack()
        case .intelligence where canNavigateIntelligenceTextContextBack:
            _ = intelligenceTextContextNavigationState.goBack()
        default:
            break
        }
    }

    private func navigateForward() {
        switch selectedSection {
        case .activity:
            activityNavigationState.goForward()
        case .meetings where meetingNavigationState.canGoForward:
            _ = meetingNavigationState.goForward()
        case .dictation where dictationNavigationState.canGoForward:
            _ = dictationNavigationState.goForward()
        case .enhancements where enhancementsNavigationState.canGoForward:
            _ = enhancementsNavigationState.goForward()
        case .intelligence where canNavigateIntelligenceTextContextForward:
            _ = intelligenceTextContextNavigationState.goForward()
        default:
            break
        }
    }

    private func selectDestination(_ destination: SettingsDestination) {
        if selectedSection == .activity, destination.section != .activity {
            transcriptionsSearchText = ""
        }
        selectedSection = destination.section
        activityNavigationState.apply(destination.activityRoute)
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

    private var canNavigateBack: Bool {
        switch selectedSection {
        case .activity:
            activityNavigationState.canGoBack
        case .meetings:
            meetingNavigationState.canGoBack
        case .dictation:
            dictationNavigationState.canGoBack
        case .enhancements:
            enhancementsNavigationState.canGoBack
        case .intelligence:
            canNavigateIntelligenceTextContextBack
        default:
            false
        }
    }

    private var canNavigateForward: Bool {
        switch selectedSection {
        case .activity:
            activityNavigationState.canGoForward
        case .meetings:
            meetingNavigationState.canGoForward
        case .dictation:
            dictationNavigationState.canGoForward
        case .enhancements:
            enhancementsNavigationState.canGoForward
        case .intelligence:
            canNavigateIntelligenceTextContextForward
        default:
            false
        }
    }

    private var canNavigateIntelligenceTextContextBack: Bool {
        intelligenceRoute == .textContext && intelligenceTextContextNavigationState.canGoBack
    }

    private var canNavigateIntelligenceTextContextForward: Bool {
        intelligenceRoute == .textContext && intelligenceTextContextNavigationState.canGoForward
    }

    @MainActor
    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .metrics:
            MetricsDashboardSettingsTab(navigationState: $activityNavigationState.metricsNavigationState)
        case .general:
            GeneralSettingsTab()
        case .models:
            ModelsSettingsTab()
        case .vocabulary:
            VocabularySettingsTab()
        case .dictation:
            DictationSettingsTab(navigationState: $dictationNavigationState)
        case .meetings:
            MeetingSettingsTab(navigationState: $meetingNavigationState)
        case .assistant:
            AssistantSettingsTab()
        case .integrations:
            IntegrationsSettingsTab()
        case .audio:
            AudioSettingsTab()
        case .transcriptions:
            TranscriptionsSettingsTab(
                searchText: $transcriptionsSearchText,
                navigationHistory: $activityNavigationState.transcriptionsNavigationHistory
            )
        case .enhancements:
            EnhancementsSettingsTab(navigationState: $enhancementsNavigationState)
        case .permissions:
            PermissionsSettingsTab()
        case .activity:
            ActivitySettingsTab(
                navigationState: $activityNavigationState,
                transcriptionsSearchText: $transcriptionsSearchText
            )
        case .intelligence:
            IntelligenceSettingsTab(
                route: $intelligenceRoute,
                textContextNavigationState: $intelligenceTextContextNavigationState
            )
        case .system:
            GeneralSettingsTab()
        }
    }

}

private struct SettingsDetailChromeModifier<LegacyHeader: View>: ViewModifier {
    let legacyHeader: LegacyHeader
    let usesToolbarChrome: Bool

    func body(content: Content) -> some View {
        if usesToolbarChrome {
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
            previewNavigationControls
            previewSectionTitle
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 900, alignment: .leading)
    }

    private var previewNavigationControls: some View {
        HStack(spacing: 2) {
            previewNavButton("chevron.left")
            previewNavButton("chevron.right")
        }
    }

    private func previewNavButton(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }

    private var previewSectionTitle: some View {
        Label("settings.section.metrics".localized, systemImage: "chart.pie.fill")
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
