import AppKit
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class DictionaryQuickAddPanelControllerTests: XCTestCase {
    private func skipIfOverlayLifecycleDisabled() throws {
        if ProcessInfo.processInfo.environment["MA_SKIP_OVERLAY_LIFECYCLE_TESTS"] == "1" {
            throw XCTSkip("Overlay lifecycle tests disabled for current runner")
        }
    }

    func testShowDismissReopenDoesNotCrash() throws {
        try skipIfOverlayLifecycleDisabled()

        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = DictionaryQuickAddPanelController.shared

        controller.show()
        XCTAssertTrue(controller.isVisible)

        controller.dismiss()
        XCTAssertFalse(controller.isVisible)

        controller.show()
        XCTAssertTrue(controller.isVisible)

        controller.dismiss()
        XCTAssertFalse(controller.isVisible)
    }

    func testRepeatedShowWhileVisibleRemainsIdempotent() throws {
        try skipIfOverlayLifecycleDisabled()

        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = DictionaryQuickAddPanelController.shared

        controller.show()
        controller.show()
        controller.show()
        XCTAssertTrue(controller.isVisible)

        controller.dismiss()
        controller.dismiss()
        XCTAssertFalse(controller.isVisible)
    }
}
