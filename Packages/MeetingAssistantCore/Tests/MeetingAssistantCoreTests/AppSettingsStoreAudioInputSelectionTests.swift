@testable import MeetingAssistantCore
import XCTest

@MainActor
final class AppSettingsStoreAudioInputSelectionTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testMigrateLegacyAudioDevicePriorityToPowerSelection_UsesFirstLegacyUIDForBothStates() {
        settings.audioDevicePriority = ["usb-mic-primary", "usb-mic-backup"]
        settings.microphoneWhenChargingUID = nil
        settings.microphoneOnBatteryUID = nil

        settings.migrateLegacyAudioDevicePriorityToPowerSelectionIfNeeded()

        XCTAssertEqual(settings.microphoneWhenChargingUID, "usb-mic-primary")
        XCTAssertEqual(settings.microphoneOnBatteryUID, "usb-mic-primary")
    }

    func testMigrateLegacyAudioDevicePriorityToPowerSelection_DoesNotOverrideExistingSelection() {
        settings.audioDevicePriority = ["usb-mic-primary", "usb-mic-backup"]
        settings.microphoneWhenChargingUID = "already-selected"
        settings.microphoneOnBatteryUID = nil

        settings.migrateLegacyAudioDevicePriorityToPowerSelectionIfNeeded()

        XCTAssertEqual(settings.microphoneWhenChargingUID, "already-selected")
        XCTAssertNil(settings.microphoneOnBatteryUID)
    }
}
