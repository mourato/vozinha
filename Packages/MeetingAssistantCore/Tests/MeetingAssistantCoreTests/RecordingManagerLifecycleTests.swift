import Foundation
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
extension RecordingManagerTests {
    func testStopWithoutTranscriptionUsesRealLifecycleCleanup() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockStorage = try XCTUnwrap(mockStorage)

        await manager.startRecording()
        XCTAssertTrue(manager.isRecording)

        await manager.stopRecording(transcribe: false)

        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertNil(manager.currentMeeting)
        XCTAssertNil(manager.currentCapturePurpose)
        let micURL = await manager.getMicAudioURL()
        let systemURL = await manager.getSystemAudioURL()
        XCTAssertNil(micURL)
        XCTAssertNil(systemURL)
        XCTAssertTrue(mockStorage.cleanupTemporaryFilesCalled)
        let activeMode = await RecordingExclusivityCoordinator.shared.activeRecordingMode()
        XCTAssertNil(activeMode)
    }

    func testStartFailureCleansRecorderFilesStateContextAndExclusivity() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockStorage = try XCTUnwrap(mockStorage)

        let micURL = FileManager.default.temporaryDirectory.appendingPathComponent("start-failure-mic-\(UUID().uuidString).m4a")
        let systemURL = FileManager.default.temporaryDirectory.appendingPathComponent("start-failure-system-\(UUID().uuidString).m4a")
        let mergedURL = mockStorage.recordingsDirectory.appendingPathComponent("mock_merged.wav")
        try Data([1]).write(to: micURL)
        try Data([2]).write(to: systemURL)
        try FileManager.default.createDirectory(
            at: mockStorage.recordingsDirectory,
            withIntermediateDirectories: true,
        )
        try Data([3]).write(to: mergedURL)
        mockMic.currentRecordingURL = micURL
        mockSystem.currentRecordingURL = systemURL
        mockMic.isRecording = true
        mockSystem.isRecording = true
        mockMic.shouldFailStart = true

        await manager.startRecording()

        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
        XCTAssertEqual(mockSystem.stopRecordingCalledCount, 1)
        XCTAssertTrue(mockStorage.cleanupTemporaryFilesCalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: micURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: systemURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: mergedURL.path))
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertNil(manager.currentMeeting)
        XCTAssertNil(manager.currentCapturePurpose)
        XCTAssertNil(manager.postProcessingContext)
        XCTAssertTrue(manager.postProcessingContextItems.isEmpty)
        XCTAssertNotNil(manager.lastError)
        guard case .failed = manager.meetingState else {
            return XCTFail("Expected start failure to leave the meeting in a failed state")
        }
        let micURLAfter = await manager.getMicAudioURL()
        let systemURLAfter = await manager.getSystemAudioURL()
        let mergedURLAfter = await manager.getMergedAudioURL()
        let activeMode = await RecordingExclusivityCoordinator.shared.activeRecordingMode()
        XCTAssertNil(micURLAfter)
        XCTAssertNil(systemURLAfter)
        XCTAssertNil(mergedURLAfter)
        XCTAssertNil(activeMode)
    }

    func testCancelRecordingDuringStartupCleansReturnedFilesAndMergedState() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockStorage = try XCTUnwrap(mockStorage)

        let micURL = FileManager.default.temporaryDirectory.appendingPathComponent("startup-cancel-mic-\(UUID().uuidString).m4a")
        let systemURL = FileManager.default.temporaryDirectory.appendingPathComponent("startup-cancel-system-\(UUID().uuidString).m4a")
        let mergedURL = FileManager.default.temporaryDirectory.appendingPathComponent("startup-cancel-merged-\(UUID().uuidString).m4a")
        try Data([1]).write(to: micURL)
        try Data([2]).write(to: systemURL)
        try Data([3]).write(to: mergedURL)
        mockMic.currentRecordingURL = micURL
        mockSystem.currentRecordingURL = systemURL
        manager.isStartingRecording = true
        manager.currentCapturePurpose = .dictation
        manager.currentMeeting = Meeting(app: .unknown, capturePurpose: .dictation)
        await manager.recordingActor.setMergedAudioURL(mergedURL)

        let acquired = await RecordingExclusivityCoordinator.shared.beginRecording(mode: .dictation)
        XCTAssertTrue(acquired)

        await manager.cancelRecording()

        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
        XCTAssertEqual(mockSystem.stopRecordingCalledCount, 1)
        XCTAssertTrue(mockStorage.cleanupTemporaryFilesCalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: micURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: systemURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: mergedURL.path))
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertNil(manager.currentMeeting)
        XCTAssertNil(manager.currentCapturePurpose)
        XCTAssertEqual(manager.meetingState, .idle)
        let micURLAfter = await manager.getMicAudioURL()
        let systemURLAfter = await manager.getSystemAudioURL()
        let mergedURLAfter = await manager.getMergedAudioURL()
        XCTAssertNil(micURLAfter)
        XCTAssertNil(systemURLAfter)
        XCTAssertNil(mergedURLAfter)
        let activeMode = await RecordingExclusivityCoordinator.shared.activeRecordingMode()
        XCTAssertNil(activeMode)
    }

    func testCancelRecordingWhileStartOperationIsInFlightPreventsCommitBeforeStartupState() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockStorage = try XCTUnwrap(mockStorage)

        var beginExclusivityContinuation: CheckedContinuation<Bool, Never>?
        var commitCalled = false
        manager.isStartOperationInFlight = true
        defer { manager.isStartOperationInFlight = false }

        let exclusivityStarted = expectation(description: "Start is awaiting exclusivity")
        let startTask = Task { @MainActor in
            await manager.lifecycleCoordinator.start(
                isRecording: false,
                actions: .init(
                    beginExclusivity: {
                        await withCheckedContinuation { continuation in
                            beginExclusivityContinuation = continuation
                            exclusivityStarted.fulfill()
                        }
                    },
                    beginState: {
                        manager.isStartingRecording = true
                    },
                    prepare: {
                        URL(fileURLWithPath: "/tmp/start-before-state-cancel.wav")
                    },
                    commit: { _ in
                        commitCalled = true
                    },
                ),
                operations: manager.lifecycleOperations,
                handleFailure: { _ in
                    XCTFail("Unexpected start failure")
                },
            )
            manager.isStartOperationInFlight = false
        }

        await fulfillment(of: [exclusivityStarted], timeout: 1)
        XCTAssertFalse(manager.isStartingRecording)

        await manager.cancelRecording()

        beginExclusivityContinuation?.resume(returning: true)
        await startTask.value

        XCTAssertFalse(commitCalled)
        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
        XCTAssertEqual(mockSystem.stopRecordingCalledCount, 1)
        XCTAssertTrue(mockStorage.cleanupTemporaryFilesCalled)
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertEqual(manager.meetingState, .idle)
    }

    func testStopRecordingFinalizationFailureCleansReturnedFilesStateAndExclusivity() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockStorage = try XCTUnwrap(mockStorage)

        let settings = AppSettingsStore.shared
        let originalMergeSetting = settings.shouldMergeAudioFiles
        settings.shouldMergeAudioFiles = false
        defer { settings.shouldMergeAudioFiles = originalMergeSetting }

        let acquired = await RecordingExclusivityCoordinator.shared.beginRecording(mode: .dictation)
        XCTAssertTrue(acquired)
        manager.isRecording = true
        manager.currentCapturePurpose = .dictation
        manager.currentMeeting = Meeting(app: .unknown, capturePurpose: .dictation)

        let mergedURL = FileManager.default.temporaryDirectory.appendingPathComponent("finalization-merged-\(UUID().uuidString).m4a")
        let systemURL = FileManager.default.temporaryDirectory.appendingPathComponent("finalization-system-\(UUID().uuidString).m4a")
        try Data([1]).write(to: mergedURL)
        try Data([2]).write(to: systemURL)
        mockMic.currentRecordingURL = nil
        mockSystem.currentRecordingURL = systemURL
        await manager.recordingActor.setMergedAudioURL(mergedURL)

        await manager.stopRecording(transcribe: false)

        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
        XCTAssertEqual(mockSystem.stopRecordingCalledCount, 1)
        XCTAssertTrue(mockStorage.cleanupTemporaryFilesCalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: systemURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: mergedURL.path))
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertNil(manager.currentMeeting)
        XCTAssertNil(manager.currentCapturePurpose)
        let mergedURLAfter = await manager.getMergedAudioURL()
        let activeMode = await RecordingExclusivityCoordinator.shared.activeRecordingMode()
        XCTAssertNil(mergedURLAfter)
        XCTAssertNil(activeMode)
    }

    func testCancelRecordingCleansReturnedFilesWhenActorHasNoRecorderURLs() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockStorage = try XCTUnwrap(mockStorage)

        let acquired = await RecordingExclusivityCoordinator.shared.beginRecording(mode: .dictation)
        XCTAssertTrue(acquired)
        manager.isRecording = true
        manager.currentCapturePurpose = .dictation
        manager.currentMeeting = Meeting(app: .unknown, capturePurpose: .dictation)
        let micURL = FileManager.default.temporaryDirectory.appendingPathComponent("cancel-mic-\(UUID().uuidString).m4a")
        let systemURL = FileManager.default.temporaryDirectory.appendingPathComponent("cancel-system-\(UUID().uuidString).m4a")
        try Data([1]).write(to: micURL)
        try Data([2]).write(to: systemURL)
        mockMic.isRecording = true
        mockMic.currentRecordingURL = micURL
        mockSystem.isRecording = true
        mockSystem.currentRecordingURL = systemURL

        await manager.cancelRecording()

        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
        XCTAssertEqual(mockSystem.stopRecordingCalledCount, 1)
        XCTAssertTrue(mockStorage.cleanupTemporaryFilesCalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: micURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: systemURL.path))
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertNil(manager.currentMeeting)
        XCTAssertNil(manager.currentCapturePurpose)
        XCTAssertEqual(manager.meetingState, .idle)
        let activeMode = await RecordingExclusivityCoordinator.shared.activeRecordingMode()
        XCTAssertNil(activeMode)
    }

    func testUnexpectedRecorderFailureThroughManagerCleansReturnedFilesStateAndExclusivity() async throws {
        let manager = try XCTUnwrap(manager)
        let mockMic = try XCTUnwrap(mockMic)
        let mockSystem = try XCTUnwrap(mockSystem)
        let mockStorage = try XCTUnwrap(mockStorage)

        let acquired = await RecordingExclusivityCoordinator.shared.beginRecording(mode: .dictation)
        XCTAssertTrue(acquired)
        manager.isRecording = true
        manager.currentCapturePurpose = .dictation
        manager.currentMeeting = Meeting(app: .unknown, capturePurpose: .dictation)
        let mergedURL = FileManager.default.temporaryDirectory.appendingPathComponent("lifecycle-merged-\(UUID().uuidString).m4a")
        let micURL = FileManager.default.temporaryDirectory.appendingPathComponent("lifecycle-mic-\(UUID().uuidString).m4a")
        let systemURL = FileManager.default.temporaryDirectory.appendingPathComponent("lifecycle-system-\(UUID().uuidString).m4a")
        try Data([1]).write(to: mergedURL)
        try Data([2]).write(to: micURL)
        try Data([3]).write(to: systemURL)
        mockMic.isRecording = true
        mockMic.currentRecordingURL = micURL
        mockSystem.isRecording = true
        mockSystem.currentRecordingURL = systemURL
        await manager.recordingActor.setMergedAudioURL(mergedURL)

        await manager.lifecycleCoordinator.recorderDidFail(
            NSError(domain: "RecordingManagerTests", code: 1),
            isRecording: true,
            isStarting: false,
            operations: manager.lifecycleOperations,
        )

        XCTAssertEqual(mockMic.stopRecordingCalledCount, 1)
        XCTAssertEqual(mockSystem.stopRecordingCalledCount, 1)
        XCTAssertTrue(mockStorage.cleanupTemporaryFilesCalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: micURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: systemURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: mergedURL.path))
        XCTAssertFalse(manager.isRecording)
        XCTAssertFalse(manager.isStartingRecording)
        XCTAssertNil(manager.currentMeeting)
        XCTAssertNil(manager.currentCapturePurpose)
        let micURLAfter = await manager.getMicAudioURL()
        let systemURLAfter = await manager.getSystemAudioURL()
        let mergedURLAfter = await manager.getMergedAudioURL()
        let activeMode = await RecordingExclusivityCoordinator.shared.activeRecordingMode()
        XCTAssertNil(micURLAfter)
        XCTAssertNil(systemURLAfter)
        XCTAssertNil(mergedURLAfter)
        XCTAssertNil(activeMode)
    }
}
