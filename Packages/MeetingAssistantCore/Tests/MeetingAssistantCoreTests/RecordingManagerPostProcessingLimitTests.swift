@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI
import XCTest

extension RecordingManagerTests {
    func testRunPostProcessing_WithLongManualInputPassesThroughToService() async throws {
        let manager = try XCTUnwrap(manager)
        let postProcessing = try XCTUnwrap(mockPostProcessing)
        let longInput = String(repeating: "Manual meeting segment. ", count: 5_500)

        let result = await manager.runPostProcessing(
            postProcessingInput: longInput,
            prompt: PostProcessingPrompt(title: "Summarize", promptText: "Summarize this", isActive: true),
            settings: AppSettingsStore.shared,
            qualityProfile: nil,
            kernelMode: .meeting,
            dictationStructuredPostProcessingEnabled: false,
            contextMetadata: "",
        )

        XCTAssertGreaterThan(longInput.count, 100_000)
        XCTAssertEqual(postProcessing.processTranscriptionCallCount, 1)
        XCTAssertEqual(postProcessing.lastProcessText, longInput)
        XCTAssertNil(result.failureReason)
        XCTAssertNotNil(result.processedContent)
    }
}
