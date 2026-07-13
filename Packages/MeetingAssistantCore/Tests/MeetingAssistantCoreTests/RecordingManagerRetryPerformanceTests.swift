import Foundation
@testable import MeetingAssistantCore
import XCTest

@MainActor
extension RecordingManagerTests {
    func testRetryTranscription_PersistsRetryPerformanceAttempt() async throws {
        let manager = try XCTUnwrap(manager)
        let mockStorage = try XCTUnwrap(mockStorage)

        let rawURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try writeRetryTestAudioFile(at: rawURL)
        defer { try? FileManager.default.removeItem(at: rawURL) }

        let transcription = Transcription(
            meeting: Meeting(app: .zoom, capturePurpose: .meeting, audioFilePath: rawURL.path),
            text: "Existing",
            rawText: "Existing",
            processedContent: nil,
            postProcessingPromptId: nil,
            postProcessingPromptTitle: nil,
            language: "en",
            modelName: "test-model",
        )

        await manager.retryTranscription(for: transcription)

        XCTAssertTrue(
            mockStorage.savedModelPerformanceAttempts.contains {
                $0.attemptKind == .retry && $0.stage == .transcription
            },
        )
    }

    private func writeRetryTestAudioFile(at url: URL) throws {
        let data = Data(repeating: 0, count: 256)
        try data.write(to: url)
    }
}
