import Foundation

@MainActor
final class RecordingLifecycleCoordinator {
    typealias Action = () async -> Void
    typealias StopRecorders = () async -> (mic: URL?, system: URL?)
    typealias CleanupTemporaryFiles = (_ recordings: (mic: URL?, system: URL?)) async -> Void

    struct StartActions {
        let beginExclusivity: () async -> Bool
        let beginState: () -> Void
        let prepare: () async throws -> Void
    }

    struct StopActions {
        let beforeRelease: (_ recordings: (mic: URL?, system: URL?)) async -> Void
        let finalize: (_ recordings: (mic: URL?, system: URL?)) async throws -> Void
        let handleFailure: (_ error: Error, _ recordings: (mic: URL?, system: URL?)) async -> Void
    }

    struct Operations {
        let stopRecorders: StopRecorders
        let cancelIncremental: Action
        let cancelPostStartTasks: () -> Void
        let cleanupTemporaryFiles: CleanupTemporaryFiles
        let removeMergedAudio: Action
        let resetState: (_ error: Error?, _ transcriptionID: UUID?) async -> Void
        let endExclusivity: Action
        let playStopSound: () -> Void
        let playCancelledSound: () -> Void
    }

    func start(
        isRecording: Bool,
        actions: StartActions,
        operations: Operations,
        handleFailure: (_ error: Error) async -> Void,
    ) async {
        guard !isRecording, await actions.beginExclusivity() else { return }

        actions.beginState()
        do {
            try await actions.prepare()
        } catch {
            await operations.cancelIncremental()
            operations.cancelPostStartTasks()
            await operations.endExclusivity()
            await handleFailure(error)
        }
    }

    func cancel(
        isRecording: Bool,
        isStarting: Bool,
        operations: Operations,
    ) async {
        guard isRecording || isStarting else { return }

        _ = await operations.stopRecorders()
        await operations.cancelIncremental()
        operations.cancelPostStartTasks()
        if isRecording {
            await operations.cleanupTemporaryFiles((mic: nil, system: nil))
            await operations.removeMergedAudio()
        }
        await operations.resetState(nil, nil)
        await operations.endExclusivity()
        operations.playCancelledSound()
    }

    func recorderDidFail(
        _ error: Error,
        isRecording: Bool,
        isStarting: Bool,
        operations: Operations,
    ) async {
        guard isRecording || isStarting else { return }

        let recordings = await operations.stopRecorders()
        operations.cancelPostStartTasks()
        await operations.cancelIncremental()
        await operations.cleanupTemporaryFiles(recordings)
        await operations.removeMergedAudio()
        await operations.resetState(error, nil)
        await operations.endExclusivity()
    }

    func stop(
        isRecording: Bool,
        transcribe: Bool,
        operations: Operations,
        actions: StopActions,
    ) async {
        guard isRecording else { return }

        operations.cancelPostStartTasks()
        let recordings = await operations.stopRecorders()
        await actions.beforeRelease(recordings)
        await operations.endExclusivity()
        operations.playStopSound()

        do {
            try await actions.finalize(recordings)
            if !transcribe {
                await operations.cancelIncremental()
                await operations.resetState(nil, nil)
            }
        } catch {
            await actions.handleFailure(error, recordings)
        }
    }
}
