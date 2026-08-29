import MeetingAssistantCoreDomain
@testable import MeetingAssistantCoreInfrastructure
import XCTest

@MainActor
final class AppSettingsStoreMeetingReminderTests: XCTestCase {
    override func tearDown() async throws {
        [
            AppSettingsStore.Keys.meetingRemindersEnabled,
            AppSettingsStore.Keys.meetingReminderLeadMinutes,
            AppSettingsStore.Keys.meetingReminderOverlayLeadSeconds,
            AppSettingsStore.Keys.meetingReminderOverlayEnabled,
            AppSettingsStore.Keys.meetingReminderAlertSoundEnabled,
            AppSettingsStore.Keys.meetingReminderMirrorAllScreens,
            AppSettingsStore.Keys.meetingReminderDismissedEventKeys,
        ].forEach(UserDefaults.standard.removeObject)
        AppSettingsStore.shared.resetToDefaults()
    }

    func testMeetingReminderDefaultsRoundTrip() {
        removeReminderDefaults()
        let meeting = AppSettingsStore.loadMeetingSummarySettings()

        XCTAssertTrue(meeting.meetingRemindersEnabled)
        XCTAssertEqual(meeting.meetingReminderLeadMinutes, 15)
        XCTAssertEqual(meeting.meetingReminderOverlayLeadSeconds, 0)
        XCTAssertTrue(meeting.meetingReminderOverlayEnabled)
        XCTAssertFalse(meeting.meetingReminderAlertSoundEnabled)
        XCTAssertFalse(meeting.meetingReminderMirrorAllScreens)
    }

    func testMeetingReminderExplicitValuesPersist() {
        let settings = AppSettingsStore.shared

        settings.meetingRemindersEnabled = false
        settings.meetingReminderLeadMinutes = 5
        settings.meetingReminderOverlayLeadSeconds = 30
        settings.meetingReminderOverlayEnabled = false
        settings.meetingReminderAlertSoundEnabled = true
        settings.meetingReminderMirrorAllScreens = true

        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppSettingsStore.Keys.meetingRemindersEnabled))
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppSettingsStore.Keys.meetingReminderLeadMinutes), 5)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppSettingsStore.Keys.meetingReminderOverlayLeadSeconds), 30)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppSettingsStore.Keys.meetingReminderOverlayEnabled))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppSettingsStore.Keys.meetingReminderAlertSoundEnabled))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppSettingsStore.Keys.meetingReminderMirrorAllScreens))
    }

    func testDismissedOccurrenceKeyIsStable() {
        let event = MeetingCalendarEventSnapshot(
            eventIdentifier: "abc",
            title: "Standup",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_000_900),
        )

        let key = AppSettingsStore.meetingReminderOccurrenceKey(for: event)
        XCTAssertEqual(key, "abc-1700000000.0")

        AppSettingsStore.shared.dismissMeetingReminderOccurrence(for: event)
        XCTAssertTrue(AppSettingsStore.shared.meetingReminderDismissedOccurrenceKeys().contains(key))
    }

    private func removeReminderDefaults() {
        [
            AppSettingsStore.Keys.meetingRemindersEnabled,
            AppSettingsStore.Keys.meetingReminderLeadMinutes,
            AppSettingsStore.Keys.meetingReminderOverlayLeadSeconds,
            AppSettingsStore.Keys.meetingReminderOverlayEnabled,
            AppSettingsStore.Keys.meetingReminderAlertSoundEnabled,
            AppSettingsStore.Keys.meetingReminderMirrorAllScreens,
        ].forEach(UserDefaults.standard.removeObject)
    }
}
