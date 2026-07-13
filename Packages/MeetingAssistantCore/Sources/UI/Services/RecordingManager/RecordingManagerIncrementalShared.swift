import AVFoundation
import Foundation
import MeetingAssistantCoreAI
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreDomain
import MeetingAssistantCoreInfrastructure
import os.lock

extension RecordingManager {
    struct IncrementalCaptureSupportConfig {
        let expectedPurpose: CapturePurpose
        let expectedSource: RecordingSource
        let incrementalFeatureEnabled: Bool
        let realtimeFeatureEnabled: Bool
        let executionMode: TranscriptionExecutionMode
    }

    final class SendableIncrementalAudioBufferBox: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    final class UncheckedTranscriptionServiceBox: @unchecked Sendable {
        @MainActor private let value: any TranscriptionService

        @MainActor init(_ value: any TranscriptionService) {
            self.value = value
        }

        @MainActor
        func transcribe(samples: [Float]) async throws -> TranscriptionResponse {
            try await value.transcribe(samples: samples)
        }
    }

    final class UncheckedFinalDiarizationServiceBox: @unchecked Sendable {
        @MainActor private let value: any TranscriptionServiceFinalDiarization

        @MainActor init(_ value: any TranscriptionServiceFinalDiarization) {
            self.value = value
        }

        @MainActor
        func diarize(audioURL: URL) async throws -> [SpeakerTimelineSegment] {
            try await value.diarize(audioURL: audioURL)
        }

        @MainActor
        func assignSpeakers(
            to segments: [Transcription.Segment],
            using speakerTimeline: [SpeakerTimelineSegment],
        ) -> [Transcription.Segment] {
            value.assignSpeakers(to: segments, using: speakerTimeline)
        }
    }

    final class IncrementalBufferForwarder: @unchecked Sendable {
        private enum PressureConstants {
            static let highPendingBufferThreshold = 7
            static let lowPendingBufferThreshold = 2
        }

        private struct PressureState {
            var pendingBufferCount = 0
            var isHighLoad = false
        }

        private final class ContinuationStorage: @unchecked Sendable {
            private let lock = OSAllocatedUnfairLock<AsyncStream<SendableIncrementalAudioBufferBox>.Continuation?>(initialState: nil)

            func set(_ continuation: AsyncStream<SendableIncrementalAudioBufferBox>.Continuation?) {
                lock.withLock { $0 = continuation }
            }

            func yield(_ buffer: AVAudioPCMBuffer) {
                let bufferBox = SendableIncrementalAudioBufferBox(buffer: buffer)
                _ = lock.withLock { $0?.yield(bufferBox) }
            }

            func finishAndClear() {
                lock.withLock { continuation in
                    continuation?.finish()
                    continuation = nil
                }
            }
        }

        private let continuationStorage = ContinuationStorage()
        private let pressureLock = OSAllocatedUnfairLock(initialState: PressureState())
        private let onLoadStateChanged: (@Sendable (Bool) -> Void)?
        private var processingTask: Task<Void, Never>?

        init(
            handler: @escaping @Sendable (SendableIncrementalAudioBufferBox) async -> Void,
            onLoadStateChanged: (@Sendable (Bool) -> Void)? = nil,
        ) {
            self.onLoadStateChanged = onLoadStateChanged

            let stream = AsyncStream<SendableIncrementalAudioBufferBox> { continuation in
                continuationStorage.set(continuation)
            }

            processingTask = Task(priority: .userInitiated) {
                for await bufferBox in stream {
                    await handler(bufferBox)
                    emitLoadTransitionIfNeeded {
                        $0.pendingBufferCount = max(0, $0.pendingBufferCount - 1)
                    }
                }
            }
        }

        deinit {
            stop()
        }

        func enqueue(_ buffer: AVAudioPCMBuffer) {
            emitLoadTransitionIfNeeded {
                $0.pendingBufferCount += 1
            }
            continuationStorage.yield(buffer)
        }

        func stop() {
            continuationStorage.finishAndClear()
            processingTask?.cancel()
            processingTask = nil

            emitLoadTransitionIfNeeded {
                $0.pendingBufferCount = 0
            }
        }

        private func emitLoadTransitionIfNeeded(_ mutate: @Sendable (inout PressureState) -> Void) {
            let transition = pressureLock.withLock { state -> Bool? in
                mutate(&state)

                let nextIsHighLoad: Bool = if state.isHighLoad {
                    state.pendingBufferCount > PressureConstants.lowPendingBufferThreshold
                } else {
                    state.pendingBufferCount >= PressureConstants.highPendingBufferThreshold
                }

                guard nextIsHighLoad != state.isHighLoad else {
                    return nil
                }

                state.isHighLoad = nextIsHighLoad
                return nextIsHighLoad
            }

            if let transition {
                onLoadStateChanged?(transition)
            }
        }
    }

    func supportsIncrementalCapture(
        _ config: IncrementalCaptureSupportConfig,
        actualPurpose: CapturePurpose,
        actualSource: RecordingSource,
    ) -> Bool {
        guard actualPurpose == config.expectedPurpose, actualSource == config.expectedSource else { return false }
        guard config.incrementalFeatureEnabled else { return false }
        guard config.realtimeFeatureEnabled else { return false }
        guard let recorder = micRecorder as? AudioRecorder else { return false }
        guard recorder === AudioRecorder.shared else { return false }
        guard let transcriptionClient = transcriptionClient as? TranscriptionClient else { return false }
        return transcriptionClient.supportsIncrementalTranscription(for: config.executionMode)
    }

    func warmupIncrementalTranscriptionIfNeeded() {
        guard let transcriptionClient = transcriptionClient as? TranscriptionClient else { return }
        transcriptionClient.warmupModelIfNeededInBackground()
    }

    func scheduleDeferredIncrementalWarmupIfNeeded(meetingID: UUID) {
        deferredIncrementalWarmupTask?.cancel()

        guard incrementalDictationCoordinator != nil || incrementalMeetingCoordinator != nil else {
            deferredIncrementalWarmupTask = nil
            return
        }

        deferredIncrementalWarmupTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Constants.deferredIncrementalWarmupDelay)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard isRecording, currentMeeting?.id == meetingID else { return }
            warmupIncrementalTranscriptionIfNeeded()
        }
    }

    func cancelDeferredIncrementalWarmup() {
        deferredIncrementalWarmupTask?.cancel()
        deferredIncrementalWarmupTask = nil
    }

    func clearIncrementalBufferForwarder(on recorder: AudioRecorder?) {
        recorder?.onMixedAudioBuffer = nil
        incrementalBufferForwarder?.stop()
        incrementalBufferForwarder = nil
    }

    func installIncrementalBufferForwarder(
        on recorder: AudioRecorder,
        handler: @escaping @Sendable (SendableIncrementalAudioBufferBox) async -> Void,
        onLoadStateChanged: (@Sendable (Bool) -> Void)? = nil,
    ) {
        clearIncrementalBufferForwarder(on: recorder)

        let forwarder = IncrementalBufferForwarder(
            handler: handler,
            onLoadStateChanged: onLoadStateChanged,
        )
        incrementalBufferForwarder = forwarder
        recorder.onMixedAudioBuffer = { [weak forwarder] buffer in
            forwarder?.enqueue(buffer)
        }
    }

    func beginIncrementalFinalizationUI(
        audioURL: URL,
        sessionID: UUID,
    ) async -> Double? {
        let audioDuration = await getAudioDuration(from: audioURL)
        beginVisibleTranscriptionStatus(audioDuration: audioDuration, sessionID: sessionID)
        updateVisibleTranscriptionProgress(
            phase: .processing,
            percentage: Constants.processingProgress,
            sessionID: sessionID,
        )
        return audioDuration
    }

    func finalizeIncrementalPreparedResponse(
        response: DomainTranscriptionResponse,
        checkpointID: UUID,
        session: TranscriptionSessionSnapshot,
        audioDuration: Double?,
        transcriptionDuration: Double,
    ) async throws -> Transcription {
        let settings = AppSettingsStore.shared
        let meetingEntity = makeMeetingEntity(meeting: session.meeting, audioDuration: audioDuration)
        let config = makeUseCaseConfig(session: session, settings: settings)
        let transcriptionIdentity = resolvedTranscriptionPerformanceIdentity(
            capturePurpose: session.meeting.capturePurpose,
        )
        let transcriptionCompletedAt = Date()
        let transcriptionStartedAt = transcriptionCompletedAt.addingTimeInterval(-max(0, transcriptionDuration))

        if shouldDriveSharedTranscriptionState(for: session.id) {
            meetingState = .processing(.generatingOutput)
        }

        let transcriptionEntity = try await transcribeAudioUseCase.finalizePreparedResponse(
            response: response,
            transcriptionID: checkpointID,
            meeting: meetingEntity,
            transcriptionIdentity: transcriptionIdentity,
            inputSource: resolveInputSourceLabel(for: session.meeting, recordingSource: session.recordingSource),
            contextItems: config.postProcessingContextItems,
            vocabularyReplacementRules: settings.vocabularyReplacementRules,
            applyPostProcessing: config.applyPostProcessing,
            postProcessingPrompt: config.postProcessingPrompt,
            defaultPostProcessingPrompt: config.defaultPostProcessingPrompt,
            postProcessingIdentity: config.postProcessingIdentity,
            autoDetectMeetingType: config.autoDetectMeetingType,
            availablePrompts: config.availablePrompts,
            postProcessingContext: config.postProcessingContext,
            kernelMode: config.kernelMode,
            dictationStructuredPostProcessingEnabled: config.dictationStructuredPostProcessingEnabled,
            transcriptionDuration: transcriptionDuration,
            transcriptionStartedAt: transcriptionStartedAt,
            transcriptionCompletedAt: transcriptionCompletedAt,
            onPhaseChange: { [weak self] phase in
                Task { @MainActor [weak self] in
                    self?.handleUseCasePhaseChange(phase, meeting: session.meeting, sessionID: session.id)
                }
            },
        )

        return convertToModel(
            transcriptionEntity,
            audioDuration: audioDuration,
            transcriptionStart: session.meeting.startTime,
        )
    }
}
