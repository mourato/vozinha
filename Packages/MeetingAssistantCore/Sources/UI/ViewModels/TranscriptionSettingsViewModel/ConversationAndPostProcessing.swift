// swiftlint:disable file_length

import AppKit
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import OSLog
import SwiftUI

public extension TranscriptionSettingsViewModel {
    enum ManualTranscriptionExportKind: Sendable {
        case summary
        case original

        var filenameSuffixKey: String? {
            switch self {
            case .summary:
                nil
            case .original:
                "transcription.export.filename.original_suffix"
            }
        }

        var emptyContentErrorKey: String {
            switch self {
            case .summary:
                "transcription.export.error.empty_summary"
            case .original:
                "transcription.export.error.empty_original"
            }
        }
    }

    static func manualExportSuggestedFilename(
        baseFilename: String,
        kind: ManualTranscriptionExportKind,
    ) -> String {
        guard let suffixKey = kind.filenameSuffixKey else {
            return "\(baseFilename).md"
        }

        return "\(baseFilename) \(suffixKey.localized).md"
    }

    func submitQuestion(for transcription: Transcription) async {
        let trimmedQuestion = qaQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            qaErrorMessage = "transcription.qa.error.empty_question".localized
            return
        }

        await askQuestion(trimmedQuestion, for: transcription)
    }

    func retryQuestion(_ question: String, turnID: UUID, for transcription: Transcription) async {
        await retryQuestion(question, turnID: Optional(turnID), for: transcription)
    }

    private func retryQuestion(_ question: String, turnID: UUID?, for transcription: Transcription) async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            qaErrorMessage = "transcription.qa.error.empty_question".localized
            return
        }

        qaQuestion = trimmedQuestion
        await askQuestion(trimmedQuestion, for: transcription, retryTurnID: turnID)
    }

    private func askQuestion(
        _ question: String,
        for transcription: Transcription,
        retryTurnID: UUID? = nil,
    ) async {
        guard transcription.supportsMeetingConversation else {
            qaErrorMessage = localizedQuestionError(for: .disabled, transcriptionID: transcription.id)
            return
        }

        guard !isAnsweringQuestion else { return }

        isAnsweringQuestion = true
        qaErrorMessage = nil
        defer { isAnsweringQuestion = false }

        do {
            let request = IntelligenceKernelQuestionRequest(
                mode: .meeting,
                question: question,
                transcription: transcription,
                modelSelectionOverride: qaModelSelectionByTranscription[transcription.id],
            )
            let response = try await meetingQAService.ask(request)
            qaResponse = response
            upsertQATurn(
                QATurn(
                    id: retryTurnID ?? UUID(),
                    question: question,
                    response: response,
                    errorMessage: nil,
                    createdAt: turnCreationDate(for: retryTurnID, transcriptionID: transcription.id),
                ),
                transcriptionID: transcription.id,
                replacingTurnID: retryTurnID,
            )
            await persistMeetingConversationState(for: transcription.id)
        } catch {
            let message = (error as? MeetingQAError).map {
                localizedQuestionError(for: $0, transcriptionID: transcription.id)
            } ?? "transcription.qa.error.generic".localized
            qaErrorMessage = message
            upsertQATurn(
                QATurn(
                    id: retryTurnID ?? UUID(),
                    question: question,
                    response: nil,
                    errorMessage: message,
                    createdAt: turnCreationDate(for: retryTurnID, transcriptionID: transcription.id),
                ),
                transcriptionID: transcription.id,
                replacingTurnID: retryTurnID,
            )
            await persistMeetingConversationState(for: transcription.id)
        }
    }

    private func localizedQuestionError(for error: MeetingQAError, transcriptionID: UUID? = nil) -> String {
        switch error {
        case .disabled:
            "transcription.qa.error.disabled".localized
        case .emptyQuestion:
            "transcription.qa.error.empty_question".localized
        case .noAPIConfigured:
            "transcription.qa.error.no_api".localized
        case .invalidURL:
            "transcription.qa.error.invalid_url".localized
        case .timeout:
            "transcription.qa.error.timeout".localized
        case .networkUnavailable:
            "transcription.qa.error.network".localized
        case .invalidResponse:
            invalidResponseQuestionError(transcriptionID: transcriptionID)
        case .requestFailed:
            "transcription.qa.error.generic".localized
        }
    }

    func resetQuestionState() {
        qaQuestion = ""
        qaResponse = nil
        qaErrorMessage = nil
    }

    func clearQuestionComposer() {
        qaQuestion = ""
        qaErrorMessage = nil
    }

    private func upsertQATurn(
        _ turn: QATurn,
        transcriptionID: UUID,
        replacingTurnID: UUID?,
    ) {
        var turns = qaHistoryByTranscription[transcriptionID] ?? []
        if let replacingTurnID,
           let existingIndex = turns.firstIndex(where: { $0.id == replacingTurnID })
        {
            turns[existingIndex] = turn
        } else {
            turns.append(turn)
        }
        qaHistoryByTranscription[transcriptionID] = turns
    }

    private func turnCreationDate(for turnID: UUID?, transcriptionID: UUID) -> Date {
        guard let turnID,
              let existingTurn = qaHistoryByTranscription[transcriptionID]?.first(where: { $0.id == turnID })
        else {
            return Date()
        }
        return existingTurn.createdAt
    }

    private func invalidResponseQuestionError(transcriptionID: UUID?) -> String {
        guard let transcriptionID else {
            return "transcription.qa.error.invalid_response".localized
        }

        let selection = effectiveMeetingQAModelSelection(for: transcriptionID)
        let providerName = AIProvider(rawValue: selection.providerRawValue)?.displayName ?? selection.providerRawValue
        let modelName = selection.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModelName = modelName.isEmpty
            ? "transcription.qa.error.invalid_response.unknown_model".localized
            : modelName

        return "transcription.qa.error.invalid_response.detailed".localized(with: providerName, resolvedModelName)
    }

    func isPostProcessing(transcriptionID: UUID) -> Bool {
        postProcessingByTranscriptionID.contains(transcriptionID)
    }

    func postProcessingError(for transcriptionID: UUID) -> String? {
        postProcessingErrorByTranscriptionID[transcriptionID]
    }

    var availablePrompts: [PostProcessingPrompt] {
        settings.allPrompts
    }

    func availablePrompts(for metadata: TranscriptionMetadata) -> [PostProcessingPrompt] {
        if !metadata.supportsMeetingConversation {
            return settings.dictationAvailablePrompts
        }
        return settings.meetingAvailablePrompts
    }

    func availableRetryTranscriptionOptions(for metadata: TranscriptionMetadata) -> [RetryTranscriptionOption] {
        RetryTranscriptionSelectionMatrix.eligibleSelections(
            for: metadata.capturePurpose,
            transcriptionAPIKeyExists: { [keychain] provider in
                keychain.existsTranscriptionAPIKey(for: provider)
            },
            isLocalModelReady: isLocalModelReady,
        )
        .map(RetryTranscriptionOption.init)
    }

    func applyPostProcessing(prompt: PostProcessingPrompt, transcriptionID: UUID) async {
        do {
            if let selected = selectedTranscription, selected.id == transcriptionID {
                await applyPostProcessing(prompt: prompt, to: selected)
                return
            }

            guard let loaded = try await storage.loadTranscription(by: transcriptionID) else {
                operationErrorMessage = "transcription.post_processing.error".localized
                return
            }
            selectedTranscription = loaded
            selectedId = transcriptionID
            await applyPostProcessing(prompt: prompt, to: loaded)
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }

    // swiftlint:disable:next function_body_length
    func applyPostProcessing(prompt: PostProcessingPrompt, to transcription: Transcription) async {
        guard !isProcessingAI else { return }

        let transcriptionID = transcription.id
        markPostProcessingStarted(for: transcriptionID)
        let startTime = Date()
        let mode: IntelligenceKernelMode = transcription.capturePurpose.intelligenceKernelMode
        let postProcessingSelection = settings.enhancementsSelection(for: mode)
        let postProcessingIdentity = settings.resolvedEnhancementsPerformanceIdentity(for: mode)
        let useStructuredPipeline = mode == .meeting || settings.dictationStructuredPostProcessingEnabled
        let postProcessingConfiguration = settings.resolvedEnhancementsAIConfiguration(for: postProcessingSelection)
        let readinessIssue = settings.enhancementsInferenceReadinessIssue(for: postProcessingSelection, apiKeyExists: nil)
        let request = DomainPostProcessingRequest(
            prompt: DomainPostProcessingPrompt(id: prompt.id, title: prompt.title, content: prompt.promptText),
            mode: mode,
            selection: DomainPostProcessingSelection(
                providerID: postProcessingSelection.provider.rawValue,
                modelID: postProcessingSelection.selectedModel,
                registrationID: postProcessingSelection.registrationID,
            ),
            configuration: DomainPostProcessingConfiguration(
                providerID: postProcessingConfiguration.provider.rawValue,
                baseURL: postProcessingConfiguration.baseURL,
                modelID: postProcessingConfiguration.selectedModel,
                readinessIssue: readinessIssue?.rawValue,
                outputLanguageID: mode == .meeting ? settings.meetingSummaryOutputLanguage.rawValue : nil,
            ),
            useStructuredPipeline: useStructuredPipeline,
            systemPromptOverride: mode == .meeting ? settings.systemPrompt : nil,
        )
        let executionProvenance = makeReprocessProvenance(
            transcription: transcription,
            prompt: prompt,
            selection: postProcessingSelection,
            identity: postProcessingIdentity,
            mode: mode,
            useStructuredPipeline: useStructuredPipeline,
        )
        let postProcessingInput = postProcessingInput(for: transcription)
        defer { markPostProcessingFinished(for: transcriptionID) }

        do {
            let result = try await runPostProcessing(
                postProcessingInput: postProcessingInput,
                request: request,
            )
            let duration = Date().timeIntervalSince(startTime)
            let modelUsed = postProcessingSelection.selectedModel
            let updatedTranscription = makePostProcessedTranscription(
                from: transcription,
                prompt: prompt,
                processedText: result.processedText,
                canonicalSummary: result.canonicalSummary,
                outputState: result.outputState,
                duration: duration,
                modelUsed: modelUsed,
                executionProvenance: executionProvenance,
            )

            try await storage.saveTranscription(updatedTranscription)
            try? await storage.saveModelPerformanceAttempt(
                makeReprocessAttempt(
                    transcription: transcription,
                    identity: postProcessingIdentity,
                    status: .succeeded,
                    startedAt: startTime,
                    completedAt: Date(),
                    input: postProcessingInput,
                    outputCharacterCount: result.processedText.count,
                    failureReason: nil,
                    executionProvenance: executionProvenance,
                ),
            )

            selectedTranscription = updatedTranscription
            clearPostProcessingError(for: transcriptionID)
            await loadTranscriptions()
        } catch {
            await handlePostProcessingFailure(
                error: error,
                transcription: transcription,
                transcriptionID: transcriptionID,
                identity: postProcessingIdentity,
                startedAt: startTime,
                input: postProcessingInput,
                executionProvenance: executionProvenance,
            )
        }
    }

    private struct ReprocessPipelineResult {
        let processedText: String
        let canonicalSummary: CanonicalSummary?
        let outputState: DomainPostProcessingOutputState?
    }

    private func runPostProcessing(
        postProcessingInput: String,
        request: DomainPostProcessingRequest,
    ) async throws -> ReprocessPipelineResult {
        if request.useStructuredPipeline {
            let structuredResult = try await recordingManager.postProcessingRepository.processTranscriptionStructured(
                postProcessingInput,
                request: request,
            )
            return ReprocessPipelineResult(
                processedText: structuredResult.processedText,
                canonicalSummary: structuredResult.canonicalSummary,
                outputState: structuredResult.outputState,
            )
        }

        let processedText = try await recordingManager.postProcessingRepository.processTranscription(
            postProcessingInput,
            request: request,
        )
        return ReprocessPipelineResult(
            processedText: processedText,
            canonicalSummary: nil,
            outputState: nil,
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func makeReprocessAttempt(
        transcription: Transcription,
        identity: ModelPerformanceModelIdentity,
        status: ModelPerformanceAttemptStatus,
        startedAt: Date,
        completedAt: Date,
        input: String,
        outputCharacterCount: Int,
        failureReason: String?,
        executionProvenance: ExecutionProvenance,
    ) -> ModelPerformanceAttempt {
        ModelPerformanceAttempt(
            transcriptionID: transcription.id,
            stage: .postProcessing,
            attemptKind: .reprocess,
            capturePurpose: transcription.capturePurpose,
            modelIdentity: identity,
            status: status,
            startedAt: startedAt,
            completedAt: completedAt,
            wallClockSeconds: max(0, completedAt.timeIntervalSince(startedAt)),
            audioSeconds: 0,
            inputUTF8Bytes: input.lengthOfBytes(using: .utf8),
            inputCharacterCount: input.count,
            outputCharacterCount: outputCharacterCount,
            failureReason: failureReason,
            executionProvenance: executionProvenance,
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func handlePostProcessingFailure(
        error: Error,
        transcription: Transcription,
        transcriptionID: UUID,
        identity: ModelPerformanceModelIdentity,
        startedAt: Date,
        input: String,
        executionProvenance: ExecutionProvenance,
    ) async {
        let message: String
        if let processingError = error as? PostProcessingError {
            logger.error("Failed to apply post-processing: \(processingError.localizedDescription)")
            message = processingError.localizedDescription
        } else {
            logger.error("Failed to apply post-processing: \(error.localizedDescription)")
            message = "transcription.post_processing.error".localized
        }

        try? await storage.saveModelPerformanceAttempt(
            makeReprocessAttempt(
                transcription: transcription,
                identity: identity,
                status: .failed,
                startedAt: startedAt,
                completedAt: Date(),
                input: input,
                outputCharacterCount: 0,
                failureReason: message,
                executionProvenance: executionProvenance,
            ),
        )
        postProcessingErrorByTranscriptionID[transcriptionID] = message
        operationErrorMessage = message
    }

    // swiftlint:disable:next function_parameter_count
    private func makePostProcessedTranscription(
        from transcription: Transcription,
        prompt: PostProcessingPrompt,
        processedText: String,
        canonicalSummary: CanonicalSummary?,
        outputState: DomainPostProcessingOutputState?,
        duration: TimeInterval,
        modelUsed: String,
        executionProvenance: ExecutionProvenance,
    ) -> Transcription {
        Transcription(
            id: transcription.id,
            meeting: transcription.meeting,
            contextItems: transcription.contextItems,
            segments: sortedSegments(transcription.segments),
            text: processedText,
            rawText: transcription.rawText,
            processedContent: processedText,
            canonicalSummary: canonicalSummary,
            qualityProfile: transcription.qualityProfile,
            postProcessingPromptId: prompt.id,
            postProcessingPromptTitle: prompt.title,
            language: transcription.language,
            createdAt: transcription.createdAt,
            modelName: transcription.modelName,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcription.transcriptionDuration,
            postProcessingDuration: duration,
            postProcessingModel: modelUsed,
            meetingType: transcription.meetingType,
            meetingConversationState: transcription.meetingConversationState,
            postProcessingFailureReason: nil,
            postProcessingOutputState: outputState,
            transcriptionFailureReason: transcription.transcriptionFailureReason,
            executionProvenance: executionProvenance,
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func makeReprocessProvenance(
        transcription: Transcription,
        prompt: PostProcessingPrompt,
        selection: EnhancementsAISelection,
        identity: ModelPerformanceModelIdentity,
        mode: IntelligenceKernelMode,
        useStructuredPipeline: Bool,
    ) -> ExecutionProvenance {
        ExecutionProvenance(
            transcriptionRequest: transcription.executionProvenance?.transcriptionRequest,
            vocabularySnapshot: transcription.executionProvenance?.vocabularySnapshot ?? .empty,
            transcriptionModelIdentity: transcription.executionProvenance?.transcriptionModelIdentity
                ?? ModelPerformanceModelIdentity(
                    providerID: "unknown",
                    providerDisplayName: "Unknown",
                    modelID: "unknown",
                    modelDisplayName: "Unknown",
                    runtimeKind: .unknown,
                ),
            postProcessingSelection: DomainPostProcessingSelection(
                providerID: selection.provider.rawValue,
                modelID: selection.selectedModel,
                registrationID: selection.registrationID,
            ),
            postProcessingModelIdentity: identity,
            postProcessingPromptID: prompt.id,
            postProcessingPromptTitle: prompt.title,
            kernelMode: mode,
            usedStructuredPostProcessing: useStructuredPipeline,
        )
    }

    func renameSpeaker(
        from originalSpeaker: String,
        to updatedSpeaker: String,
        in transcriptionID: UUID,
    ) async {
        let oldValue = originalSpeaker.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = updatedSpeaker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldValue.isEmpty, !newValue.isEmpty, oldValue != newValue else { return }

        do {
            guard var transcription = selectedTranscription, transcription.id == transcriptionID else {
                guard var loaded = try await storage.loadTranscription(by: transcriptionID) else { return }
                try await renameSpeaker(in: &loaded, from: oldValue, to: newValue, selectedID: transcriptionID)
                return
            }

            try await renameSpeaker(in: &transcription, from: oldValue, to: newValue, selectedID: transcriptionID)
        } catch {
            logger.error("Failed to rename speaker: \(error.localizedDescription)")
            operationErrorMessage = "transcription.speaker.rename.error".localized
        }
    }

    func meetingNotesContent(for transcription: Transcription?) -> MeetingNotesContent {
        guard let transcription else {
            return .empty
        }

        if transcription.supportsMeetingConversation {
            let sharedContent = recordingManager.loadSharedMeetingNotesContent(for: transcription.meeting)
            if hasPersistedMeetingNotesContent(sharedContent) {
                return sharedContent
            }
        }

        let fallbackLegacyContent = MeetingNotesContent(
            plainText: transcription.contextItems.first(where: { $0.source == .meetingNotes })?.text ?? "",
            richTextRTFData: meetingNotesRichTextStore.transcriptionNotesRTFData(for: transcription.id),
        )
        return meetingNotesMarkdownStore.loadTranscriptionNotesContent(
            for: transcription.id,
            legacyContent: fallbackLegacyContent,
        )
    }

    func updateMeetingNotes(_ content: MeetingNotesContent, in transcriptionID: UUID) async {
        do {
            guard var transcription = selectedTranscription, transcription.id == transcriptionID else {
                guard var loaded = try await storage.loadTranscription(by: transcriptionID) else { return }
                try await updateMeetingNotes(in: &loaded, content: content, selectedID: transcriptionID)
                return
            }

            try await updateMeetingNotes(in: &transcription, content: content, selectedID: transcriptionID)
        } catch {
            logger.error("Failed to update meeting notes: \(error.localizedDescription)")
            operationErrorMessage = "transcription.meeting_notes.error".localized
        }
    }

    func updateMeetingNotes(_ notes: String, in transcriptionID: UUID) async {
        await updateMeetingNotes(MeetingNotesContent(plainText: notes), in: transcriptionID)
    }

    func confirmDeleteTranscription(_ metadata: TranscriptionMetadata) {
        pendingDeleteTranscription = metadata
        showDeleteConfirmation = true
    }

    func cancelDeleteTranscription() {
        pendingDeleteTranscription = nil
        showDeleteConfirmation = false
    }

    func executeDeleteTranscription() async {
        guard let metadata = pendingDeleteTranscription else { return }
        await doDeleteTranscription(metadata)
        cancelDeleteTranscription()
    }

    private func doDeleteTranscription(_ metadata: TranscriptionMetadata) async {
        do {
            try await storage.deleteTranscription(by: metadata.id)
            meetingNotesRichTextStore.saveTranscriptionNotesRTFData(nil, for: metadata.id)
            meetingNotesMarkdownStore.deleteTranscriptionNotesContent(for: metadata.id)
            if selectedId == metadata.id {
                selectedId = nil
            }
            await loadTranscriptions()
        } catch {
            logger.error("Failed to delete transcription: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func exportTranscription(
        for metadata: TranscriptionMetadata,
        kind: ManualTranscriptionExportKind,
    ) async {
        operationErrorMessage = nil
        do {
            guard let transcription = try await transcriptionForAction(metadata) else {
                operationErrorMessage = "transcription.export.error.missing_transcription".localized
                return
            }

            let exportContent = contentForManualExport(transcription: transcription, kind: kind)
            guard !exportContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                operationErrorMessage = kind.emptyContentErrorKey.localized
                return
            }

            let panel = savePanelProvider()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = suggestedExportFilename(for: transcription, kind: kind)

            let response = panel.runModal()
            guard response == .OK, let destinationURL = panel.url else {
                return
            }

            try summaryExportHelper.exportContentManually(exportContent, to: destinationURL)
        } catch {
            logger.error("Failed to manually export transcription: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func retryTranscription(
        for metadata: TranscriptionMetadata,
        selectionOverride: TranscriptionProviderSelection,
    ) async {
        guard !recordingManager.isTranscribing else {
            return
        }

        do {
            guard let transcription = try await transcriptionForAction(metadata) else {
                operationErrorMessage = "transcription.retry.missing_transcription".localized
                return
            }

            guard let audioURL = transcription.audioURL else {
                operationErrorMessage = "transcription.retry.missing_audio".localized
                return
            }

            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                operationErrorMessage = "transcription.retry.missing_audio".localized
                return
            }

            await recordingManager.retryTranscription(for: transcription, selectionOverride: selectionOverride)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to retry transcription: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func updateMeetingTitle(for metadata: TranscriptionMetadata, to title: String?) async {
        guard metadata.supportsMeetingConversation else { return }

        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle : nil

        do {
            let existing = try await meetingRepository.fetchMeeting(by: metadata.meetingId)
            let updatedMeeting = makeUpdatedMeetingEntity(
                existing: existing,
                metadata: metadata,
                app: existing?.app ?? (DomainMeetingApp(rawValue: metadata.appRawValue) ?? .unknown),
                capturePurpose: existing?.capturePurpose ?? metadata.capturePurpose,
                title: normalizedTitle,
            )

            try await meetingRepository.updateMeeting(updatedMeeting)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to update meeting title: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    func updateSource(for metadata: TranscriptionMetadata, isMeeting: Bool) async {
        await updateCapturePurpose(for: metadata, to: isMeeting ? .meeting : .dictation)
    }

    func updateCapturePurpose(for metadata: TranscriptionMetadata, to capturePurpose: CapturePurpose) async {
        let metadataApp = DomainMeetingApp(rawValue: metadata.appRawValue) ?? .unknown

        do {
            let existing = try await meetingRepository.fetchMeeting(by: metadata.meetingId)
            let existingApp = existing?.app ?? metadataApp
            let endTime = metadata.duration > 0
                ? metadata.startTime.addingTimeInterval(metadata.duration)
                : nil
            let targetApp = adjustedApp(existingApp, for: capturePurpose)

            let updatedMeeting = makeUpdatedMeetingEntity(
                existing: existing,
                metadata: metadata,
                app: targetApp,
                capturePurpose: capturePurpose,
                title: capturePurpose == .meeting ? existing?.title ?? metadata.meetingTitle : nil,
                fallbackEndTime: endTime,
            )

            try await meetingRepository.updateMeeting(updatedMeeting)
            await loadTranscriptions()
            if selectedId == metadata.id {
                await loadFullTranscription(id: metadata.id)
            }
        } catch {
            logger.error("Failed to update capture purpose: \(error.localizedDescription)")
            operationErrorMessage = error.localizedDescription
        }
    }

    private func transcriptionForAction(_ metadata: TranscriptionMetadata) async throws -> Transcription? {
        if selectedId == metadata.id, let current = selectedTranscription {
            return current
        }

        return try await storage.loadTranscription(by: metadata.id)
    }

    private func contentForManualExport(
        transcription: Transcription,
        kind: ManualTranscriptionExportKind,
    ) -> String {
        switch kind {
        case .summary:
            TranscriptionDisplayText.preferredSummary(
                processedContent: transcription.processedContent,
                canonicalSummary: transcription.canonicalSummary,
                text: transcription.text,
                emptyFallback: "",
            )
        case .original:
            transcription.rawText
        }
    }

    private func suggestedExportFilename(
        for transcription: Transcription,
        kind: ManualTranscriptionExportKind,
    ) -> String {
        let baseFilename = summaryExportHelper.defaultExportFilename(for: transcription)
        return Self.manualExportSuggestedFilename(baseFilename: baseFilename, kind: kind)
    }

    private func makeUpdatedMeetingEntity(
        existing: MeetingEntity?,
        metadata: TranscriptionMetadata,
        app: DomainMeetingApp,
        capturePurpose: CapturePurpose,
        title: String?,
        fallbackEndTime: Date? = nil,
    ) -> MeetingEntity {
        MeetingEntity(
            id: metadata.meetingId,
            app: app,
            capturePurpose: capturePurpose,
            appBundleIdentifier: existing?.appBundleIdentifier ?? metadata.appBundleIdentifier,
            appDisplayName: existing?.appDisplayName ?? metadata.appName,
            title: title,
            linkedCalendarEvent: existing?.linkedCalendarEvent,
            startTime: existing?.startTime ?? metadata.startTime,
            endTime: existing?.endTime ?? fallbackEndTime,
            audioFilePath: existing?.audioFilePath ?? metadata.audioFilePath,
        )
    }

    private func adjustedApp(_ app: DomainMeetingApp, for capturePurpose: CapturePurpose) -> DomainMeetingApp {
        switch (capturePurpose, app) {
        case (.meeting, .unknown):
            .manualMeeting
        case (.dictation, .manualMeeting):
            .unknown
        default:
            app
        }
    }

    private func renameSpeaker(
        in transcription: inout Transcription,
        from oldValue: String,
        to newValue: String,
        selectedID: UUID,
    ) async throws {
        let renamedSegments = transcription.segments.map { segment in
            guard segment.speaker == oldValue else { return segment }
            return Transcription.Segment(
                id: segment.id,
                speaker: newValue,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
            )
        }

        guard renamedSegments != transcription.segments else { return }
        let sortedRenamedSegments = sortedSegments(renamedSegments)
        let updatedTranscription = Transcription(
            id: transcription.id,
            meeting: transcription.meeting,
            contextItems: transcription.contextItems,
            segments: sortedRenamedSegments,
            text: transcription.text,
            rawText: transcription.rawText,
            processedContent: transcription.processedContent,
            canonicalSummary: transcription.canonicalSummary,
            qualityProfile: transcription.qualityProfile,
            postProcessingPromptId: transcription.postProcessingPromptId,
            postProcessingPromptTitle: transcription.postProcessingPromptTitle,
            language: transcription.language,
            createdAt: transcription.createdAt,
            modelName: transcription.modelName,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcription.transcriptionDuration,
            postProcessingDuration: transcription.postProcessingDuration,
            postProcessingModel: transcription.postProcessingModel,
            meetingType: transcription.meetingType,
            meetingConversationState: transcription.meetingConversationState,
        )

        try await storage.saveTranscription(updatedTranscription)
        if selectedId == selectedID || selectedTranscription?.id == selectedID {
            selectedTranscription = updatedTranscription
        }
    }

    private func updateMeetingNotes(
        in transcription: inout Transcription,
        content: MeetingNotesContent,
        selectedID: UUID,
    ) async throws {
        let notes = content.plainText
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextWithoutMeetingNotes = transcription.contextItems.filter { $0.source != .meetingNotes }
        let updatedContextItems = if trimmedNotes.isEmpty {
            contextWithoutMeetingNotes
        } else {
            contextWithoutMeetingNotes + [TranscriptionContextItem(source: .meetingNotes, text: notes)]
        }
        let currentTranscriptionRichTextData = meetingNotesRichTextStore.transcriptionNotesRTFData(for: transcription.id)
        let isSameTranscriptionRichText = currentTranscriptionRichTextData == content.richTextRTFData
        let isSameSharedContent = if transcription.supportsMeetingConversation {
            recordingManager.loadSharedMeetingNotesContent(for: transcription.meeting) == content
        } else {
            true
        }

        guard updatedContextItems != transcription.contextItems
            || !isSameTranscriptionRichText
            || !isSameSharedContent
        else { return }

        if updatedContextItems == transcription.contextItems {
            persistMeetingNotesSideEffects(content, trimmedNotes: trimmedNotes, for: transcription)
            return
        }

        let updatedTranscription = Transcription(
            id: transcription.id,
            meeting: transcription.meeting,
            contextItems: updatedContextItems,
            segments: transcription.segments,
            text: transcription.text,
            rawText: transcription.rawText,
            processedContent: transcription.processedContent,
            canonicalSummary: transcription.canonicalSummary,
            qualityProfile: transcription.qualityProfile,
            postProcessingPromptId: transcription.postProcessingPromptId,
            postProcessingPromptTitle: transcription.postProcessingPromptTitle,
            language: transcription.language,
            createdAt: transcription.createdAt,
            modelName: transcription.modelName,
            inputSource: transcription.inputSource,
            transcriptionDuration: transcription.transcriptionDuration,
            postProcessingDuration: transcription.postProcessingDuration,
            postProcessingModel: transcription.postProcessingModel,
            meetingType: transcription.meetingType,
            meetingConversationState: transcription.meetingConversationState,
        )

        try await storage.saveTranscription(updatedTranscription)
        persistMeetingNotesSideEffects(content, trimmedNotes: trimmedNotes, for: transcription)

        if selectedId == selectedID || selectedTranscription?.id == selectedID {
            selectedTranscription = updatedTranscription
        }
    }

    private func persistMeetingNotesSideEffects(
        _ content: MeetingNotesContent,
        trimmedNotes: String,
        for transcription: Transcription,
    ) {
        if transcription.supportsMeetingConversation {
            recordingManager.saveSharedMeetingNotesContent(content, for: transcription.meeting)
        }

        if trimmedNotes.isEmpty {
            meetingNotesRichTextStore.saveTranscriptionNotesRTFData(nil, for: transcription.id)
            meetingNotesMarkdownStore.deleteTranscriptionNotesContent(for: transcription.id)
        } else {
            meetingNotesRichTextStore.saveTranscriptionNotesRTFData(content.richTextRTFData, for: transcription.id)
            meetingNotesMarkdownStore.saveTranscriptionNotesContent(content, for: transcription.id)
        }
    }

    private func hasPersistedMeetingNotesContent(_ content: MeetingNotesContent) -> Bool {
        !content.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (content.richTextRTFData?.isEmpty == false)
    }

    private func sortedSegments(_ segments: [Transcription.Segment]) -> [Transcription.Segment] {
        segments.sorted(by: Self.segmentSortComparator)
    }

    private func postProcessingInput(for transcription: Transcription) -> String {
        let segments = sortedSegments(transcription.segments)
        guard !segments.isEmpty else {
            return transcription.rawText
        }

        return segments
            .map { segment in
                "[\(segment.startTime)-\(segment.endTime)] \(segment.speaker): \(segment.text)"
            }
            .joined(separator: "\n")
    }

    private func markPostProcessingStarted(for transcriptionID: UUID) {
        postProcessingByTranscriptionID.insert(transcriptionID)
        isProcessingAI = !postProcessingByTranscriptionID.isEmpty
    }

    private func markPostProcessingFinished(for transcriptionID: UUID) {
        postProcessingByTranscriptionID.remove(transcriptionID)
        isProcessingAI = !postProcessingByTranscriptionID.isEmpty
    }

    private func clearPostProcessingError(for transcriptionID: UUID) {
        postProcessingErrorByTranscriptionID.removeValue(forKey: transcriptionID)
    }
}
