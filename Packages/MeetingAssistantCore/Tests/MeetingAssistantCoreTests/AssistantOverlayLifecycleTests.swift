import AppKit
@testable import MeetingAssistantCore
import XCTest

@MainActor
final class AssistantOverlayLifecycleTests: XCTestCase {
    private func skipIfOverlayLifecycleDisabled() throws {
        if ProcessInfo.processInfo.environment["MA_SKIP_OVERLAY_LIFECYCLE_TESTS"] == "1" {
            throw XCTSkip("Overlay lifecycle tests disabled for current runner")
        }
    }

    func testFloatingIndicatorRapidShowHideDoesNotCrash() async throws {
        try skipIfOverlayLifecycleDisabled()

        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = FloatingRecordingIndicatorController()

        for _ in 0..<20 {
            controller.show(mode: .recording)
            controller.hide()
            controller.show(mode: .processing)
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        controller.hide()
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertFalse(controller.isVisible)
    }

    func testFloatingIndicatorRenderStateShowUpdateHideDoesNotCrash() async throws {
        try skipIfOverlayLifecycleDisabled()

        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = FloatingRecordingIndicatorController()
        let meetingState = RecordingIndicatorRenderState(mode: .recording, kind: .meeting, meetingType: .standup)
        let processingState = meetingState.with(mode: .processing)

        controller.show(renderState: meetingState)
        controller.update(renderState: processingState)
        controller.hide()

        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertFalse(controller.isVisible)
    }

    func testFloatingIndicatorAssistantIntegrationRenderStateShowUpdateHideDoesNotCrash() async throws {
        try skipIfOverlayLifecycleDisabled()

        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = FloatingRecordingIndicatorController()
        let integrationID = UUID()
        let recordingState = RecordingIndicatorRenderState(
            mode: .recording,
            kind: .assistantIntegration,
            assistantIntegrationID: integrationID,
        )
        let processingState = recordingState.with(mode: .processing)

        controller.show(renderState: recordingState)
        controller.update(renderState: processingState)
        controller.hide()

        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertFalse(controller.isVisible)
    }

    func testAssistantBorderRapidShowHideDoesNotCrash() async throws {
        try skipIfOverlayLifecycleDisabled()

        guard NSScreen.main != nil else {
            throw XCTSkip("No main screen available in current test environment")
        }

        let controller = AssistantScreenBorderController()

        for _ in 0..<20 {
            controller.show()
            controller.hide()
            controller.show()
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        controller.hide()
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertFalse(controller.isVisible)
    }
}
