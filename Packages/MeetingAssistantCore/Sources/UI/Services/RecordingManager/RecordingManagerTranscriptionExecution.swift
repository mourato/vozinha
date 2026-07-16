import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Transcription Execution

extension RecordingManager {
    func performHealthCheck(
        capturePurpose: CapturePurpose = .meeting,
        selectionOverride: TranscriptionProviderSelection? = nil,
        effectiveSelection: TranscriptionProviderSelection? = nil,
        sessionID: UUID? = nil,
    ) async throws {
        updateVisibleTranscriptionProgress(phase: .preparing, sessionID: sessionID)

        let executionMode: TranscriptionExecutionMode = capturePurpose == .dictation ? .dictation : .meeting
        let resolvedSelection = effectiveSelection
            ?? selectionOverride
            ?? AppSettingsStore.shared.resolvedTranscriptionSelection(for: executionMode)
        let shouldUseRemoteSelection = resolvedSelection.provider.usesRemoteInference

        if shouldUseRemoteSelection {
            transcriptionStatus.updateServiceState(.connected)
            return
        }

        let isHealthy = try await transcriptionClient.healthCheck()
        guard isHealthy else {
            throw TranscriptionError.serviceUnavailable
        }
    }

    func performTranscription(
        audioURL: URL,
        diarizationEnabledOverride: Bool? = nil,
        capturePurpose: CapturePurpose = .meeting,
        sessionID: UUID? = nil,
        selectionOverride: TranscriptionProviderSelection? = nil,
    ) async throws -> TranscriptionResponse {
        updateVisibleTranscriptionProgress(
            phase: .processing,
            percentage: Constants.processingProgress,
            sessionID: sessionID,
        )
        let onProgress: @Sendable (Double) -> Void = { [weak self] percentage in
            Task { @MainActor in
                self?.updateVisibleTranscriptionProgress(
                    phase: .processing,
                    percentage: percentage,
                    sessionID: sessionID,
                )
            }
        }

        if let selectionOverride,
           let configuredClient = transcriptionClient as? any TranscriptionServiceConfigurationAware
        {
            return try await configuredClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                executionMode: capturePurpose == .dictation ? .dictation : .meeting,
                diarizationEnabledOverride: diarizationEnabledOverride,
                selection: selectionOverride,
                inputLanguageCode: AppSettingsStore.shared.resolvedTranscriptionInputLanguageCode(
                    for: capturePurpose == .dictation ? .dictation : .meeting,
                ),
            )
        }

        if let diarizationAwareClient = transcriptionClient as? any TranscriptionServicePurposeDiarized {
            return try await diarizationAwareClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride,
                capturePurpose: capturePurpose,
            )
        }

        if let diarizationAwareClient = transcriptionClient as? any TranscriptionServiceDiarizationOverride {
            return try await diarizationAwareClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride,
            )
        }

        if let purposeAwareClient = transcriptionClient as? any TranscriptionServicePurposeAware {
            return try await purposeAwareClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                capturePurpose: capturePurpose,
            )
        }

        return try await transcriptionClient.transcribe(
            audioURL: audioURL,
            onProgress: onProgress,
        )
    }

    func resolvedTranscriptionPerformanceIdentity(
        capturePurpose: CapturePurpose,
        selectionOverride: TranscriptionProviderSelection? = nil,
    ) -> ModelPerformanceModelIdentity {
        let executionMode: TranscriptionExecutionMode = capturePurpose == .dictation ? .dictation : .meeting
        let selection = selectionOverride ?? AppSettingsStore.shared.resolvedTranscriptionSelection(for: executionMode)
        return selection.provider.modelPerformanceIdentity(modelID: selection.selectedModel)
    }

    func shouldEnableDiarization(
        for meeting: Meeting,
        capturePurposeOverride: CapturePurpose? = nil,
    ) -> Bool {
        if meeting.app == .importedFile {
            return (capturePurposeOverride ?? meeting.capturePurpose) == .meeting
        }

        if let capturePurposeOverride {
            return capturePurposeOverride == .meeting
        }

        return meeting.supportsMeetingConversation
    }
}
