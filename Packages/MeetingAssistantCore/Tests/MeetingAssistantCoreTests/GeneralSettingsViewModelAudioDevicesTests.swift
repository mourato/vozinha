@testable import MeetingAssistantCore
import XCTest

@MainActor
final class GeneralSettingsAudioDevicesTests: XCTestCase {
    private var settings: AppSettingsStore!

    override func setUp() async throws {
        settings = .shared
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings.resetToDefaults()
        settings = nil
    }

    func testMicrophoneSelectionsArePersistedInSettingsStore() {
        let viewModel = GeneralSettingsViewModel(settingsStore: settings)

        viewModel.microphoneWhenChargingUID = "charging-mic-id"
        viewModel.microphoneOnBatteryUID = "battery-mic-id"

        XCTAssertEqual(settings.microphoneWhenChargingUID, "charging-mic-id")
        XCTAssertEqual(settings.microphoneOnBatteryUID, "battery-mic-id")
    }

    func testUnavailablePersistedSelectionRemainsVisibleInDeviceList() {
        let viewModel = GeneralSettingsViewModel(settingsStore: settings)
        let missingUID = "missing-device-uid-for-tests"

        viewModel.microphoneWhenChargingUID = missingUID

        XCTAssertTrue(viewModel.availableDevices.contains(where: { device in
            device.id == missingUID && device.isAvailable == false
        }))
    }

    func testMicrophoneSelectionsSurviveViewModelReload() {
        let firstViewModel = GeneralSettingsViewModel(settingsStore: settings)
        firstViewModel.microphoneWhenChargingUID = "charging-mic-id"
        firstViewModel.microphoneOnBatteryUID = "battery-mic-id"

        let reloadedViewModel = GeneralSettingsViewModel(settingsStore: settings)

        XCTAssertEqual(reloadedViewModel.microphoneWhenChargingUID, "charging-mic-id")
        XCTAssertEqual(reloadedViewModel.microphoneOnBatteryUID, "battery-mic-id")
    }
}
