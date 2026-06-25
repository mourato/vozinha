import MeetingAssistantCoreDomain
@testable import MeetingAssistantCoreAI
import XCTest

@MainActor
final class PostProcessingServiceValidationTests: XCTestCase {
    func testValidateInput_AllowsTranscriptionsOverPreviousCharacterLimit() throws {
        let input = String(repeating: "a", count: 100_001)

        let validated = try PostProcessingService.shared.validateInput(input)

        XCTAssertEqual(validated.count, 100_001)
    }

    func testValidateInput_RejectsEmptyTranscription() {
        XCTAssertThrowsError(try PostProcessingService.shared.validateInput("   \n\t")) { error in
            guard case PostProcessingError.emptyTranscription = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
