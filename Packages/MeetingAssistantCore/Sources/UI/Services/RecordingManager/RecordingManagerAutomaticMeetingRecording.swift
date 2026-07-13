import Combine
import Foundation
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure

public struct AutomaticMeetingRecordingConfirmation: Sendable, Equatable {
    public let id: UUID
    public let meetingApp: MeetingApp
    public let detectedContext: ResolvedCaptureContext
    public let detectedAt: Date
    public let deadline: Date
    public let duration: TimeInterval

    public init(
        id: UUID = UUID(),
        meetingApp: MeetingApp,
        detectedContext: ResolvedCaptureContext,
        detectedAt: Date,
        deadline: Date,
        duration: TimeInterval,
    ) {
        self.id = id
        self.meetingApp = meetingApp
        self.detectedContext = detectedContext
        self.detectedAt = detectedAt
        self.deadline = deadline
        self.duration = duration
    }
}

enum AutoMeetingConfirmationPolicy {
    static func isIdleForAutomaticMeetingStart(
        currentCapturePurpose: CapturePurpose?,
        isRecording: Bool,
        isStartingRecording: Bool,
    ) -> Bool {
        guard !isRecording, !isStartingRecording else { return false }
        return currentCapturePurpose == nil
    }
}

public extension RecordingManager {
    func setAutomaticMeetingRecordingEnabled(_ isEnabled: Bool) {
        guard let bundleId = Bundle.main.bundleIdentifier,
              !bundleId.lowercased().contains("xctest")
        else {
            return
        }

        if isEnabled {
            enableAutoRecording()
        } else {
            disableAutoRecording()
        }
    }
}

extension RecordingManager {
    /// Enables automatic recording when meeting candidates are detected.
    func enableAutoRecording() {
        guard automaticMeetingRecordingCancellable == nil else {
            meetingDetector.startMonitoring()
            return
        }

        meetingDetector.startMonitoring()
        automaticMeetingRecordingCancellable = meetingDetector.$detectedContext
            .dropFirst()
            .removeDuplicates()
            .sink { @Sendable [weak self] detectedContext in
                Task { @MainActor in
                    guard let self else { return }

                    let isMeetingCaptureActive = self.currentCapturePurpose == .meeting
                        && (self.isRecording || self.isStartingRecording)

                    guard let detectedContext else {
                        self.cancelAutomaticMeetingRecordingConfirmation()
                        if isMeetingCaptureActive {
                            await self.stopRecording()
                        }
                        return
                    }

                    if AutoMeetingConfirmationPolicy.isIdleForAutomaticMeetingStart(
                        currentCapturePurpose: self.currentCapturePurpose,
                        isRecording: self.isRecording,
                        isStartingRecording: self.isStartingRecording,
                    ) {
                        self.scheduleAutomaticMeetingRecordingConfirmation(for: detectedContext)
                    }
                }
            }
    }

    func disableAutoRecording() {
        automaticMeetingRecordingCancellable?.cancel()
        automaticMeetingRecordingCancellable = nil
        cancelAutomaticMeetingRecordingConfirmation()
        meetingDetector.stopMonitoring()
    }

    func scheduleAutomaticMeetingRecordingConfirmation(for detectedContext: ResolvedCaptureContext) {
        if automaticMeetingRecordingConfirmation?.detectedContext == detectedContext {
            return
        }

        automaticMeetingRecordingConfirmationTask?.cancel()

        let detectedAt = Date()
        let duration = AppSettingsStore.shared.automaticAutomaticMeetingRecordingConfirmationDelay.timeInterval
        let confirmation = AutomaticMeetingRecordingConfirmation(
            meetingApp: detectedContext.meetingApp,
            detectedContext: detectedContext,
            detectedAt: detectedAt,
            deadline: detectedAt.addingTimeInterval(duration),
            duration: duration,
        )

        automaticMeetingRecordingConfirmation = confirmation
        automaticMeetingRecordingConfirmationTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(max(0, duration) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled, let self else { return }
            await startConfirmedAutomaticMeetingRecording(confirmation)
        }
    }

    public func cancelAutomaticMeetingRecordingConfirmation() {
        automaticMeetingRecordingConfirmationTask?.cancel()
        automaticMeetingRecordingConfirmationTask = nil
        automaticMeetingRecordingConfirmation = nil
    }

    private func startConfirmedAutomaticMeetingRecording(_ confirmation: AutomaticMeetingRecordingConfirmation) async {
        guard automaticMeetingRecordingConfirmation?.id == confirmation.id else { return }
        guard meetingDetector.detectedContext == confirmation.detectedContext else {
            cancelAutomaticMeetingRecordingConfirmation()
            return
        }
        guard AutoMeetingConfirmationPolicy.isIdleForAutomaticMeetingStart(
            currentCapturePurpose: currentCapturePurpose,
            isRecording: isRecording,
            isStartingRecording: isStartingRecording,
        ) else {
            cancelAutomaticMeetingRecordingConfirmation()
            return
        }

        automaticMeetingRecordingConfirmationTask = nil
        automaticMeetingRecordingConfirmation = nil
        await startCapture(
            purpose: .meeting,
            requestedAt: confirmation.deadline,
            triggerLabel: "recording.start.automatic_meeting_confirmation",
        )
    }
}
