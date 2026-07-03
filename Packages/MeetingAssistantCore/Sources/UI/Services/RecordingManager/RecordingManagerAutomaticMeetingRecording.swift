import Combine
import Foundation
import MeetingAssistantCoreDomain

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
        automaticMeetingRecordingCancellable = meetingDetector.$detectedMeeting
            .dropFirst()
            .removeDuplicates()
            .sink { @Sendable [weak self] detected in
                Task { @MainActor in
                    guard let self else { return }

                    let isMeetingCaptureActive = self.currentCapturePurpose == .meeting
                        && (self.isRecording || self.isStartingRecording)

                    if detected != nil, !self.isRecording, !self.isStartingRecording {
                        await self.startCapture(purpose: .meeting)
                    } else if detected == nil, isMeetingCaptureActive {
                        await self.stopRecording()
                    }
                }
            }
    }

    func disableAutoRecording() {
        automaticMeetingRecordingCancellable?.cancel()
        automaticMeetingRecordingCancellable = nil
        meetingDetector.stopMonitoring()
    }
}
