import Foundation
@testable import MeetingAssistantCoreDomain
@testable import MeetingAssistantCoreInfrastructure
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class ExtractedWorkflowServicesTests: XCTestCase {
    private var settings: AppSettingsStore!
    private var originalContextAwarenessEnabled = false
    private var originalIncludeAccessibilityText = false
    private var originalIncludeClipboard = false
    private var originalIncludeWindowOCR = false
    private var originalRedactSensitiveData = false
    private var originalExcludedBundleIDs: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        try AppSettingsTestIsolationLock.acquire()
        settings = .shared
        originalContextAwarenessEnabled = settings.contextAwarenessEnabled
        originalIncludeAccessibilityText = settings.contextAwarenessIncludeAccessibilityText
        originalIncludeClipboard = settings.contextAwarenessIncludeClipboard
        originalIncludeWindowOCR = settings.contextAwarenessIncludeWindowOCR
        originalRedactSensitiveData = settings.contextAwarenessRedactSensitiveData
        originalExcludedBundleIDs = settings.contextAwarenessExcludedBundleIDs
    }

    override func tearDown() async throws {
        settings.contextAwarenessEnabled = originalContextAwarenessEnabled
        settings.contextAwarenessIncludeAccessibilityText = originalIncludeAccessibilityText
        settings.contextAwarenessIncludeClipboard = originalIncludeClipboard
        settings.contextAwarenessIncludeWindowOCR = originalIncludeWindowOCR
        settings.contextAwarenessRedactSensitiveData = originalRedactSensitiveData
        settings.contextAwarenessExcludedBundleIDs = originalExcludedBundleIDs
        settings = nil
        AppSettingsTestIsolationLock.release()
        try await super.tearDown()
    }

    func testMeetingCalendarIntegrationService_AppliesBestMatchingEventTitle() async {
        let event = MeetingCalendarEventSnapshot(
            eventIdentifier: "event-1",
            title: " Design Review ",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3_600),
            attendees: ["Alice", "Bob"]
        )
        let calendarService = MockCalendarEventServiceForExtraction()
        calendarService.eventsToReturn = [event]
        let service = MeetingCalendarIntegrationService(
            calendarEventService: calendarService,
            ignoredEventIdentifiers: { [] }
        )

        let result = await service.applyAutomaticCalendarEventIfAvailable(
            to: Meeting(app: .zoom, capturePurpose: .meeting)
        )

        XCTAssertEqual(result.linkedCalendarEvent?.eventIdentifier, event.eventIdentifier)
        XCTAssertEqual(result.title, "Design Review")
    }

    func testAssistantContextCaptureService_ReturnsActiveTabWhenContextAwarenessDisabled() async {
        settings.contextAwarenessEnabled = false

        let service = AssistantContextCaptureService(
            contextAwarenessService: MockContextAwarenessService(),
            textContextProvider: MockTextContextProvider(text: nil),
            textContextGuardrails: TextContextGuardrails(),
            textContextPolicy: .default,
            isAccessibilityTrusted: { true },
            requestAccessibilityPermission: {}
        )

        let result = await service.capturePostProcessingContext(
            for: Meeting(app: .googleMeet, capturePurpose: .meeting),
            settings: settings,
            activeTabURL: "https://example.com",
            calendarContext: nil,
            isDictationMode: false
        )

        XCTAssertNil(result.context)
        XCTAssertEqual(result.items.map { $0.source }, [TranscriptionContextItem.Source.activeTabURL])
        XCTAssertEqual(result.items.first?.text, "https://example.com")
    }

    func testAssistantContextCaptureService_AppendsFocusedTextForDictationFallback() async {
        settings.contextAwarenessEnabled = true
        settings.contextAwarenessIncludeAccessibilityText = true
        settings.contextAwarenessIncludeClipboard = false
        settings.contextAwarenessIncludeWindowOCR = false
        settings.contextAwarenessRedactSensitiveData = false
        settings.contextAwarenessExcludedBundleIDs = []

        let contextService = MockContextAwarenessService()
        contextService.snapshot = ContextAwarenessSnapshot(
            activeAppName: "Safari",
            activeWindowTitle: "Draft",
            activeAccessibilityText: nil,
            clipboardText: nil,
            activeWindowOCRText: nil
        )
        contextService.context = "CONTEXT_METADATA\n- Active app: Safari"

        let service = AssistantContextCaptureService(
            contextAwarenessService: contextService,
            textContextProvider: MockTextContextProvider(text: "Focused draft"),
            textContextGuardrails: TextContextGuardrails(),
            textContextPolicy: .default,
            isAccessibilityTrusted: { true },
            requestAccessibilityPermission: {}
        )

        let result = await service.capturePostProcessingContext(
            for: Meeting(app: .unknown, capturePurpose: .dictation),
            settings: settings,
            activeTabURL: nil,
            calendarContext: nil,
            isDictationMode: true
        )

        XCTAssertTrue(
            result.items.contains(where: {
                $0.source == TranscriptionContextItem.Source.focusedText && $0.text == "Focused draft"
            })
        )
        XCTAssertTrue(result.context?.contains("Focused draft") == true)
    }
}

@MainActor
private final class MockCalendarEventServiceForExtraction: CalendarEventServiceProtocol, @unchecked Sendable {
    var eventsToReturn: [MeetingCalendarEventSnapshot] = []

    func authorizationState() -> PermissionState { .granted }
    func requestAccess() async -> PermissionState { .granted }
    func openSystemSettings() {}

    func fetchUpcomingEvents(
        limit _: Int,
        now _: Date,
        window _: TimeInterval,
        ignoredEventIdentifiers _: Set<String>
    ) throws -> [MeetingCalendarEventSnapshot] {
        eventsToReturn
    }

    func bestMatchingEvent(
        at _: Date,
        in events: [MeetingCalendarEventSnapshot]
    ) -> MeetingCalendarEventSnapshot? {
        events.first
    }
}

@MainActor
private final class MockContextAwarenessService: ContextAwarenessServiceProtocol, @unchecked Sendable {
    var snapshot = ContextAwarenessSnapshot(
        activeAppName: nil,
        activeWindowTitle: nil,
        activeAccessibilityText: nil,
        clipboardText: nil,
        activeWindowOCRText: nil
    )
    var context: String?

    func captureSnapshot(options _: ContextAwarenessCaptureOptions) async -> ContextAwarenessSnapshot {
        snapshot
    }

    func makePostProcessingContext(from _: ContextAwarenessSnapshot) -> String? {
        context
    }
}

private struct MockTextContextProvider: TextContextProvider {
    let text: String?

    func fetchTextContext() async throws -> TextContextSnapshot {
        TextContextSnapshot(
            text: text ?? "",
            source: .accessibility,
            appContext: ActiveAppContext(bundleIdentifier: "com.apple.Safari", name: "Safari", processIdentifier: 1)
        )
    }
}
