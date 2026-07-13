import MeetingAssistantCoreCommon
import SwiftUI

public enum SystemSettingsRoute: Hashable, Sendable {
    case root
    case models
    case dictionary
    case sound
    case permissions
    case protectedApps
}

public struct SystemSettingsTab: View {
    @Binding private var route: SystemSettingsRoute

    public init(route: Binding<SystemSettingsRoute> = .constant(.root)) {
        _route = route
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
                openDictionary: { route = .dictionary },
                openSound: { route = .sound },
                openProtectedApps: { route = .protectedApps },
                openPermissions: { route = .permissions },
            )
        case .models:
            ModelsSettingsTab()
        case .dictionary:
            VocabularySettingsTab()
        case .sound:
            AudioSettingsTab()
        case .permissions:
            PermissionsSettingsTab()
        case .protectedApps:
            EnhancementsSettingsTab(content: .protectedApps)
        }
    }
}

#Preview {
    SystemSettingsTab()
        .frame(width: 900, height: 620)
}
