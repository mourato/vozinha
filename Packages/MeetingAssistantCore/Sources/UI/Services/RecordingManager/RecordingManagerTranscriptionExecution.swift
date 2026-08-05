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

        let executionMode: TranscriptionExecutionMode = capturePurpose.transcriptionExecutionMode
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
        inputLanguageCode: String? = nil,
        vocabularyHints: VocabularyProviderHints? = nil,
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

        let executionMode: TranscriptionExecutionMode = capturePurpose.transcriptionExecutionMode
        let resolvedInputLanguage = inputLanguageCode
            ?? AppSettingsStore.shared.resolvedTranscriptionInputLanguageCode(for: executionMode)

        if let selectionOverride,
           let configuredClient = transcriptionClient as? any TranscriptionServiceConfigurationAware
        {
            return try await configuredClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                executionMode: executionMode,
                diarizationEnabledOverride: diarizationEnabledOverride,
                selection: selectionOverride,
                inputLanguageCode: resolvedInputLanguage,
                vocabularyHints: vocabularyHints,
            )
        }

        // Prefer configuration-aware path when vocabulary hints must reach remote backends.
        if let vocabularyHints, !vocabularyHints.isEmpty,
           let configuredClient = transcriptionClient as? any TranscriptionServiceConfigurationAware
        {
            let selection = AppSettingsStore.shared.resolvedTranscriptionSelection(for: executionMode)
            return try await configuredClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                executionMode: executionMode,
                diarizationEnabledOverride: diarizationEnabledOverride,
                selection: selection,
                inputLanguageCode: resolvedInputLanguage,
                vocabularyHints: vocabularyHints,
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
        let executionMode: TranscriptionExecutionMode = capturePurpose.transcriptionExecutionMode
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

    /// Builds a domain transcription configuration that always carries session vocabulary hints.
    func makeDomainTranscriptionConfiguration(
        from dictationConfiguration: DictationTranscriptionConfiguration?,
        vocabularyHints: VocabularyProviderHints,
        capturePurpose: CapturePurpose,
    ) -> DomainTranscriptionRequestConfiguration? {
        let executionMode: TranscriptionExecutionMode = capturePurpose.transcriptionExecutionMode
        let hints: VocabularyProviderHints? = vocabularyHints.isEmpty ? nil : vocabularyHints

        if let dictationConfiguration {
            return DomainTranscriptionRequestConfiguration(
                providerID: dictationConfiguration.selection.provider.rawValue,
                modelID: dictationConfiguration.selection.selectedModel,
                inputLanguageCode: dictationConfiguration.inputLanguageCode,
                vocabularyHints: hints,
            )
        }

        // Synthesize from resolved settings when hints must reach a remote provider.
        guard let hints, !hints.isEmpty else { return nil }
        let selection = AppSettingsStore.shared.resolvedTranscriptionSelection(for: executionMode)
        return DomainTranscriptionRequestConfiguration(
            providerID: selection.provider.rawValue,
            modelID: selection.selectedModel,
            inputLanguageCode: AppSettingsStore.shared.resolvedTranscriptionInputLanguageCode(for: executionMode),
            vocabularyHints: hints,
        )
    }
}
