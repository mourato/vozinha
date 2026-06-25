import Foundation
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreDomain
import XCTest

private final class UseCaseCallbackRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var phasesStorage: [TranscriptionPhase] = []
    private var progressStorage: [Double] = []

    func record(phase: TranscriptionPhase) {
        lock.lock()
        phasesStorage.append(phase)
        lock.unlock()
    }

    func record(progress: Double) {
        lock.lock()
        progressStorage.append(progress)
        lock.unlock()
    }

    func snapshot() -> (phases: [TranscriptionPhase], progress: [Double]) {
        lock.lock()
        defer { lock.unlock() }
        return (phasesStorage, progressStorage)
    }
}

final class TranscribeAudioUseCaseMacroMockingTests: XCTestCase {
    func testExecuteSuccess_SavesTranscription() async throws {
        let transcriptionRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionRepository()
        let storageRepository = makeMacroMockTranscriptionStorageRepository()

        transcriptionRepository.healthCheckHandler = { () async throws -> Bool in true }

        let response = DomainTranscriptionResponse(
            text: "Hello world",
            language: "en",
            durationSeconds: 1.0,
            model: "test-model",
            processedAt: "now"
        )

        transcriptionRepository.transcribeHandler = { _, _ in response }

        var saved: [TranscriptionEntity] = []
        storageRepository.saveTranscriptionHandler = { transcription in
            saved.append(transcription)
        }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionStorageRepository: storageRepository,
            postProcessingRepository: nil
        )

        let meeting = MeetingEntity(app: .googleMeet)
        let audioURL = URL(fileURLWithPath: "/tmp/test.wav")

        let transcription = try await useCase.execute(audioURL: audioURL, meeting: meeting)

        XCTAssertEqual(transcription.text, "Hello world")
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(transcriptionRepository.healthCheckCallCount, 0)
        XCTAssertEqual(transcriptionRepository.transcribeCalls.count, 1)
    }

    func testExecuteSuccess_PersistsModelPerformanceAttempts() async throws {
        let transcriptionRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionRepository()
        let storageRepository = makeMacroMockTranscriptionStorageRepository()
        let postProcessingRepository = MeetingAssistantCoreDomain.MacroMockPostProcessingRepository()

        transcriptionRepository.transcribeHandler = { _, _ in
            DomainTranscriptionResponse(
                text: "Hello world",
                language: "en",
                durationSeconds: 30,
                model: "test-model",
                processedAt: "now"
            )
        }
        postProcessingRepository.processTranscriptionStructured_4Handler = { _, _, _ in
            DomainPostProcessingResult(
                processedText: "Processed",
                canonicalSummary: CanonicalSummary(title: "Processed", summary: "Processed"),
                outputState: .structured
            )
        }

        var savedAttempts: [ModelPerformanceAttempt] = []
        storageRepository.saveTranscriptionHandler = { _ in }
        storageRepository.saveModelPerformanceAttemptHandler = { attempt in
            savedAttempts.append(attempt)
        }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionStorageRepository: storageRepository,
            postProcessingRepository: postProcessingRepository
        )

        _ = try await useCase.execute(
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            meeting: MeetingEntity(app: .unknown, capturePurpose: .dictation),
            transcriptionIdentity: ModelPerformanceModelIdentity(
                providerID: "local",
                providerDisplayName: "Local",
                modelID: "test-model",
                modelDisplayName: "Test Model",
                runtimeKind: .local
            ),
            applyPostProcessing: true,
            postProcessingPrompt: DomainPostProcessingPrompt(title: "Prompt", content: "Prompt"),
            postProcessingIdentity: ModelPerformanceModelIdentity(
                providerID: "openai",
                providerDisplayName: "OpenAI",
                modelID: "gpt-4.1-mini",
                modelDisplayName: "GPT-4.1 Mini",
                runtimeKind: .remote
            ),
            kernelMode: .dictation,
            dictationStructuredPostProcessingEnabled: true
        )

        XCTAssertEqual(savedAttempts.count, 2)
        XCTAssertEqual(savedAttempts.map(\.stage), [.transcription, .postProcessing])
        XCTAssertEqual(savedAttempts.map(\.status), [.succeeded, .succeeded])
    }

    func testExecute_EmitsPhaseAndProgressCallbacks() async throws {
        let transcriptionRepository = MeetingAssistantCoreDomain.MacroMockTranscriptionRepository()
        let storageRepository = makeMacroMockTranscriptionStorageRepository()
        let postProcessingRepository = MeetingAssistantCoreDomain.MacroMockPostProcessingRepository()

        transcriptionRepository.healthCheckHandler = { () async throws -> Bool in true }
        transcriptionRepository.transcribeHandler = { _, onProgress in
            onProgress?(20)
            onProgress?(55)
            onProgress?(100)
            return DomainTranscriptionResponse(
                text: "Hello world",
                language: "en",
                durationSeconds: 1.0,
                model: "test-model",
                processedAt: "now"
            )
        }
        postProcessingRepository.processTranscriptionStructured_4Handler = { _, _, _ in
            DomainPostProcessingResult(
                processedText: "Processed",
                canonicalSummary: CanonicalSummary(title: "Processed", summary: "Processed"),
                outputState: .structured
            )
        }
        storageRepository.saveTranscriptionHandler = { _ in }

        let useCase = TranscribeAudioUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionStorageRepository: storageRepository,
            postProcessingRepository: postProcessingRepository
        )

        let recorder = UseCaseCallbackRecorder()

        _ = try await useCase.execute(
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            meeting: MeetingEntity(app: .googleMeet),
            applyPostProcessing: true,
            postProcessingPrompt: DomainPostProcessingPrompt(title: "Prompt", content: "Prompt"),
            onPhaseChange: { phase in
                recorder.record(phase: phase)
            },
            onTranscriptionProgress: { progress in
                recorder.record(progress: progress)
            }
        )

        let snapshot = recorder.snapshot()

        XCTAssertEqual(snapshot.phases, [.preparing, .processing, .postProcessing, .completed])
        XCTAssertEqual(snapshot.progress, [20, 55, 100])
    }
}
