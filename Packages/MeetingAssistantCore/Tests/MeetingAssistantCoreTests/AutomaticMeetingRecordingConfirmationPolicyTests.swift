import MeetingAssistantCoreDomain
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class AutoMeetingConfirmationPolicyTests: XCTestCase {
    func testIdleMeetingStartEligibilityRequiresNoActiveRecording() {
        XCTAssertTrue(
            isIdleForAutomaticMeetingStart(
                currentCapturePurpose: nil,
                isRecording: false,
                isStartingRecording: false,
            ),
        )

        XCTAssertFalse(
            isIdleForAutomaticMeetingStart(
                currentCapturePurpose: .meeting,
                isRecording: true,
                isStartingRecording: false,
            ),
        )

        XCTAssertFalse(
            isIdleForAutomaticMeetingStart(
                currentCapturePurpose: .meeting,
                isRecording: false,
                isStartingRecording: true,
            ),
        )

        XCTAssertFalse(
            isIdleForAutomaticMeetingStart(
                currentCapturePurpose: .dictation,
                isRecording: false,
                isStartingRecording: false,
            ),
        )
    }
}
