@testable import MeetingAssistantCore
import XCTest

@MainActor
final class MetricsDashboardViewModelTests: XCTestCase {
    func testLoad_RefreshesAfterFirstLoadEvenWhenAlreadyLoaded() async {
        let storage = MockStorageService()
        storage.mockTranscriptions = [
            makeTranscription(wordCount: 3),
        ]
        let viewModel = MetricsDashboardViewModel(storage: storage)

        await viewModel.load()
        XCTAssertEqual(viewModel.summary.sessionsRecorded, 1)
        XCTAssertEqual(viewModel.summary.wordsDictated, 3)

        storage.mockTranscriptions.append(makeTranscription(wordCount: 4))

        await viewModel.load()

        XCTAssertEqual(viewModel.summary.sessionsRecorded, 2)
        XCTAssertEqual(viewModel.summary.wordsDictated, 7)
    }

    func testHandleTranscriptionSaved_UpsertsSavedTranscriptionData() async {
        let storage = MockStorageService()
        let first = makeTranscription(wordCount: 2)
        let second = makeTranscription(wordCount: 5)
        storage.mockTranscriptions = [first]

        let viewModel = MetricsDashboardViewModel(storage: storage)
        await viewModel.load()
        XCTAssertEqual(viewModel.summary.sessionsRecorded, 1)

        storage.mockTranscriptions.append(second)
        let notification = Notification(
            name: .meetingAssistantTranscriptionSaved,
            object: nil,
            userInfo: [AppNotifications.UserInfoKey.transcriptionId: second.id.uuidString],
        )
        await viewModel.handleTranscriptionSaved(notification)

        XCTAssertEqual(viewModel.summary.sessionsRecorded, 2)
        XCTAssertEqual(viewModel.summary.wordsDictated, 7)
        XCTAssertTrue(viewModel.dailyBuckets.contains { $0.words >= 7 })
    }

    func testHandleTranscriptionSaved_MissingIDFallsBackToRefresh() async {
        let storage = MockStorageService()
        storage.mockTranscriptions = [
            makeTranscription(wordCount: 3),
        ]
        let viewModel = MetricsDashboardViewModel(storage: storage)

        await viewModel.load()
        XCTAssertEqual(viewModel.summary.sessionsRecorded, 1)

        storage.mockTranscriptions.append(makeTranscription(wordCount: 6))
        let notification = Notification(name: .meetingAssistantTranscriptionSaved)
        await viewModel.handleTranscriptionSaved(notification)

        XCTAssertEqual(viewModel.summary.sessionsRecorded, 2)
        XCTAssertEqual(viewModel.summary.wordsDictated, 9)
    }

    func testLoad_ComputesTopAppUsageBucketsWithOtherGroup() async {
        let storage = MockStorageService()
        storage.mockTranscriptions = [
            makeTranscription(wordCount: 10, app: .zoom),
            makeTranscription(wordCount: 10, app: .zoom),
            makeTranscription(wordCount: 10, app: .microsoftTeams),
            makeTranscription(wordCount: 10, app: .microsoftTeams),
            makeTranscription(wordCount: 10, app: .slack),
            makeTranscription(wordCount: 10, app: .discord),
            makeTranscription(wordCount: 10, app: .googleMeet),
            makeTranscription(wordCount: 10, app: .manualMeeting),
            makeTranscription(wordCount: 10, app: .unknown),
        ]

        let viewModel = MetricsDashboardViewModel(storage: storage)
        await viewModel.load()

        XCTAssertEqual(viewModel.appUsageBuckets.count, 7)
        XCTAssertEqual(viewModel.appUsageBuckets.first?.sessions, 2)
        XCTAssertTrue(
            viewModel.appUsageBuckets.contains {
                $0.appRawValue == MeetingApp.zoom.rawValue && $0.sessions == 2
            },
        )
        XCTAssertTrue(
            viewModel.appUsageBuckets.contains {
                $0.appRawValue == MeetingApp.microsoftTeams.rawValue && $0.sessions == 2
            },
        )
        XCTAssertTrue(viewModel.appUsageBuckets.last?.isOther ?? false)
        XCTAssertEqual(viewModel.appUsageBuckets.last?.sessions, 1)
    }

    private func makeTranscription(wordCount: Int, app: MeetingApp = .microsoftTeams) -> Transcription {
        let words = Array(repeating: "word", count: max(wordCount, 1)).joined(separator: " ")
        let start = Date()
        let end = start.addingTimeInterval(60)
        let meeting = Meeting(
            id: UUID(),
            app: app,
            startTime: start,
            endTime: end,
        )

        return Transcription(
            id: UUID(),
            meeting: meeting,
            text: words,
            rawText: words,
            createdAt: start,
        )
    }
}
