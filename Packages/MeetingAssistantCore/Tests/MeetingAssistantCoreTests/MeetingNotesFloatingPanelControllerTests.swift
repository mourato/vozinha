@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class MeetingNotesFloatingPanelControllerTests: XCTestCase {
    func testMaximumScreenHeightRatio() {
        XCTAssertEqual(MeetingNotesFloatingPanelController.maximumScreenHeightRatio, 0.9, accuracy: 0.001)
    }
}
