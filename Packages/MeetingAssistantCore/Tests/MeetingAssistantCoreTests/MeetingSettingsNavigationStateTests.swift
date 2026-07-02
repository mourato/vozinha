@testable import MeetingAssistantCore
import XCTest

final class MeetingSettingsNavigationStateTests: XCTestCase {
    func testInitialState() {
        let state = MeetingSettingsNavigationState()

        XCTAssertEqual(state.currentRoute, .root)
        XCTAssertFalse(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
    }

    func testBackMovesToRootAndPreservesForwardRoute() {
        for route in drillDownRoutes {
            var state = MeetingSettingsNavigationState(currentRoute: route)

            _ = state.goBack()

            XCTAssertEqual(state.currentRoute, .root)
            XCTAssertFalse(state.canGoBack)
            XCTAssertTrue(state.canGoForward)
            XCTAssertEqual(state.forwardRoute, route)
        }
    }

    func testForwardRestoresDrillDownRouteAndClearsForwardRoute() {
        for route in drillDownRoutes {
            var state = MeetingSettingsNavigationState(
                currentRoute: .root,
                forwardRoute: route
            )

            _ = state.goForward()

            XCTAssertEqual(state.currentRoute, route)
            XCTAssertTrue(state.canGoBack)
            XCTAssertFalse(state.canGoForward)
            XCTAssertNil(state.forwardRoute)
        }
    }

    func testOpenMovesToRouteAndClearsForwardRoute() {
        var state = MeetingSettingsNavigationState(
            currentRoute: .root,
            forwardRoute: .export
        )

        state.open(.meetingPrompts)

        XCTAssertEqual(state.currentRoute, .meetingPrompts)
        XCTAssertNil(state.forwardRoute)
    }

    private var drillDownRoutes: [MeetingSettingsNavigationRoute] {
        [.monitoringTargets, .meetingPrompts, .export]
    }
}
