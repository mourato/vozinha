import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Recording Stop and Cancellation

public extension RecordingManager {
    /// Stop recording and optionally transcribe.
    func stopRecording() async {
        await stopRecording(transcribe: true)
    }

    func stopRecording(transcribe: Bool = true) async {
        guard isRecording else {
            AppLogger.info("Attempted to stop recording but not recording", category: .recordingManager)
            return
        }

        cancelPostStartCaptureTasks()
        isStartingRecording = false
        var transcriptionSession: TranscriptionSessionSnapshot?

        do {
            let micURL = await micRecorder.stopRecording()
            let sysURL = await systemRecorder.stopRecording()

            currentMeeting?.endTime = Date()
            transcriptionSession = currentMeeting.map(makeTranscriptionSessionSnapshot)

            if transcribe, let transcriptionSession {
                registerTranscriptionSession(transcriptionSession.id, foreground: true)
                meetingState = .processing(.transcribing)
                currentMeeting?.state = .processing(.transcribing)
            } else {
                meetingState = .idle
                currentMeeting?.state = .completed
            }

            isRecording = false
            await RecordingExclusivityCoordinator.shared.endRecording()
            SoundFeedbackService.shared.playRecordingStopSound()

            AppLogger.info("Recording stopped", category: .recordingManager, extra: [
                "micURL": micURL?.lastPathComponent ?? "nil",
                "sysURL": sysURL?.lastPathComponent ?? "nil",
            ])

            let finalURL = try await processRecordedAudio(micURL: micURL, sysURL: sysURL)

            if transcribe, let transcriptionSession {
                if incrementalDictationCoordinator != nil, transcriptionSession.meeting.capturePurpose == .dictation {
                    await transcribeIncrementalSession(
                        audioURL: finalURL,
                        session: transcriptionSession,
                        coordinatorKind: .dictation,
                    )
                } else if incrementalMeetingCoordinator != nil, transcriptionSession.meeting.capturePurpose == .meeting {
                    await transcribeIncrementalSession(
                        audioURL: finalURL,
                        session: transcriptionSession,
                        coordinatorKind: .meeting,
                    )
                } else {
                    let preparedAudio = await prepareAudioForTranscription(
                        audioURL: finalURL,
                        allowSilenceRemoval: shouldRemoveSilenceBeforeTranscription(for: transcriptionSession),
                    )
                    await transcribeRecording(
                        audioURL: preparedAudio.transcriptionURL,
                        session: transcriptionSession,
                        cleanupAudioURL: preparedAudio.cleanupURL,
                    )
                }
            } else {
                await resetAfterDiscardingRecording()
            }
        } catch {
            await handleStopRecordingError(error, transcriptionSession: transcriptionSession)
        }
    }

    /// Cancel recording and discard audio files.
    func cancelRecording() async {
        guard isRecording || isStartingRecording else { return }

        if !isRecording {
            AppLogger.info("Cancelling recording during startup...", category: .recordingManager)
            _ = await micRecorder.stopRecording()
            _ = await systemRecorder.stopRecording()
            await cancelIncrementalTranscriptionSessionsIfNeeded()
            cancelPostStartCaptureTasks()
            isStartingRecording = false
            cancelEstimatedPostProcessingProgress(for: currentMeeting?.id)
            currentCapturePurpose = nil
            isMeetingMicrophoneEnabled = false
            clearMeetingNotesState(removePersistedValue: true)
            currentMeeting = nil
            postProcessingContext = nil
            postProcessingContextItems = []
            dictationSessionOutputLanguageOverride = nil
            dictationStartBundleIdentifier = nil
            dictationStartURL = nil
            activeDictationStyleSnapshot = nil
            activeStartTelemetry = nil
            clearPostProcessingReadinessWarning()
            await RecordingExclusivityCoordinator.shared.endRecording()
            SoundFeedbackService.shared.playRecordingCancelledSound()
            AppLogger.info("Recording startup cancelled", category: .recordingManager)
            return
        }

        AppLogger.info("Cancelling recording...", category: .recordingManager)
        _ = await micRecorder.stopRecording()
        _ = await systemRecorder.stopRecording()
        await cancelIncrementalTranscriptionSessionsIfNeeded()
        cancelPostStartCaptureTasks()

        await cleanupTemporaryFiles()

        if let mergedURL = await getMergedAudioURL() {
            try? FileManager.default.removeItem(at: mergedURL)
            setMergedAudioURL(nil)
        }

        isRecording = false
        isStartingRecording = false
        cancelEstimatedPostProcessingProgress(for: currentMeeting?.id)
        currentCapturePurpose = nil
        isMeetingMicrophoneEnabled = false
        clearMeetingNotesState(removePersistedValue: true)
        currentMeeting = nil
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        dictationStartBundleIdentifier = nil
        dictationStartURL = nil
        activeDictationStyleSnapshot = nil
        activeStartTelemetry = nil
        clearPostProcessingReadinessWarning()
        await RecordingExclusivityCoordinator.shared.endRecording()
        SoundFeedbackService.shared.playRecordingCancelledSound()

        AppLogger.info("Recording cancelled and files discarded", category: .recordingManager)
    }
}

private extension RecordingManager {
    enum IncrementalCoordinatorKind {
        case dictation
        case meeting
    }

    func transcribeIncrementalSession(
        audioURL: URL,
        session: TranscriptionSessionSnapshot,
        coordinatorKind: IncrementalCoordinatorKind,
    ) async {
        let checkpointID: UUID? = switch coordinatorKind {
        case .dictation:
            await incrementalDictationCoordinator?.checkpointID
        case .meeting:
            await incrementalMeetingCoordinator?.checkpointID
        }

        do {
            let transcription: Transcription = switch coordinatorKind {
            case .dictation:
                try await finishIncrementalDictationSession(audioURL: audioURL, session: session)
            case .meeting:
                try await finishIncrementalMeetingSession(audioURL: audioURL, session: session)
            }
            finishSuccessfulTranscription(transcription, session: session)
            if AppSettingsStore.shared.autoExportSummaries {
                await exportSummary(transcription: transcription)
            }
            clearCompletedMeetingState(sessionID: session.id)
        } catch {
            let fallbackReason = await incrementalFallbackReason(for: coordinatorKind)
            AppLogger.warning(
                "Incremental transcription failed during finalization; falling back to legacy full-file pipeline",
                category: .recordingManager,
                extra: [
                    "error": error.localizedDescription,
                    "reason": fallbackReason,
                ],
            )
            teardownIncrementalCoordinator(for: coordinatorKind)
            let preparedAudio = await prepareAudioForTranscription(
                audioURL: audioURL,
                allowSilenceRemoval: shouldRemoveSilenceBeforeTranscription(for: session),
            )
            await transcribeRecording(
                audioURL: preparedAudio.transcriptionURL,
                session: session,
                cleanupAudioURL: preparedAudio.cleanupURL,
                transcriptionIDOverride: checkpointID,
                pipelinePath: "incremental->fallback-full-file",
                fallbackReason: fallbackReason,
            )
        }
    }

    func incrementalFallbackReason(for kind: IncrementalCoordinatorKind) async -> String {
        switch kind {
        case .dictation:
            await incrementalDictationCoordinator?.fallbackReason?.rawValue ?? "unknown"
        case .meeting:
            await incrementalMeetingCoordinator?.fallbackReason?.rawValue ?? "unknown"
        }
    }

    func teardownIncrementalCoordinator(for kind: IncrementalCoordinatorKind) {
        switch kind {
        case .dictation:
            teardownIncrementalDictationSession()
        case .meeting:
            teardownIncrementalMeetingSession()
        }
    }

    func finishSuccessfulTranscription(_ transcription: Transcription, session: TranscriptionSessionSnapshot) {
        persistMeetingNotes(session.meetingNotesContent, forTranscription: transcription.id)
        if shouldDriveSharedTranscriptionState(for: session.id) {
            meetingState = .processing(.generatingOutput)
        }
        if currentMeeting?.id == session.id {
            currentMeeting?.state = .completed
        }
        TranscriptionDeliveryService.deliver(transcription: transcription, recordingSource: session.recordingSource, textPolicy: session.dictationTextHandlingPolicy)
        completeVisibleTranscription(success: true, sessionID: session.id)
        notifySuccess(for: transcription)
        scheduleStatusReset(sessionID: session.id)
        unregisterTranscriptionSession(session.id)
        cancelEstimatedPostProcessingProgress(for: session.id)
        isStartingRecording = false

        if foregroundTranscriptionSessionID == nil, !isRecording, !isStartingRecording {
            meetingState = .idle
        }
    }

    func clearCompletedMeetingState(sessionID: UUID) {
        clearMeetingNotesState(removePersistedValue: true, meetingID: sessionID)
        guard currentMeeting?.id == sessionID else { return }
        currentMeeting = nil
        currentCapturePurpose = nil
        isMeetingMicrophoneEnabled = false
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        dictationStartBundleIdentifier = nil
        dictationStartURL = nil
        activeStartTelemetry = nil
        clearPostProcessingReadinessWarning()
    }

    func resetAfterDiscardingRecording() async {
        await cancelIncrementalTranscriptionSessionsIfNeeded()
        cancelEstimatedPostProcessingProgress(for: currentMeeting?.id)
        postProcessingContext = nil
        postProcessingContextItems = []
        dictationSessionOutputLanguageOverride = nil
        dictationStartBundleIdentifier = nil
        dictationStartURL = nil
        clearMeetingNotesState(removePersistedValue: true)
        currentCapturePurpose = nil
        isMeetingMicrophoneEnabled = false
        currentMeeting = nil
        activeStartTelemetry = nil
        clearPostProcessingReadinessWarning()
    }

    func handleStopRecordingError(_ error: Error, transcriptionSession: TranscriptionSessionSnapshot?) async {
        AppLogger.error("Failed to stop recording cleanly", category: .recordingManager, error: error)
        await cancelIncrementalTranscriptionSessionsIfNeeded()
        lastError = error
        isRecording = false
        if let transcriptionSession {
            unregisterTranscriptionSession(transcriptionSession.id)
        }
        cancelEstimatedPostProcessingProgress(for: currentMeeting?.id)
        meetingState = .failed(error.localizedDescription)
        currentMeeting?.state = .failed(error.localizedDescription)
        await RecordingExclusivityCoordinator.shared.endRecording()
        postProcessingContext = nil
        postProcessingContextItems = []
        isStartingRecording = false
        dictationSessionOutputLanguageOverride = nil
        dictationStartBundleIdentifier = nil
        dictationStartURL = nil
        clearMeetingNotesState(removePersistedValue: true)
        currentCapturePurpose = nil
        isMeetingMicrophoneEnabled = false
        activeStartTelemetry = nil
        clearPostProcessingReadinessWarning()
    }
}
