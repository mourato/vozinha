import MeetingAssistantCoreCommon
import SwiftUI

public enum SystemSettingsRoute: Hashable, Sendable {
    case root
    case models
    case sound
}

public struct SystemSettingsTab: View {
    @Binding private var route: SystemSettingsRoute
    @Binding private var expandProtectedApps: Bool
    private let onCheckForUpdates: (() -> Void)?

    public init(
        route: Binding<SystemSettingsRoute> = .constant(.root),
        expandProtectedApps: Binding<Bool> = .constant(false),
        onCheckForUpdates: (() -> Void)? = nil,
    ) {
        _route = route
        _expandProtectedApps = expandProtectedApps
        self.onCheckForUpdates = onCheckForUpdates
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @MainActor
    @ViewBuilder
    private var content: some View {
        switch route {
        case .root:
            GeneralSettingsTab(
                showsHeader: true,
                headerTitleKey: "settings.section.settings",
                headerDescriptionKey: "settings.system.description",
                openModels: { route = .models },
                openSound: { route = .sound },
                expandProtectedApps: $expandProtectedApps,
                onCheckForUpdates: onCheckForUpdates,
            )
        case .models:
            ModelsSettingsTab(onBack: { route = .root })
        case .sound:
            AudioSettingsTab(onBack: { route = .root })
        }
    }
}

#Preview {
    SystemSettingsTab()
        .frame(width: 900, height: 620)
}
