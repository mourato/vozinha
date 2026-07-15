import MeetingAssistantCoreCommon
import SwiftUI

public enum SystemSettingsRoute: Hashable, Sendable {
    case root
    case models
    case dictionary
    case sound
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
            )
        case .models:
            ModelsSettingsTab(onBack: { route = .root })
        case .dictionary:
            VocabularySettingsTab(onBack: { route = .root })
        case .sound:
            AudioSettingsTab(onBack: { route = .root })
        }
    }
}

#Preview {
    SystemSettingsTab()
        .frame(width: 900, height: 620)
}
