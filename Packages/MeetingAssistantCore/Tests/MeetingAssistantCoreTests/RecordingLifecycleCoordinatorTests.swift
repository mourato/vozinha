import Foundation
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class RecordingLifecycleCoordinatorTests: XCTestCase {
    func testCancellationDuringStartupCleansStateAndExclusivity() async {
        let state = RecordingLifecycleTestState()
        state.captureActive = true
        state.exclusive = true
        state.temporaryTaskActive = true

        await RecordingLifecycleCoordinator().cancel(
            isRecording: false,
            isStarting: true,
            operations: makeOperations(state),
        )

        XCTAssertTrue(state.reset)
        XCTAssertFalse(state.captureActive)
        XCTAssertFalse(state.exclusive)
        XCTAssertFalse(state.temporaryTaskActive)
        XCTAssertEqual(state.events, ["stopRecorders", "cancelIncremental", "cancelPostStartTasks", "resetState", "endExclusivity"])
    }

    func testCancellationDuringRecordingCleansStateAndFiles() async {
        let state = RecordingLifecycleTestState()
        state.captureActive = true
        state.exclusive = true
        state.incrementalActive = true
        state.temporaryFilesExist = true
        state.mergedAudioExists = true

        await RecordingLifecycleCoordinator().cancel(
            isRecording: true,
            isStarting: false,
            operations: makeOperations(state),
        )

        XCTAssertTrue(state.reset)
        XCTAssertFalse(state.captureActive)
        XCTAssertFalse(state.exclusive)
        XCTAssertFalse(state.temporaryFilesExist)
        XCTAssertFalse(state.mergedAudioExists)
        XCTAssertFalse(state.incrementalActive)
    }

    func testStopWithoutTranscriptionCancelsIncrementalBeforeReset() async {
        let state = RecordingLifecycleTestState()
        state.captureActive = true
        state.exclusive = true
        state.incrementalActive = true

        await RecordingLifecycleCoordinator().stop(
            isRecording: true,
            transcribe: false,
            operations: makeOperations(state),
            actions: .init(
                beforeRelease: { _ in state.events.append("beforeRelease") },
                finalize: { _ in state.events.append("finalize") },
                handleFailure: { _ in XCTFail("Unexpected finalization failure") },
            ),
        )

        XCTAssertFalse(state.incrementalActive)
        XCTAssertTrue(state.reset)
        XCTAssertEqual(state.events, ["cancelPostStartTasks", "stopRecorders", "beforeRelease", "endExclusivity", "finalize", "cancelIncremental", "resetState"])
    }

    func testStopWithTranscriptionPreservesFullFileHandoff() async {
        let state = RecordingLifecycleTestState()
        state.captureActive = true
        state.exclusive = true

        await RecordingLifecycleCoordinator().stop(
            isRecording: true,
            transcribe: true,
            operations: makeOperations(state),
            actions: .init(
                beforeRelease: { _ in state.events.append("beforeRelease") },
                finalize: { _ in state.events.append("fullFileHandoff") },
                handleFailure: { _ in XCTFail("Unexpected finalization failure") },
            ),
        )

        XCTAssertTrue(state.events.contains("fullFileHandoff"))
        XCTAssertFalse(state.reset)
        XCTAssertFalse(state.events.contains("cancelIncremental"))
        XCTAssertFalse(state.exclusive)
    }

    func testFinalizationFailureResetsStateAndReleasesExclusivity() async {
        let state = RecordingLifecycleTestState()
        state.captureActive = true
        state.exclusive = true

        await RecordingLifecycleCoordinator().stop(
            isRecording: true,
            transcribe: true,
            operations: makeOperations(state),
            actions: .init(
                beforeRelease: { _ in state.events.append("beforeRelease") },
                finalize: { _ in throw RecordingLifecycleTestError.finalizationFailed },
                handleFailure: { _ in
                    state.events.append("handleFailure")
                    state.captureActive = false
                    state.reset = true
                },
            ),
        )

        XCTAssertTrue(state.reset)
        XCTAssertFalse(state.captureActive)
        XCTAssertFalse(state.exclusive)
        XCTAssertTrue(state.events.contains("handleFailure"))
    }

    func testUnexpectedRecorderFailureStopsCaptureAndCleansFiles() async {
        let state = RecordingLifecycleTestState()
        state.captureActive = true
        state.exclusive = true
        state.incrementalActive = true
        state.temporaryTaskActive = true
        state.temporaryFilesExist = true
        state.mergedAudioExists = true

        await RecordingLifecycleCoordinator().recorderDidFail(
            RecordingLifecycleTestError.finalizationFailed,
            isRecording: true,
            isStarting: false,
            operations: makeOperations(state),
        )

        XCTAssertTrue(state.reset)
        XCTAssertFalse(state.captureActive)
        XCTAssertFalse(state.exclusive)
        XCTAssertFalse(state.incrementalActive)
        XCTAssertFalse(state.temporaryTaskActive)
        XCTAssertFalse(state.temporaryFilesExist)
        XCTAssertFalse(state.mergedAudioExists)
        XCTAssertEqual(state.events, ["stopRecorders", "cancelPostStartTasks", "cancelIncremental", "cleanupTemporaryFiles", "removeMergedAudio", "resetState", "endExclusivity"])
    }
}

private final class RecordingLifecycleTestState {
    var events: [String] = []
    var captureActive = false
    var exclusive = false
    var incrementalActive = false
    var temporaryFilesExist = false
    var temporaryTaskActive = false
    var mergedAudioExists = false
    var reset = false
}

private enum RecordingLifecycleTestError: Error {
    case finalizationFailed
}

private func makeOperations(_ state: RecordingLifecycleTestState) -> RecordingLifecycleCoordinator.Operations {
    RecordingLifecycleCoordinator.Operations(
        stopRecorders: {
            state.events.append("stopRecorders")
            state.captureActive = false
            return (URL(fileURLWithPath: "/tmp/mic.m4a"), URL(fileURLWithPath: "/tmp/system.m4a"))
        },
        cancelIncremental: {
            state.events.append("cancelIncremental")
            state.incrementalActive = false
        },
        cancelPostStartTasks: {
            state.events.append("cancelPostStartTasks")
            state.temporaryTaskActive = false
        },
        cleanupTemporaryFiles: {
            state.events.append("cleanupTemporaryFiles")
            state.temporaryFilesExist = false
        },
        removeMergedAudio: {
            state.events.append("removeMergedAudio")
            state.mergedAudioExists = false
        },
        resetState: { _, _ in
            state.events.append("resetState")
            state.captureActive = false
            state.reset = true
        },
        endExclusivity: {
            state.events.append("endExclusivity")
            state.exclusive = false
        },
        playStopSound: {},
        playCancelledSound: {},
    )
}
