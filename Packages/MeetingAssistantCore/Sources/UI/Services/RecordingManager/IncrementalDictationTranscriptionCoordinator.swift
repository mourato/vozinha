@preconcurrency import AVFoundation
import Foundation
import MeetingAssistantCoreAudio
import MeetingAssistantCoreCommon
import MeetingAssistantCoreData
import MeetingAssistantCoreDomain
@preconcurrency import MeetingAssistantCoreInfrastructure

// swiftlint:disable type_name
actor IncrementalDictationTranscriptionCoordinator {
    struct FinalizedResult {
        let response: DomainTranscriptionResponse
        let checkpointID: UUID
        let wallClockDuration: Double
    }

    struct Callbacks {
        let onPreviewTextChanged: @Sendable (String) -> Void
        let onProcessedDurationChanged: @Sendable (Double) -> Void
    }

    private let core: IncrementalTranscriptionCoordinatorCore

    init(
        transcriptionID: UUID,
        meeting: Meeting,
        inputSource: String?,
        storage: any StorageService,
        transcriptionClientBox: RecordingManager.UncheckedTranscriptionServiceBox,
        voiceActivityKernel: any VoiceActivityKernel = RealtimeVoiceActivityWindowAssembler(),
        callbacks: Callbacks,
    ) {
        core = IncrementalTranscriptionCoordinatorCore(
            configuration: .init(
                transcriptionID: transcriptionID,
                meeting: meeting,
                inputSource: inputSource,
                storage: storage,
                transcriptionClientBox: transcriptionClientBox,
                voiceActivityKernel: voiceActivityKernel,
                onPreviewTextChanged: callbacks.onPreviewTextChanged,
                onProcessedDurationChanged: callbacks.onProcessedDurationChanged,
                fallbackLogMessage: "Dictation incremental transcription degraded; full-file fallback required",
            ),
        )
    }

    var checkpointID: UUID {
        get async {
            await core.checkpointID
        }
    }

    var requiresLegacyFallback: Bool {
        get async {
            await core.requiresLegacyFallback
        }
    }

    var fallbackError: Error? {
        get async {
            await core.fallbackError
        }
    }

    var fallbackReason: IncrementalTranscriptionFallbackReason? {
        get async {
            await core.fallbackReason
        }
    }

    func start() async throws {
        try await core.start()
    }

    func append(bufferBox: RecordingManager.SendableIncrementalAudioBufferBox) async {
        await core.append(bufferBox: bufferBox)
    }

    func setHighLoadMode(_ isHighLoad: Bool) async {
        await core.setHighLoadMode(isHighLoad)
    }

    func finish() async throws -> FinalizedResult {
        try await core.finishAccumulation()
        let response = try await core.buildFinalizedResponse()

        return await FinalizedResult(
            response: response,
            checkpointID: core.checkpointID,
            wallClockDuration: core.wallClockElapsedSeconds,
        )
    }

    func cancelAndDiscard() async {
        await core.cancelAndDiscard()
    }
}

// swiftlint:enable type_name
