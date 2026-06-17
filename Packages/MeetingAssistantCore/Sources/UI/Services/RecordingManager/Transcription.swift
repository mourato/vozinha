import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

// MARK: - Transcription

extension RecordingManager {
    func transcribeRecording(
        audioURL: URL,
        session: TranscriptionSessionSnapshot,
        cleanupAudioURL: URL? = nil,
        transcriptionIDOverride: UUID? = nil,
        pipelinePath: String = "full-file-direct",
        fallbackReason: String? = nil
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
            extra: pipelineLogExtra
        )

        beginTranscriptionUIStateIfNeeded(for: session)
        cancelEstimatedPostProcessingProgress(for: session.id)

        let audioDuration = await getAudioDuration(from: audioURL)
        beginVisibleTranscriptionStatus(audioDuration: audioDuration, sessionID: session.id)

        do {
            let settings = AppSettingsStore.shared
            let transcriptionStart = Date()
            let meetingEntity = makeMeetingEntity(meeting: session.meeting, audioDuration: audioDuration)
            let config = makeUseCaseConfig(session: session, settings: settings)
            let diarizationEnabledOverride = shouldEnableDiarization(
                for: session.meeting,
                capturePurposeOverride: session.meeting.capturePurpose
            )

            if shouldDriveSharedTranscriptionState(for: session.id) {
                meetingState = .processing(.transcribing)
            }

            let transcriptionEntity = try await transcribeAudioUseCase.execute(
                audioURL: audioURL,
                transcriptionID: transcriptionIDOverride,
                meeting: meetingEntity,
                inputSource: resolveInputSourceLabel(for: session.meeting, recordingSource: session.recordingSource),
                contextItems: config.postProcessingContextItems,
                vocabularyReplacementRules: settings.vocabularyReplacementRules,
                diarizationEnabledOverride: diarizationEnabledOverride,
                applyPostProcessing: config.applyPostProcessing,
                postProcessingPrompt: config.postProcessingPrompt,
                defaultPostProcessingPrompt: config.defaultPostProcessingPrompt,
                postProcessingModel: config.postProcessingModel,
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
                }
            )

            let transcription = convertToModel(transcriptionEntity, audioDuration: audioDuration, transcriptionStart: transcriptionStart)
            persistMeetingNotes(session.meetingNotesContent, forTranscription: transcription.id)
            updateIndicatorProcessingSnapshot(
                step: .finalizingResult,
                progressPercent: 100,
                sessionID: session.id
            )

            if shouldDriveSharedTranscriptionState(for: session.id) {
                meetingState = .processing(.generatingOutput)
            }
            if currentMeeting?.id == session.id {
                currentMeeting?.state = .completed
            }

            TranscriptionDeliveryService.deliver(
                transcription: transcription,
                recordingSource: session.recordingSource
            )

            completeVisibleTranscription(success: true, sessionID: session.id)
            notifySuccess(for: transcription)
            scheduleStatusReset(sessionID: session.id)

            if settings.autoExportSummaries {
                await exportSummary(transcription: transcription)
            }
        } catch {
            cancelEstimatedPostProcessingProgress(for: session.id)
            handleTranscriptionError(error, sessionID: session.id)
            if shouldDriveSharedTranscriptionState(for: session.id) {
                meetingState = .failed(error.localizedDescription)
            }
            if currentMeeting?.id == session.id {
                currentMeeting?.state = .failed(error.localizedDescription)
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

    // MARK: - Entity Conversion

    func makeMeetingEntity(meeting: Meeting, audioDuration: Double?) -> MeetingEntity {
        var entity = MeetingEntity(
            id: meeting.id,
            app: DomainMeetingApp(rawValue: meeting.app.rawValue) ?? .unknown,
            capturePurpose: meeting.capturePurpose,
            appBundleIdentifier: meeting.appBundleIdentifier,
            appDisplayName: meeting.appDisplayName,
            title: meeting.title,
            linkedCalendarEvent: meeting.linkedCalendarEvent,
            startTime: meeting.startTime,
            endTime: meeting.endTime,
            audioFilePath: meeting.audioFilePath
        )

        if entity.endTime == nil, let audioDuration {
            entity.endTime = entity.startTime.addingTimeInterval(audioDuration)
        }

        return entity
    }

    func convertToModel(_ entity: TranscriptionEntity, audioDuration: Double?, transcriptionStart: Date) -> Transcription {
        Transcription(
            id: entity.id,
            meeting: Meeting(
                id: entity.meeting.id,
                app: MeetingApp(rawValue: entity.meeting.app.rawValue) ?? .unknown,
                capturePurpose: entity.meeting.capturePurpose,
                appBundleIdentifier: entity.meeting.appBundleIdentifier,
                appDisplayName: entity.meeting.appDisplayName,
                title: entity.meeting.title,
                linkedCalendarEvent: entity.meeting.linkedCalendarEvent,
                type: MeetingType(rawValue: entity.meetingType ?? "") ?? .general,
                startTime: entity.meeting.startTime,
                endTime: entity.meeting.endTime,
                audioFilePath: entity.meeting.audioFilePath
            ),
            contextItems: entity.contextItems,
            segments: entity.segments.map { Transcription.Segment(id: $0.id, speaker: $0.speaker, text: $0.text, startTime: $0.startTime, endTime: $0.endTime) },
            text: entity.text,
            rawText: entity.rawText,
            processedContent: entity.processedContent,
            canonicalSummary: entity.canonicalSummary,
            qualityProfile: entity.qualityProfile,
            postProcessingPromptId: entity.postProcessingPromptId,
            postProcessingPromptTitle: entity.postProcessingPromptTitle,
            postProcessingRequestSystemPrompt: entity.postProcessingRequestSystemPrompt,
            postProcessingRequestUserPrompt: entity.postProcessingRequestUserPrompt,
            language: entity.language,
            createdAt: entity.createdAt,
            modelName: entity.modelName,
            inputSource: entity.inputSource,
            transcriptionDuration: entity.transcriptionDuration,
            postProcessingDuration: entity.postProcessingDuration,
            postProcessingModel: entity.postProcessingModel,
            meetingType: entity.meetingType,
            lifecycleState: entity.lifecycleState,
            postProcessingFailureReason: entity.postProcessingFailureReason
        )
    }

    // MARK: - Health Check & Transcription

    func performHealthCheck(
        capturePurpose: CapturePurpose = .meeting,
        sessionID: UUID? = nil
    ) async throws {
        updateVisibleTranscriptionProgress(phase: .preparing, sessionID: sessionID)

        if capturePurpose == .dictation,
           AppSettingsStore.shared.shouldUseRemoteTranscription(for: .dictation)
        {
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
        sessionID: UUID? = nil
    ) async throws -> TranscriptionResponse {
        updateVisibleTranscriptionProgress(
            phase: .processing,
            percentage: Constants.processingProgress,
            sessionID: sessionID
        )
        let onProgress: @Sendable (Double) -> Void = { [weak self] percentage in
            Task { @MainActor in
                self?.updateVisibleTranscriptionProgress(
                    phase: .processing,
                    percentage: percentage,
                    sessionID: sessionID
                )
            }
        }

        if let diarizationAwareClient = transcriptionClient as? any TranscriptionServicePurposeDiarized {
            return try await diarizationAwareClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride,
                capturePurpose: capturePurpose
            )
        }

        if let diarizationAwareClient = transcriptionClient as? any TranscriptionServiceDiarizationOverride {
            return try await diarizationAwareClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                diarizationEnabledOverride: diarizationEnabledOverride
            )
        }

        if let purposeAwareClient = transcriptionClient as? any TranscriptionServicePurposeAware {
            return try await purposeAwareClient.transcribe(
                audioURL: audioURL,
                onProgress: onProgress,
                capturePurpose: capturePurpose
            )
        }

        return try await transcriptionClient.transcribe(
            audioURL: audioURL,
            onProgress: onProgress
        )
    }

    func handleUseCasePhaseChange(_ phase: TranscriptionPhase, meeting: Meeting, sessionID: UUID) {
        switch phase {
        case .preparing:
            updateVisibleTranscriptionProgress(phase: .preparing, sessionID: sessionID)
        case .processing:
            updateVisibleTranscriptionProgress(
                phase: .processing,
                percentage: max(Constants.processingProgress, transcriptionStatus.progressPercentage),
                sessionID: sessionID
            )
        case .postProcessing:
            let startProgress = max(Constants.postProcessingProgress, transcriptionStatus.progressPercentage)
            updateVisibleTranscriptionProgress(
                phase: .postProcessing,
                percentage: startProgress,
                sessionID: sessionID
            )
            if meeting.capturePurpose == .meeting, meeting.type == .autodetect {
                updateIndicatorProcessingSnapshot(
                    step: .detectingMeetingType,
                    progressPercent: startProgress,
                    sessionID: sessionID
                )
            }

            if meeting.capturePurpose == .meeting {
                startEstimatedPostProcessingProgress(from: startProgress, sessionID: sessionID)
            }
        case .completed:
            cancelEstimatedPostProcessingProgress(for: sessionID)
        case .failed:
            cancelEstimatedPostProcessingProgress(for: sessionID)
        case .idle:
            break
        }
    }

    func handleUseCaseTranscriptionProgress(_ progress: Double, sessionID: UUID) {
        let clamped = min(max(progress, 0), 100)
        let processingRange = Constants.postProcessingProgress - Constants.processingProgress
        let mappedProgress = Constants.processingProgress + (clamped / 100.0 * processingRange)
        updateVisibleTranscriptionProgress(
            phase: .processing,
            percentage: mappedProgress,
            sessionID: sessionID
        )
    }

    func startEstimatedPostProcessingProgress(from startProgress: Double, sessionID: UUID) {
        guard shouldDriveForegroundTranscriptionUI(for: sessionID) else { return }

        cancelEstimatedPostProcessingProgress(for: sessionID)

        let clampedStart = min(max(startProgress, Constants.postProcessingProgress), Constants.postProcessingProgressCeiling)
        estimatedPostProcessingProgressSessionID = sessionID
        updateVisibleTranscriptionProgress(
            phase: .postProcessing,
            percentage: clampedStart,
            sessionID: sessionID
        )

        estimatedPostProcessingProgressTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startDate = Date()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Constants.postProcessingProgressTickNanoseconds)
                guard !Task.isCancelled else { return }

                let elapsed = Date().timeIntervalSince(startDate)
                let easedProgress = Constants.postProcessingProgressCeiling
                    - (Constants.postProcessingProgressCeiling - clampedStart) * exp(-elapsed / Constants.postProcessingProgressSmoothingTau)
                let nextProgress = min(Constants.postProcessingProgressCeiling, max(clampedStart, easedProgress))
                updateVisibleTranscriptionProgress(
                    phase: .postProcessing,
                    percentage: nextProgress,
                    sessionID: sessionID
                )
            }
        }
    }

    func cancelEstimatedPostProcessingProgress(for sessionID: UUID? = nil) {
        if let sessionID, estimatedPostProcessingProgressSessionID != sessionID {
            return
        }
        estimatedPostProcessingProgressTask?.cancel()
        estimatedPostProcessingProgressTask = nil
        estimatedPostProcessingProgressSessionID = nil
    }

    func shouldEnableDiarization(
        for meeting: Meeting,
        capturePurposeOverride: CapturePurpose? = nil
    ) -> Bool {
        if meeting.app == .importedFile {
            return false
        }

        if let capturePurposeOverride {
            return capturePurposeOverride == .meeting
        }

        return meeting.supportsMeetingConversation
    }

    // MARK: - Notifications

    func notifySuccess(for transcription: Transcription) {
        let body: String
        if let failureReason = transcription.postProcessingFailureReason {
            RecordingIndicatorProcessingStateStore.shared.update(
                snapshot: RecordingIndicatorProcessingSnapshot(
                    step: .postProcessingFailed,
                    progressPercent: nil
                )
            )
            body = "notification.transcription_body_with_post_processing_failure".localized(
                with: transcription.meeting.appName,
                transcription.wordCount,
                failureReason
            )
        } else {
            let suffix = transcription.isPostProcessed
                ? "notification.transcription_processed".localized
                : "notification.transcription_transcribed".localized
            body = "notification.transcription_body".localized(
                with: transcription.meeting.appName,
                transcription.wordCount,
                suffix
            )
        }

        notificationService.sendNotification(
            title: "notification.transcription_completed".localized,
            body: body
        )

        NotificationCenter.default.post(
            name: .meetingAssistantTranscriptionSaved,
            object: nil,
            userInfo: [AppNotifications.UserInfoKey.transcriptionId: transcription.id.uuidString]
        )
    }

    func handleTranscriptionError(_ error: Error, sessionID: UUID? = nil) {
        AppLogger.error("Transcription failed", category: .recordingManager, error: error)
        lastError = error
        cancelEstimatedPostProcessingProgress(for: sessionID)

        updateIndicatorProcessingSnapshot(
            step: .transcribingFailed,
            progressPercent: nil,
            sessionID: sessionID
        )

        let statusError = self.transcriptionStatusError(from: error)

        if shouldDriveForegroundTranscriptionUI(for: sessionID) {
            transcriptionStatus.recordError(statusError)
            transcriptionStatus.completeTranscription(success: false)
        }

        notificationService.sendNotification(
            title: "notification.transcription_failed".localized,
            body: statusError.localizedDescription
        )
    }

    private func transcriptionStatusError(from error: Error) -> TranscriptionStatusError {
        switch error {
        case let error as TranscriptionError:
            switch error {
            case .serviceUnavailable:
                return .serviceUnavailable
            case .warmupFailed:
                return .modelLoadFailed(error.localizedDescription)
            case .invalidResponse:
                return .transcriptionFailed(error.localizedDescription)
            case .invalidURL:
                return .connectionFailed(error.localizedDescription)
            case .transcriptionFailed(let message):
                return .transcriptionFailed(message)
            }
        case let error as DomainTranscriptionError:
            switch error {
            case .serviceUnavailable:
                return .serviceUnavailable
            case .invalidAudioFile:
                return .transcriptionFailed("error.transcription.invalid_audio_file".localized)
            case .transcriptionFailed(let message):
                return .transcriptionFailed(message)
            case .postProcessingFailed(let message):
                return .transcriptionFailed(message)
            }
        case let error as PostProcessingError:
            return .transcriptionFailed(error.localizedDescription)
        case let error as RecordingManagerError:
            switch error {
            case .noOutputPath:
                return .transcriptionFailed("error.transcription.no_output_path".localized)
            case .mergeFailed:
                return .transcriptionFailed("error.transcription.merge_failed".localized)
            case .noInputFiles:
                return .transcriptionFailed("error.transcription.no_input_files".localized)
            }
        default:
            return .transcriptionFailed(error.localizedDescription)
        }
    }

    func scheduleStatusReset(sessionID: UUID? = nil) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Constants.statusResetDelay))
            guard self.shouldResetVisibleTranscriptionStatus(for: sessionID) else { return }
            self.transcriptionStatus.resetToIdle()
            self.resetIndicatorProcessingSnapshot(sessionID: sessionID)
        }
    }

    func registerTranscriptionSession(_ sessionID: UUID, foreground: Bool) {
        activeTranscriptionSessionIDs.insert(sessionID)
        isTranscribing = true

        guard foreground else { return }
        foregroundTranscriptionSessionID = sessionID
        isForegroundTranscribing = true
    }

    func unregisterTranscriptionSession(_ sessionID: UUID) {
        activeTranscriptionSessionIDs.remove(sessionID)
        isTranscribing = !activeTranscriptionSessionIDs.isEmpty

        if foregroundTranscriptionSessionID == sessionID {
            foregroundTranscriptionSessionID = nil
            isForegroundTranscribing = false
        }
    }

    func shouldDriveForegroundTranscriptionUI(for sessionID: UUID?) -> Bool {
        guard let sessionID else { return true }
        return foregroundTranscriptionSessionID == sessionID
    }

    func shouldResetVisibleTranscriptionStatus(for sessionID: UUID?) -> Bool {
        guard let sessionID else { return true }
        return foregroundTranscriptionSessionID == nil || foregroundTranscriptionSessionID == sessionID
    }

    func shouldDriveSharedTranscriptionState(for sessionID: UUID) -> Bool {
        if currentMeeting?.id == sessionID {
            return true
        }

        return !isRecording && !isStartingRecording
    }

    func beginVisibleTranscriptionStatus(audioDuration: Double?, sessionID: UUID?) {
        guard shouldDriveForegroundTranscriptionUI(for: sessionID) else { return }
        transcriptionStatus.beginTranscription(audioDuration: audioDuration)
        updateIndicatorProcessingSnapshot(step: .preparingAudio, progressPercent: 0, sessionID: sessionID)
    }

    func updateVisibleTranscriptionProgress(
        phase: TranscriptionPhase,
        percentage: Double? = nil,
        sessionID: UUID?
    ) {
        guard shouldDriveForegroundTranscriptionUI(for: sessionID) else { return }
        transcriptionStatus.updateProgress(phase: phase, percentage: percentage)
        if let step = indicatorProcessingStep(for: phase) {
            updateIndicatorProcessingSnapshot(step: step, progressPercent: percentage, sessionID: sessionID)
        }
    }

    func completeVisibleTranscription(success: Bool, sessionID: UUID?) {
        guard shouldDriveForegroundTranscriptionUI(for: sessionID) else { return }
        transcriptionStatus.completeTranscription(success: success)
    }

    func indicatorProcessingStep(for phase: TranscriptionPhase) -> RecordingIndicatorProcessingStep? {
        switch phase {
        case .idle:
            nil
        case .failed:
            .transcribingFailed
        case .preparing:
            .preparingAudio
        case .processing:
            .transcribingAudio
        case .postProcessing:
            .postProcessing
        case .completed:
            .finalizingResult
        }
    }

    func updateIndicatorProcessingSnapshot(
        step: RecordingIndicatorProcessingStep,
        progressPercent: Double? = nil,
        sessionID: UUID?
    ) {
        guard shouldDriveForegroundTranscriptionUI(for: sessionID) else { return }
        RecordingIndicatorProcessingStateStore.shared.update(
            snapshot: RecordingIndicatorProcessingSnapshot(
                step: step,
                progressPercent: progressPercent
            )
        )
    }

    func resetIndicatorProcessingSnapshot(sessionID: UUID?) {
        guard shouldResetVisibleTranscriptionStatus(for: sessionID) else { return }
        RecordingIndicatorProcessingStateStore.shared.reset()
    }

    /// Get audio duration from file for progress estimation.
    func getAudioDuration(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            AppLogger.error("Failed to load audio duration", category: .recordingManager, error: error)
            return nil
        }
    }
}
