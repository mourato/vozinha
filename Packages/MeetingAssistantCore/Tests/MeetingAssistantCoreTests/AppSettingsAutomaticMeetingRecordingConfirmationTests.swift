@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreInfrastructure
import XCTest

@MainActor
final class AutoMeetingConfirmationSettingsTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        try AppSettingsTestIsolationLock.acquire()
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
        AppSettingsTestIsolationLock.release()
    }

    func testConfirmationDelayDefaultsToThreeSecondsAfterReset() {
        settings.automaticAutomaticMeetingRecordingConfirmationDelay = .seconds9

        settings.resetToDefaults()

        XCTAssertEqual(settings.automaticAutomaticMeetingRecordingConfirmationDelay, .seconds3)
    }

    func testConfirmationDelayPersistsSupportedRawValues() {
        for delay in AppSettingsStore.AutomaticMeetingRecordingConfirmationDelay.allCases {
            settings.automaticAutomaticMeetingRecordingConfirmationDelay = delay

            XCTAssertEqual(
                UserDefaults.standard.integer(forKey: "automaticAutomaticMeetingRecordingConfirmationDelay"),
                delay.rawValue,
            )
        }
    }

    func testConfirmationDelayRejectsUnsupportedPersistedValues() {
        UserDefaults.standard.set(12, forKey: "automaticAutomaticMeetingRecordingConfirmationDelay")

        let loaded = AppSettingsStore.loadUIAndIndicatorSettings()

        XCTAssertEqual(loaded.automaticAutomaticMeetingRecordingConfirmationDelay, .seconds3)
    }
}
