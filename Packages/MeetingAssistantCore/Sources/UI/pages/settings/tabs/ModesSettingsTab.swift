import MeetingAssistantCoreAI
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct ModesSettingsTab: View {
    @StateObject private var viewModel: DictationStylesSettingsViewModel
    @StateObject private var aiSettingsViewModel: AISettingsViewModel
    @State private var navigationState = SettingsSubpageNavigationState<DictationStyleRoute>()

    public init(settings: AppSettingsStore = .shared) {
        _viewModel = StateObject(wrappedValue: DictationStylesSettingsViewModel(settings: settings))
        _aiSettingsViewModel = StateObject(wrappedValue: AISettingsViewModel(settings: settings))
    }

    public var body: some View {
        switch navigationState.currentRoute {
        case nil:
            stylesListPage
        case let .some(route):
            editorPage(for: route)
        }
    }

    @ViewBuilder
    private func editorPage(for route: DictationStyleRoute) -> some View {
        if case let .editor(styleID) = route {
            if let draft = viewModel.editorDraft {
                DictationStyleEditorDetailView(
                    draft: draft,
                    appCatalog: viewModel.appCatalog,
                    isLoadingAppCatalog: viewModel.isLoadingAppCatalog,
                    onEnsureAppCatalogLoaded: viewModel.ensureAppCatalogLoaded,
                    onFindConflictingStyleName: { target, excludeID in
                        viewModel.styleNameConflicting(with: target, excluding: excludeID)
                    },
                    modelOptions: aiSettingsViewModel.enhancementsProviderModels,
                    isLoadingModelOptions: aiSettingsViewModel.isLoadingEnhancementsProviderModels,
                    onRefreshModelOptions: {
                        _ = aiSettingsViewModel.refreshEnhancementsProviderModelsManually()
                    },
                    providerDisplayName: viewModel.enhancementsProviderDisplayName(for:),
                    onSave: { draft in
                        viewModel.saveStyle(draft)
                        navigateToRoot()
                    },
                    onCancel: {
                        viewModel.clearEditor()
                        navigateToRoot()
                    },
                    onDelete: styleID != nil ? {
                        if let styleID {
                            viewModel.deleteStyle(id: styleID)
                        }
                        viewModel.clearEditor()
                        navigateToRoot()
                    } : nil,
                )
            } else {
                stylesListPage
            }
        }
    }

    private var stylesListPage: some View {
        StylesSettingsTab(
            viewModel: viewModel,
            aiSettingsViewModel: aiSettingsViewModel,
            embedded: true,
            onOpenEditor: { styleID in
                viewModel.prepareEditor(for: styleID)
                navigationState.open(.editor(styleID: styleID))
            },
        )
    }

    private func navigateToRoot() {
        _ = navigationState.goBack()
    }
}

#Preview {
    ModesSettingsTab()
}
