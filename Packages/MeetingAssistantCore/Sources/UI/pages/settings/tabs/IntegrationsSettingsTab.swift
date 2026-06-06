import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import SwiftUI

public struct IntegrationsSettingsTab: View {
    private enum CapabilityLayout {
        static let disabledOpacity = 0.58
    }

    @StateObject private var viewModel = IntegrationSettingsViewModel()
    @StateObject private var settings = AppSettingsStore.shared
    @State private var editingIntegration: AssistantIntegrationConfig?
    @State private var advancedIntegrationDraft: AssistantIntegrationConfig?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        SettingsScrollableContent {
            SettingsSectionHeader(
                title: "settings.section.integrations".localized,
                description: "settings.integrations.header_desc".localized
            )

            integrationsSection
                .disabled(!settings.isAssistantIntegrationsEnabled)
                .opacity(settings.isAssistantIntegrationsEnabled ? 1 : CapabilityLayout.disabledOpacity)
                .animation(
                    SettingsMotion.sectionAnimation(reduceMotion: reduceMotion),
                    value: settings.isAssistantIntegrationsEnabled
                )
        }
        .sheet(item: $editingIntegration) { integration in
            AssistantIntegrationEditorSheet(
                integration: integration,
                onApplyAndClose: { draft in
                    if let conflictMessage = viewModel.saveIntegrationWithModifierValidation(draft.integration) {
                        return conflictMessage
                    }
                    editingIntegration = nil
                    return nil
                },
                onDelete: { id in
                    viewModel.removeIntegration(id: id)
                    editingIntegration = nil
                },
                onOpenAdvanced: { draft in
                    advancedIntegrationDraft = draft.integration
                    editingIntegration = nil
                }
            )
        }
        .sheet(item: $advancedIntegrationDraft) { integration in
            AssistantIntegrationBashScriptSheet(
                scriptConfig: integration.advancedScript,
                scriptTestOutput: viewModel.scriptTestOutput,
                scriptTestErrorMessage: viewModel.scriptTestErrorMessage,
                onSave: { scriptConfig in
                    var updated = integration
                    updated.advancedScript = scriptConfig
                    viewModel.saveIntegration(updated)
                    advancedIntegrationDraft = nil
                    viewModel.clearScriptTestResult()
                },
                onTest: { script, input in
                    await viewModel.testScript(script: script, input: input)
                },
                onClose: {
                    advancedIntegrationDraft = nil
                    viewModel.clearScriptTestResult()
                }
            )
        }
    }

    private var integrationsSection: some View {
        AssistantIntegrationsSection(
            viewModel: viewModel,
            showsCapabilityToggle: false,
            editingIntegration: $editingIntegration
        )
    }

}

#Preview {
    IntegrationsSettingsTab()
}
