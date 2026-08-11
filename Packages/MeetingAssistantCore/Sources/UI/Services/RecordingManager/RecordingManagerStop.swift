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
        var transcriptionSession: TranscriptionSessionSnapshot?
        await lifecycleCoordinator.stop(
            isRecording: isRecording,
            transcribe: transcribe,
            operations: lifecycleOperations,
            actions: RecordingLifecycleCoordinator.StopActions(
                beforeRelease: { recordings in
                    self.isStartingRecording = false
                    self.currentMeeting?.endTime = Date()
                    transcriptionSession = self.prepareStopState(transcribe: transcribe)
                    self.isRecording = false
                    AppLogger.info("Recording stopped", category: .recordingManager, extra: [
                        "micURL": recordings.mic?.lastPathComponent ?? "nil",
                        "sysURL": recordings.system?.lastPathComponent ?? "nil",
                    ])
                },
                finalize: { recordings in
                    let finalURL = try await self.processRecordedAudio(
                        micURL: recordings.mic,
                        sysURL: recordings.system,
                    )

                    if transcribe, let transcriptionSession {
                        if self.incrementalDictationCoordinator != nil, transcriptionSession.meeting.capturePurpose == .dictation {
                            await self.transcribeIncrementalSession(
                                audioURL: finalURL,
                                session: transcriptionSession,
                                coordinatorKind: .dictation,
                            )
                        } else if self.incrementalMeetingCoordinator != nil, transcriptionSession.meeting.capturePurpose == .meeting {
                            await self.transcribeIncrementalSession(
                                audioURL: finalURL,
                                session: transcriptionSession,
                                coordinatorKind: .meeting,
                            )
                        } else {
                            let preparedAudio = await self.prepareAudioForTranscription(
                                audioURL: finalURL,
                                allowSilenceRemoval: self.shouldRemoveSilenceBeforeTranscription(for: transcriptionSession),
                            )
                            await self.transcribeRecording(
                                audioURL: preparedAudio.transcriptionURL,
                                session: transcriptionSession,
                                cleanupAudioURL: preparedAudio.cleanupURL,
                            )
                        }
                    }
                },
                handleFailure: { error in
                    await self.handleStopRecordingError(error, transcriptionSession: transcriptionSession)
                },
            ),
        )

    }

    /// Cancel recording and discard audio files.
    func cancelRecording() async {
        let wasRecording = isRecording
        guard wasRecording || isStartingRecording else { return }

        AppLogger.info(
            wasRecording ? "Cancelling recording..." : "Cancelling recording during startup...",
            category: .recordingManager,
        )
        await lifecycleCoordinator.cancel(
            isRecording: wasRecording,
            isStarting: isStartingRecording,
            operations: lifecycleOperations,
        )
        AppLogger.info(
            wasRecording ? "Recording cancelled and files discarded" : "Recording startup cancelled",
            category: .recordingManager,
        )
    }
}

private extension RecordingManager {
    func prepareStopState(transcribe: Bool) -> TranscriptionSessionSnapshot? {
        let session = currentMeeting.map(makeTranscriptionSessionSnapshot)
        clearActiveTranscriptionSnapshot()

        if transcribe, let session {
            registerTranscriptionSession(session.id, foreground: true)
            meetingState = .processing(.transcribing)
            currentMeeting?.state = .processing(.transcribing)
        } else {
            meetingState = .idle
            currentMeeting?.state = .completed
        }

        return session
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
        clearActiveTranscriptionSnapshot()
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

    func handleStopRecordingError(_ error: Error, transcriptionSession: TranscriptionSessionSnapshot?) async {
        AppLogger.error("Failed to stop recording cleanly", category: .recordingManager, error: error)
        await cancelIncrementalTranscriptionSessionsIfNeeded()
        await resetRecordingLifecycleState(
            error: error,
            transcriptionID: transcriptionSession?.id,
        )
    }
}
