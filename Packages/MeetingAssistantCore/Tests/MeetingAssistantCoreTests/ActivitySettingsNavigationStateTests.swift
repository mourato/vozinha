@testable import MeetingAssistantCoreUI
import MeetingAssistantCoreDomain
import XCTest

final class ActivitySettingsNavigationStateTests: XCTestCase {
    func testDefaultStateStartsAtRoot() {
        let state = ActivitySettingsNavigationState()

        XCTAssertEqual(state.activeRoute, .root)
        XCTAssertFalse(state.canGoBack)
    }

    func testHistoryListControlsSearchVisibility() {
        var state = ActivitySettingsNavigationState(activeRoute: .history)
        XCTAssertTrue(state.isShowingHistoryList)

        state.transcriptionsNavigationHistory.push(.conversation(UUID()))

        XCTAssertFalse(state.isShowingHistoryList)
    }

    func testApplyHistoryOpensHistoryList() {
        var state = ActivitySettingsNavigationState()

        state.apply(.history)

        XCTAssertEqual(state.activeRoute, .history)
        XCTAssertTrue(state.isShowingHistoryList)
    }

    func testBackForwardDelegatesToActiveHistoryRoute() {
        let conversationID = UUID()
        var history = TranscriptionsNavigationHistory()
        history.push(.conversation(conversationID))
        var state = ActivitySettingsNavigationState(
            activeRoute: .history,
            transcriptionsNavigationHistory: history
        )

        XCTAssertTrue(state.canGoBack)

        state.goBack()

        XCTAssertEqual(state.transcriptionsNavigationHistory.currentRoute, .list)
        XCTAssertTrue(state.canGoForward)
    }

    func testModelPerformanceBackReturnsToRoot() {
        var metricsState = SettingsSubpageNavigationState<MetricsDashboardRoute>()
        metricsState.open(.performance)
        var state = ActivitySettingsNavigationState(
            activeRoute: .modelPerformance,
            metricsNavigationState: metricsState
        )

        XCTAssertTrue(state.canGoBack)

        state.goBack()

        XCTAssertEqual(state.activeRoute, .root)
        XCTAssertTrue(state.canGoForward)
    }

    func testMoreInsightsBackReturnsToRoot() {
        var metricsState = SettingsSubpageNavigationState<MetricsDashboardRoute>()
        metricsState.open(.moreInsights)
        var state = ActivitySettingsNavigationState(
            activeRoute: .moreInsights,
            metricsNavigationState: metricsState
        )

        state.goBack()

        XCTAssertEqual(state.activeRoute, .root)
        XCTAssertTrue(state.canGoForward)
    }

    func testNestedPerformanceRecordingBackDelegatesBeforeReturningToRoot() {
        let recordingID = UUID()
        var metricsState = SettingsSubpageNavigationState<MetricsDashboardRoute>()
        metricsState.open(.performanceRecording(recordingID))
        var state = ActivitySettingsNavigationState(
            activeRoute: .modelPerformance,
            metricsNavigationState: metricsState
        )

        state.goBack()

        XCTAssertEqual(state.activeRoute, .modelPerformance)
        XCTAssertNil(state.metricsNavigationState.currentRoute)

        state.goBack()

        XCTAssertEqual(state.activeRoute, .root)
    }

    func testCalendarEventDetailBackReturnsToRoot() {
        let event = MeetingCalendarEventSnapshot(
            eventIdentifier: "event-1",
            title: "Planning",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1_800),
            location: nil,
            notes: nil,
            attendees: []
        )
        var state = ActivitySettingsNavigationState()

        state.open(.eventDetail(event))

        XCTAssertEqual(state.activeRoute, .eventDetail(event))
        XCTAssertEqual(state.metricsNavigationState.currentRoute, .eventDetail(event))

        state.goBack()

        XCTAssertEqual(state.activeRoute, .root)
        XCTAssertTrue(state.canGoForward)
    }
}
