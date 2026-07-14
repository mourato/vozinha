@testable import MeetingAssistantCore
import XCTest

final class SettingsSubpageNavigationStateTests: XCTestCase {
    private enum Route: Hashable {
        case first
        case second
    }

    func testInitialStateStartsAtRoot() {
        let state = SettingsSubpageNavigationState<Route>()

        XCTAssertNil(state.currentRoute)
        XCTAssertFalse(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
    }

    func testOpenMakesDetailRouteCurrent() {
        var state = SettingsSubpageNavigationState<Route>()

        state.open(.first)

        XCTAssertEqual(state.currentRoute, .first)
        XCTAssertTrue(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
    }

    func testBackReturnsToRootAndPreservesForwardRoute() {
        var state = SettingsSubpageNavigationState<Route>(currentRoute: .first)

        _ = state.goBack()

        XCTAssertNil(state.currentRoute)
        XCTAssertFalse(state.canGoBack)
        XCTAssertTrue(state.canGoForward)
        XCTAssertEqual(state.forwardRoute, .first)
    }

    func testForwardRestoresDetailRouteAndClearsForwardRoute() {
        var state = SettingsSubpageNavigationState<Route>(forwardRoute: .second)

        _ = state.goForward()

        XCTAssertEqual(state.currentRoute, .second)
        XCTAssertTrue(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
        XCTAssertNil(state.forwardRoute)
    }

    func testOpeningNewRouteDropsForwardHistory() {
        var state = SettingsSubpageNavigationState<Route>(forwardRoute: .first)

        state.open(.second)

        XCTAssertEqual(state.currentRoute, .second)
        XCTAssertTrue(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
        XCTAssertNil(state.forwardRoute)
    }

    func testDictationStyleRoutesPreserveEditorChildEditorSequence() {
        var state = SettingsSubpageNavigationState<DictationStyleRoute>()
        let styleID = UUID()

        state.open(.editor(styleID: styleID))
        XCTAssertEqual(state.currentRoute, .editor(styleID: styleID))

        state.open(.promptEditor(styleID: styleID))
        XCTAssertEqual(state.currentRoute, .promptEditor(styleID: styleID))

        state.open(.editor(styleID: styleID))
        XCTAssertEqual(state.currentRoute, .editor(styleID: styleID))

        _ = state.goBack()
        XCTAssertNil(state.currentRoute)
    }
}
