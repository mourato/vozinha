import Foundation
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class RecordingLifecycleCoordinatorTests: XCTestCase {
    func testCancellationDuringStartupCleansStateAndExclusivity() async {
        let state = RecordingLifecycleTestState()
        state.captureActive = true
        state.exclusive = true
        state.temporaryFilesExist = true
        state.temporaryTaskActive = true
        state.mergedAudioExists = true

        await RecordingLifecycleCoordinator().cancel(
            isRecording: false,
            isStarting: true,
            operations: makeOperations(state),
        )

        XCTAssertTrue(state.reset)
        XCTAssertFalse(state.captureActive)
        XCTAssertFalse(state.exclusive)
        XCTAssertFalse(state.temporaryFilesExist)
        XCTAssertFalse(state.temporaryTaskActive)
        XCTAssertFalse(state.mergedAudioExists)
        XCTAssertEqual(state.events, ["stopRecorders", "cancelIncremental", "cancelPostStartTasks", "cleanupTemporaryFiles", "removeMergedAudio", "resetState", "endExclusivity"])
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
                handleFailure: { _, _ in XCTFail("Unexpected finalization failure") },
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
                handleFailure: { _, _ in XCTFail("Unexpected finalization failure") },
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
                handleFailure: { _, _ in
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

    func testOverlappingCancellationAllowsOnlyOneTransition() async {
        let state = DelayedRecordingLifecycleTestState()
        let stopStarted = expectation(description: "First cancellation stops recorders")
        let operations = makeDelayedCancellationOperations(state, stopStarted: stopStarted)
        let coordinator = RecordingLifecycleCoordinator()
        let firstCancellation = Task { @MainActor in
            await coordinator.cancel(
                isRecording: true,
                isStarting: false,
                operations: operations,
            )
        }

        await fulfillment(of: [stopStarted], timeout: 1)
        await coordinator.cancel(
            isRecording: true,
            isStarting: false,
            operations: operations,
        )

        XCTAssertEqual(state.stopCalls, 1)
        XCTAssertEqual(state.cleanupCalls, 0)

        state.stopContinuation?.resume(returning: (mic: nil, system: nil))
        await firstCancellation.value

        XCTAssertEqual(state.stopCalls, 1)
        XCTAssertEqual(state.cleanupCalls, 1)
        XCTAssertEqual(state.resetCalls, 1)
        XCTAssertEqual(state.endExclusivityCalls, 1)
        XCTAssertFalse(state.exclusive)
    }

    func testCancellationDuringAwaitedStartPreventsCommitAndCleansOnce() async {
        let state = DelayedStartLifecycleTestState()
        let prepareStarted = expectation(description: "Start preparation is awaiting")
        let operations = makeDelayedStartOperations(state)
        let coordinator = RecordingLifecycleCoordinator()
        let startTask = Task { @MainActor in
            await coordinator.start(
                isRecording: false,
                actions: .init(
                    beginExclusivity: {
                        state.beginExclusivityCalls += 1
                        return true
                    },
                    beginState: {
                        state.beginStateCalls += 1
                    },
                    prepare: {
                        await withCheckedContinuation { continuation in
                            state.prepareContinuation = continuation
                            prepareStarted.fulfill()
                        }
                    },
                    commit: { _ in
                        state.commitCalls += 1
                    },
                ),
                operations: operations,
                handleFailure: { _ in
                    state.handleFailureCalls += 1
                },
            )
        }

        await fulfillment(of: [prepareStarted], timeout: 1)
        await coordinator.cancel(
            isRecording: false,
            isStarting: true,
            operations: operations,
        )

        state.prepareContinuation?.resume(returning: URL(fileURLWithPath: "/tmp/prepared.wav"))
        await startTask.value

        XCTAssertEqual(state.beginExclusivityCalls, 1)
        XCTAssertEqual(state.beginStateCalls, 1)
        XCTAssertEqual(state.commitCalls, 0)
        XCTAssertEqual(state.handleFailureCalls, 0)
        XCTAssertEqual(state.stopRecordersCalls, 1)
        XCTAssertEqual(state.cleanupCalls, 1)
        XCTAssertEqual(state.removeMergedAudioCalls, 1)
        XCTAssertEqual(state.resetCalls, 1)
        XCTAssertEqual(state.endExclusivityCalls, 1)
        XCTAssertEqual(state.playCancelledCalls, 1)
        XCTAssertFalse(state.exclusive)
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
        cleanupTemporaryFiles: { _ in
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

private final class DelayedRecordingLifecycleTestState {
    var stopCalls = 0
    var cleanupCalls = 0
    var resetCalls = 0
    var endExclusivityCalls = 0
    var exclusive = true
    var stopContinuation: CheckedContinuation<(mic: URL?, system: URL?), Never>?
}

private func makeDelayedCancellationOperations(
    _ state: DelayedRecordingLifecycleTestState,
    stopStarted: XCTestExpectation,
) -> RecordingLifecycleCoordinator.Operations {
    RecordingLifecycleCoordinator.Operations(
        stopRecorders: {
            state.stopCalls += 1
            stopStarted.fulfill()
            return await withCheckedContinuation { continuation in
                state.stopContinuation = continuation
            }
        },
        cancelIncremental: {},
        cancelPostStartTasks: {},
        cleanupTemporaryFiles: { _ in
            state.cleanupCalls += 1
        },
        removeMergedAudio: {},
        resetState: { _, _ in
            state.resetCalls += 1
        },
        endExclusivity: {
            state.endExclusivityCalls += 1
            state.exclusive = false
        },
        playStopSound: {},
        playCancelledSound: {},
    )
}

private final class DelayedStartLifecycleTestState {
    var beginExclusivityCalls = 0
    var beginStateCalls = 0
    var commitCalls = 0
    var handleFailureCalls = 0
    var stopRecordersCalls = 0
    var cleanupCalls = 0
    var removeMergedAudioCalls = 0
    var resetCalls = 0
    var endExclusivityCalls = 0
    var playCancelledCalls = 0
    var exclusive = true
    var prepareContinuation: CheckedContinuation<URL, Never>?
}

private func makeDelayedStartOperations(_ state: DelayedStartLifecycleTestState) -> RecordingLifecycleCoordinator.Operations {
    RecordingLifecycleCoordinator.Operations(
        stopRecorders: {
            state.stopRecordersCalls += 1
            return (
                mic: URL(fileURLWithPath: "/tmp/start-cancel-mic.m4a"),
                system: URL(fileURLWithPath: "/tmp/start-cancel-system.m4a"),
            )
        },
        cancelIncremental: {},
        cancelPostStartTasks: {},
        cleanupTemporaryFiles: { _ in
            state.cleanupCalls += 1
        },
        removeMergedAudio: {
            state.removeMergedAudioCalls += 1
        },
        resetState: { _, _ in
            state.resetCalls += 1
        },
        endExclusivity: {
            state.endExclusivityCalls += 1
            state.exclusive = false
        },
        playStopSound: {},
        playCancelledSound: {
            state.playCancelledCalls += 1
        },
    )
}
