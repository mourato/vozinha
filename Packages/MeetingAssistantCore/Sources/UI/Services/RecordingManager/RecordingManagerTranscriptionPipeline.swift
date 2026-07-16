import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Transcription Pipeline

extension RecordingManager {
    func transcribeRecording(
        audioURL: URL,
        session: TranscriptionSessionSnapshot,
        cleanupAudioURL: URL? = nil,
        transcriptionIDOverride: UUID? = nil,
        pipelinePath: String = "full-file-direct",
        fallbackReason: String? = nil,
    ) async {
        defer {
            if let cleanupAudioURL {
                storage.cleanupTemporaryFiles(urls: [cleanupAudioURL])
            }
        }

        var pipelineLogExtra: [String: String] = [
            "path": pipelinePath,
            "sessionID": session.id.uuidString,
            "capturePurpose": session.meeting.capturePurpose.rawValue,
            "audio": audioURL.lastPathComponent,
        ]
        if let fallbackReason {
            pipelineLogExtra["reason"] = fallbackReason
        }
        AppLogger.info(
            "Selected transcription pipeline",
            category: .recordingManager,
            extra: pipelineLogExtra,
        )

        beginTranscriptionUIStateIfNeeded(for: session)
        cancelEstimatedPostProcessingProgress(for: session.id)

        let audioDuration = await getAudioDuration(from: audioURL)
        beginVisibleTranscriptionStatus(audioDuration: audioDuration, sessionID: session.id)

        do {
            let transcription = try await executeTranscription(
                audioURL: audioURL,
                session: session,
                audioDuration: audioDuration,
                transcriptionIDOverride: transcriptionIDOverride,
            )
            persistMeetingNotes(session.meetingNotesContent, forTranscription: transcription.id)
            updateIndicatorProcessingSnapshot(
                step: .finalizingResult,
                progressPercent: 100,
                sessionID: session.id,
            )

            if shouldDriveSharedTranscriptionState(for: session.id) {
                meetingState = .processing(.generatingOutput)
            }
            if currentMeeting?.id == session.id {
                currentMeeting?.state = .completed
            }

            TranscriptionDeliveryService.deliver(
                transcription: transcription,
                recordingSource: session.recordingSource,
                textPolicy: session.dictationTextHandlingPolicy,
            )

            completeVisibleTranscription(success: true, sessionID: session.id)
            notifySuccess(for: transcription)
            scheduleStatusReset(sessionID: session.id)

            if AppSettingsStore.shared.autoExportSummaries {
                await exportSummary(transcription: transcription)
            }
        } catch {
            cancelEstimatedPostProcessingProgress(for: session.id)
            await persistFailedTranscriptionAttempt(
                audioURL: audioURL,
                persistedAudioURL: persistedAudioURL(
                    transcriptionURL: audioURL,
                    cleanupAudioURL: cleanupAudioURL,
                    session: session,
                ),
                session: session,
                audioDuration: audioDuration,
                transcriptionIDOverride: transcriptionIDOverride,
                error: error,
            )
            handleTranscriptionError(error, sessionID: session.id)
            if shouldDriveSharedTranscriptionState(for: session.id) {
                meetingState = .failed(transcriptionStatusError(from: error).localizedDescription)
            }
            if currentMeeting?.id == session.id {
                currentMeeting?.state = .failed(transcriptionStatusError(from: error).localizedDescription)
            }
        }

        unregisterTranscriptionSession(session.id)
        cancelEstimatedPostProcessingProgress(for: session.id)
        isStartingRecording = false

        if foregroundTranscriptionSessionID == nil, !isRecording, !isStartingRecording {
            meetingState = .idle
        }

        clearMeetingNotesState(removePersistedValue: true, meetingID: session.id)

        if currentMeeting?.id == session.id {
            currentMeeting = nil
            currentCapturePurpose = nil
            isMeetingMicrophoneEnabled = false
            postProcessingContext = nil
            postProcessingContextItems = []
            dictationSessionOutputLanguageOverride = nil
            dictationStartBundleIdentifier = nil
            dictationStartURL = nil
            activeStartTelemetry = nil
            cancelPostStartCaptureTasks()
            clearPostProcessingReadinessWarning()
        }
    }

    func beginTranscriptionUIStateIfNeeded(for session: TranscriptionSessionSnapshot) {
        registerTranscriptionSession(session.id, foreground: true)
        if shouldDriveSharedTranscriptionState(for: session.id) {
            meetingState = .processing(.transcribing)
        }
        if currentMeeting?.id == session.id {
            currentMeeting?.state = .processing(.transcribing)
        }
    }

    private func executeTranscription(
        audioURL: URL,
        session: TranscriptionSessionSnapshot,
        audioDuration: Double?,
        transcriptionIDOverride: UUID?,
    ) async throws -> Transcription {
        let settings = AppSettingsStore.shared
        let transcriptionStart = Date()
        let meetingEntity = makeMeetingEntity(meeting: session.meeting, audioDuration: audioDuration)
        let config = makeUseCaseConfig(session: session, settings: settings)
        let transcriptionIdentity = resolvedTranscriptionPerformanceIdentity(
            capturePurpose: session.meeting.capturePurpose,
        )
        let diarizationEnabledOverride = shouldEnableDiarization(
            for: session.meeting,
            capturePurposeOverride: session.meeting.capturePurpose,
        )

        if shouldDriveSharedTranscriptionState(for: session.id) {
            meetingState = .processing(.transcribing)
        }

        let transcriptionEntity = try await transcribeAudioUseCase.execute(
            audioURL: audioURL,
            transcriptionID: transcriptionIDOverride,
            meeting: meetingEntity,
            transcriptionIdentity: transcriptionIdentity,
            inputSource: resolveInputSourceLabel(for: session.meeting, recordingSource: session.recordingSource),
            contextItems: config.postProcessingContextItems,
            vocabularyReplacementRules: settings.vocabularyReplacementRules,
            diarizationEnabledOverride: diarizationEnabledOverride,
            transcriptionConfiguration: config.dictationTranscriptionConfiguration.map {
                DomainTranscriptionRequestConfiguration(
                    providerID: $0.selection.provider.rawValue,
                    modelID: $0.selection.selectedModel,
                    inputLanguageCode: $0.inputLanguageCode,
                )
            },
            applyPostProcessing: config.applyPostProcessing,
            postProcessingPrompt: config.postProcessingPrompt,
            defaultPostProcessingPrompt: config.defaultPostProcessingPrompt,
            postProcessingIdentity: config.postProcessingIdentity,
            postProcessingSelection: config.dictationEnhancementsSelection.map {
                DomainPostProcessingSelection(providerID: $0.provider.rawValue, modelID: $0.selectedModel, registrationID: $0.registrationID)
            },
            autoDetectMeetingType: config.autoDetectMeetingType,
            availablePrompts: config.availablePrompts,
            postProcessingContext: config.postProcessingContext,
            kernelMode: config.kernelMode,
            dictationStructuredPostProcessingEnabled: config.dictationStructuredPostProcessingEnabled,
            onPhaseChange: { [weak self] phase in
                Task { @MainActor [weak self] in
                    self?.handleUseCasePhaseChange(phase, meeting: session.meeting, sessionID: session.id)
                }
            },
            onTranscriptionProgress: { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.handleUseCaseTranscriptionProgress(progress, sessionID: session.id)
                }
            },
        )

        return convertToModel(
            transcriptionEntity,
            audioDuration: audioDuration,
            transcriptionStart: transcriptionStart,
        )
    }
}
