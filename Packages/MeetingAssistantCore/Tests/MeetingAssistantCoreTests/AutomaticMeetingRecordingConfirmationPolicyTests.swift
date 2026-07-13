import MeetingAssistantCoreDomain
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class AutoMeetingConfirmationPolicyTests: XCTestCase {
    func testIdleMeetingStartEligibilityRequiresNoActiveRecording() {
        XCTAssertTrue(
            AutoMeetingConfirmationPolicy.isIdleForAutomaticMeetingStart(
                currentCapturePurpose: nil,
                isRecording: false,
                isStartingRecording: false,
            ),
        )

        XCTAssertFalse(
            AutoMeetingConfirmationPolicy.isIdleForAutomaticMeetingStart(
                currentCapturePurpose: .meeting,
                isRecording: true,
                isStartingRecording: false,
            ),
        )

        XCTAssertFalse(
            AutoMeetingConfirmationPolicy.isIdleForAutomaticMeetingStart(
                currentCapturePurpose: .meeting,
                isRecording: false,
                isStartingRecording: true,
            ),
        )

        XCTAssertFalse(
            AutoMeetingConfirmationPolicy.isIdleForAutomaticMeetingStart(
                currentCapturePurpose: .dictation,
                isRecording: false,
                isStartingRecording: false,
            ),
        )
    }
}
