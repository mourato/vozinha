import MeetingAssistantCoreCommon
import SwiftUI

public enum IntelligenceSettingsRoute: Hashable {
    case models
    case textContext
    case dictionary
}

public struct IntelligenceSettingsTab: View {
    @Binding private var route: IntelligenceSettingsRoute
    @Binding private var textContextNavigationState: SettingsSubpageNavigationState<EnhancementsSettingsRoute>

    public init(
        route: Binding<IntelligenceSettingsRoute> = .constant(.models),
        textContextNavigationState: Binding<SettingsSubpageNavigationState<EnhancementsSettingsRoute>> = .constant(SettingsSubpageNavigationState())
    ) {
        _route = route
        _textContextNavigationState = textContextNavigationState
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("settings.section.intelligence".localized)
                    .font(.headline.weight(.semibold))
                Text("settings.intelligence.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Picker("", selection: $route) {
                Text("settings.section.models".localized)
                    .tag(IntelligenceSettingsRoute.models)
                Text("settings.section.ai".localized)
                    .tag(IntelligenceSettingsRoute.textContext)
                Text("settings.section.vocabulary".localized)
                    .tag(IntelligenceSettingsRoute.dictionary)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 360)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @MainActor
    @ViewBuilder
    private var content: some View {
        switch route {
        case .models:
            ModelsSettingsTab(showsHeader: false)
        case .textContext:
            EnhancementsSettingsTab(
                navigationState: $textContextNavigationState,
                showsHeader: false
            )
        case .dictionary:
            VocabularySettingsTab(showsHeader: false)
        }
    }
}

#Preview {
    IntelligenceSettingsTab()
        .frame(width: 900, height: 620)
}
