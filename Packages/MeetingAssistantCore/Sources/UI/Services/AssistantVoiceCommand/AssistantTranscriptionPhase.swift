import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

@MainActor
protocol AssistantCommandTranscribing: AnyObject {
    func transcribe(
        audioURL: URL,
        onProgress: (@Sendable (Double) -> Void)?,
        executionMode: TranscriptionExecutionMode,
        diarizationEnabledOverride: Bool?
    ) async throws -> TranscriptionResponse
}

extension TranscriptionClient: AssistantCommandTranscribing {}

public struct AssistantTranscriptionPhase: @unchecked Sendable {
    private let transcriptionClient: any AssistantCommandTranscribing

    public init(transcriptionClient: TranscriptionClient) {
        self.transcriptionClient = transcriptionClient
    }

    init(transcriptionClient: any AssistantCommandTranscribing) {
        self.transcriptionClient = transcriptionClient
    }

    public func performTranscription(
        recordingURL: URL,
        vocabularyReplacementRules: [VocabularyReplacementRule],
        executionFlow: AssistantExecutionFlow,
        isAssistantIntegrationsEnabled: Bool,
        assistantSelectedIntegration: AssistantIntegrationConfig?
    ) async throws -> (
        command: String,
        executionFlow: AssistantExecutionFlow,
        selectedIntegration: AssistantIntegrationConfig?
    ) {
        let transcription = try await transcriptionClient.transcribe(
            audioURL: recordingURL,
            onProgress: nil,
            executionMode: .assistant,
            diarizationEnabledOverride: false
        )
        let command = normalizedAssistantTranscription(
            transcription.text,
            vocabularyReplacementRules: vocabularyReplacementRules
        )

        logPayloadIfNeeded("Assistant transcription payload", [
            "rawLength": transcription.text.count,
            "trimmedLength": command.count,
            "preview": AssistantPayloadLogging.payloadPreview(command),
        ])

        guard !command.isEmpty else {
            throw AssistantVoiceCommandError.emptyCommand
        }

        let selectedIntegration = resolveSelectedIntegration(
            executionFlow: executionFlow,
            isAssistantIntegrationsEnabled: isAssistantIntegrationsEnabled,
            assistantSelectedIntegration: assistantSelectedIntegration
        )

        AppLogger.info(
            "Assistant command processed",
            category: .assistant,
            extra: [
                "integration": selectedIntegration?.name ?? "assistantMode",
                "executionFlow": executionFlow == .integrationDispatch ? "integrationDispatch" : "assistantMode",
                "commandLength": command.count,
            ]
        )

        return (command, executionFlow, selectedIntegration)
    }

    public func normalizedAssistantTranscription(
        _ text: String,
        vocabularyReplacementRules: [VocabularyReplacementRule]
    ) -> String {
        VocabularyReplacementRule
            .apply(rules: vocabularyReplacementRules, to: text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func resolveSelectedIntegration(
        executionFlow: AssistantExecutionFlow,
        isAssistantIntegrationsEnabled: Bool,
        assistantSelectedIntegration: AssistantIntegrationConfig?
    ) -> AssistantIntegrationConfig? {
        guard executionFlow == .integrationDispatch,
              isAssistantIntegrationsEnabled,
              let integration = assistantSelectedIntegration,
              integration.isEnabled
        else {
            return nil
        }
        return integration
    }

    private func logPayloadIfNeeded(_ message: String, _ extras: [String: Any]) {
        guard AssistantPayloadLogging.shouldLogPayloadDetails else { return }
        AppLogger.debug(message, category: .assistant, extra: extras)
    }
}
