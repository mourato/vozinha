import AVFoundation
import Combine
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.log
import UserNotifications

extension RecordingManager {
    func setupRecorderErrorForwarding() {
        guard let recorder = micRecorder as? AudioRecorder else { return }

        recorder.onRecordingError = { [weak self] error in
            Task { @MainActor [weak self] in
                await self?.handleUnexpectedRecorderFailure(error)
            }
        }
    }

    private func handleUnexpectedRecorderFailure(_ error: Error) async {
        guard isRecording || isStartingRecording else { return }

        AppLogger.error(
            "Recorder reported an unexpected runtime failure",
            category: .recordingManager,
            error: error,
        )

        cancelPostStartCaptureTasks()
        await cancelIncrementalTranscriptionSessionsIfNeeded()
        isRecording = false
        isStartingRecording = false
        isTranscribing = !activeTranscriptionSessionIDs.isEmpty
        cancelEstimatedPostProcessingProgress(for: currentMeeting?.id)
        meetingState = .failed(error.localizedDescription)
        currentMeeting?.state = .failed(error.localizedDescription)
        clearMeetingNotesState(removePersistedValue: true)
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
        lastError = error
        await RecordingExclusivityCoordinator.shared.endRecording()
    }

    func setupBindings() {
        // Sync with audio recorder state
        micRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recorderIsRecording in
                guard let self else { return }

                // AudioRecorder is shared between recording and assistant flows.
                // Only mirror recorder state when RecordingManager owns an active capture lifecycle.
                let managerOwnsCapture = isStartingRecording || currentCapturePurpose != nil || isRecording
                guard managerOwnsCapture else { return }

                isRecording = recorderIsRecording
                if recorderIsRecording {
                    isStartingRecording = false
                }
            }
            .store(in: &cancellables)
    }

    func cleanupTemporaryFiles() async {
        var urlsToDelete: [URL] = []
        if let micURL = await getMicAudioURL() {
            urlsToDelete.append(micURL)
        }
        if let sysURL = await getSystemAudioURL() {
            urlsToDelete.append(sysURL)
        }

        storage.cleanupTemporaryFiles(urls: urlsToDelete)

        setMicAudioURL(nil)
        setSystemAudioURL(nil)
    }

    func markRecorderStartedAt(_ recorderStartedAt: Date) {
        guard var telemetry = activeStartTelemetry else { return }
        telemetry.recorderStartedAt = recorderStartedAt
        activeStartTelemetry = telemetry

        AppLogger.debug(
            "Recording startup reached recorder",
            category: .performance,
            extra: [
                "trace": telemetry.traceID,
                "trigger": telemetry.triggerLabel,
                "source": telemetry.source.rawValue,
            ],
        )

        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_requested_to_recorder_ms",
            value: recorderStartedAt.timeIntervalSince(telemetry.requestedAt) * 1_000,
            unit: "ms",
        )
        PerformanceMonitor.shared.reportMetric(
            name: "recording_start_entry_to_recorder_ms",
            value: recorderStartedAt.timeIntervalSince(telemetry.managerEntryAt) * 1_000,
            unit: "ms",
        )
    }

    func processRecordedAudio(micURL: URL?, sysURL: URL?) async throws -> URL {
        guard let outputURL = await getMergedAudioURL() else {
            throw RecordingManagerError.noOutputPath
        }

        if incrementalDictationCoordinator != nil,
           currentCapturePurpose == .dictation,
           let micURL
        {
            return micURL
        }

        let settings = AppSettingsStore.shared

        if settings.shouldMergeAudioFiles {
            var inputURLs: [URL] = []
            if let micURL {
                inputURLs.append(micURL)
            }
            if let sysURL {
                inputURLs.append(sysURL)
            }

            if inputURLs.count >= 2 {
                AppLogger.info("Merging \(inputURLs.count) audio files...", category: .recordingManager)
                let finalURL = try await audioMerger.mergeAudioFiles(
                    inputURLs: inputURLs,
                    to: outputURL,
                    format: settings.audioFormat,
                )
                await cleanupTemporaryFiles()
                return finalURL
            } else if let singleURL = inputURLs.first {
                AppLogger.info("Single audio source recorded. Skipping merge and using: \(singleURL.lastPathComponent)", category: .recordingManager)

                if singleURL == outputURL {
                    await cleanupTemporaryFiles()
                    return outputURL
                }

                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                try FileManager.default.moveItem(at: singleURL, to: outputURL)
                await cleanupTemporaryFiles()
                return outputURL
            } else {
                throw RecordingManagerError.noInputFiles
            }
        } else {
            AppLogger.info(
                "Audio merge disabled. Using microphone recording as primary.",
                category: .recordingManager,
            )

            guard let sourceURL = micURL else {
                throw RecordingManagerError.noInputFiles
            }

            if sourceURL != outputURL {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                try FileManager.default.moveItem(at: sourceURL, to: outputURL)
            }

            await cleanupTemporaryFiles()
            return outputURL
        }
    }
}
