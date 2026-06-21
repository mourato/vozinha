import Foundation
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

extension RecordingManager {
    func capturePostProcessingContext(
        for meeting: Meeting,
        includeWindowOCR: Bool? = nil
    ) async -> (context: String?, items: [TranscriptionContextItem]) {
        let settings = AppSettingsStore.shared
        let activeTabURL = activeBrowserURL(for: meeting.appBundleIdentifier)?.absoluteString
        let calendarContext = meeting.supportsMeetingConversation
            ? meeting.linkedCalendarEvent.map(calendarContextBlock(for:))
            : nil

        return await contextCaptureService.capturePostProcessingContext(
            for: meeting,
            settings: settings,
            activeTabURL: activeTabURL,
            calendarContext: calendarContext,
            isDictationMode: isDictationMode(for: meeting),
            includeWindowOCR: includeWindowOCR
        )
    }

    func cancelPostStartCaptureTasks() {
        postStartContextCaptureTask?.cancel()
        postStartContextCaptureTask = nil
        deferredContextOCRTask?.cancel()
        deferredContextOCRTask = nil
    }

    func startContextCaptureAfterRecordingStart(meetingID: UUID) {
        cancelPostStartCaptureTasks()
        postStartContextCaptureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let contextCaptureStartAt = Date()
            guard !Task.isCancelled else { return }
            guard let meeting = currentMeeting, meeting.id == meetingID else { return }

            let captureResult = await capturePostProcessingContextWithTimeout(
                for: meeting,
                includeWindowOCR: false
            )
            guard !Task.isCancelled else { return }
            guard currentMeeting?.id == meetingID else { return }

            postProcessingContext = captureResult.context
            postProcessingContextItems = captureResult.items

            if captureResult.didTimeout {
                AppLogger.warning(
                    "Context capture timed out after recording start",
                    category: .recordingManager
                )
            }

            PerformanceMonitor.shared.reportMetric(
                name: "recording_start_context_capture_ms",
                value: Date().timeIntervalSince(contextCaptureStartAt) * 1_000,
                unit: "ms"
            )

            scheduleDeferredWindowOCRCaptureIfNeeded(meetingID: meetingID)
        }
    }

    private func capturePostProcessingContextWithTimeout(
        for meeting: Meeting,
        includeWindowOCR: Bool? = nil
    ) async -> PostProcessingContextCaptureResult {
        let settings = AppSettingsStore.shared
        let activeTabURL = activeBrowserURL(for: meeting.appBundleIdentifier)?.absoluteString
        let calendarContext = meeting.supportsMeetingConversation
            ? meeting.linkedCalendarEvent.map(calendarContextBlock(for:))
            : nil

        return await contextCaptureService.capturePostProcessingContextWithTimeout(
            for: meeting,
            settings: settings,
            activeTabURL: activeTabURL,
            calendarContext: calendarContext,
            isDictationMode: isDictationMode(for: meeting),
            includeWindowOCR: includeWindowOCR,
            timeoutNanoseconds: Constants.startContextCaptureTimeout
        )
    }

    private func scheduleDeferredWindowOCRCaptureIfNeeded(meetingID: UUID) {
        deferredContextOCRTask?.cancel()

        let settings = AppSettingsStore.shared
        guard settings.contextAwarenessEnabled, settings.contextAwarenessIncludeWindowOCR else {
            deferredContextOCRTask = nil
            return
        }

        deferredContextOCRTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Constants.deferredWindowOCRCaptureDelay)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard isRecording, let meeting = currentMeeting, meeting.id == meetingID else { return }

            let captureResult = await capturePostProcessingContextWithTimeout(
                for: meeting,
                includeWindowOCR: true
            )

            guard !Task.isCancelled else { return }
            guard isRecording, currentMeeting?.id == meetingID else { return }
            guard let ocrItem = captureResult.items.first(where: { $0.source == .windowOCR }) else { return }

            var updatedItems = postProcessingContextItems
            let alreadyPresent = updatedItems.contains {
                $0.source == .windowOCR && $0.text == ocrItem.text
            }

            guard !alreadyPresent else { return }

            updatedItems.append(ocrItem)
            postProcessingContextItems = updatedItems

            var updatedContext = postProcessingContext
            appendContextBlock(
                """
                - Active window visible text (OCR):
                \(ocrItem.text)
                """,
                to: &updatedContext
            )
            postProcessingContext = updatedContext

            AppLogger.debug(
                "Deferred OCR context capture appended",
                category: .recordingManager,
                extra: ["meetingID": meetingID.uuidString]
            )
        }
    }

    private func appendContextBlock(_ block: String, to context: inout String?) {
        if let existingContext = context,
           !existingContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            context = "\(existingContext)\n\(block)"
        } else {
            context = """
            CONTEXT_METADATA
            \(block)
            """
        }
    }
}
