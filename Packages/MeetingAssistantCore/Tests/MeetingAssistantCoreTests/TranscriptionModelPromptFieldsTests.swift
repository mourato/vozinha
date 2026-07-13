@testable import MeetingAssistantCore
import XCTest

final class TranscriptionModelPromptFieldsTests: XCTestCase {
    func testInit_PreservesPostProcessingRequestPrompts() {
        let transcription = Transcription(
            meeting: Meeting(app: .unknown),
            text: "processed",
            rawText: "raw",
            postProcessingRequestSystemPrompt: "system prompt",
            postProcessingRequestUserPrompt: "user prompt",
        )

        XCTAssertEqual(transcription.postProcessingRequestSystemPrompt, "system prompt")
        XCTAssertEqual(transcription.postProcessingRequestUserPrompt, "user prompt")
    }
}
