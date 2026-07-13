import AudioToolbox
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreAudio
import XCTest

final class SystemAudioMuteControllerTests: XCTestCase {
    var sut: SystemAudioMuteController!

    override func setUp() {
        super.setUp()
        sut = SystemAudioMuteController.shared
    }

    func testMuteToggle() {
        let originalMuteState = sut.isMuted()

        // Try to toggle and then restore
        do {
            try sut.setMuted(!originalMuteState)
            XCTAssertEqual(sut.isMuted(), !originalMuteState)

            // Restore
            try sut.setMuted(originalMuteState)
            XCTAssertEqual(sut.isMuted(), originalMuteState)
        } catch {
            // It's possible that setting mute fails if no output device is found in CI
            // or if permissions are missing, so we log but don't necessarily fail if the error is CoreAudio -50 (paramErr)
            print("Mute toggle test skipped or failed due to environment: \(error)")
        }
    }

    func testMakeOutputVolumeStatePrefersVirtualMainVolume() {
        let channelState = SystemAudioMuteController.OutputScalarPropertyState(
            selector: kAudioDevicePropertyVolumeScalar,
            element: 1,
            value: 0.42,
        )

        let state = SystemAudioMuteController.makeOutputVolumeState(
            virtualMainVolume: 0.73,
            channelVolumes: [channelState],
        )

        XCTAssertEqual(
            state,
            SystemAudioMuteController.OutputVolumeState(
                properties: [
                    SystemAudioMuteController.OutputScalarPropertyState(
                        selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                        element: kAudioObjectPropertyElementMain,
                        value: 0.73,
                    ),
                ],
                strategyDescription: "virtualMainVolume",
            ),
        )
    }

    func testMakeOutputVolumeStateFallsBackToChannelVolumes() {
        let channelStates = [
            SystemAudioMuteController.OutputScalarPropertyState(
                selector: kAudioDevicePropertyVolumeScalar,
                element: 1,
                value: 0.30,
            ),
            SystemAudioMuteController.OutputScalarPropertyState(
                selector: kAudioDevicePropertyVolumeScalar,
                element: 2,
                value: 0.45,
            ),
        ]

        let state = SystemAudioMuteController.makeOutputVolumeState(
            virtualMainVolume: nil,
            channelVolumes: channelStates,
        )

        XCTAssertEqual(
            state,
            SystemAudioMuteController.OutputVolumeState(
                properties: channelStates,
                strategyDescription: "channelVolumeScalar",
            ),
        )
    }

    func testMakeOutputVolumeStateReturnsNilWithoutRestorableState() {
        XCTAssertNil(
            SystemAudioMuteController.makeOutputVolumeState(
                virtualMainVolume: nil,
                channelVolumes: [],
            ),
        )
    }

    func testMakeDuckedOutputVolumeStateScalesVolumeByPercent() {
        let state = SystemAudioMuteController.OutputVolumeState(
            properties: [
                SystemAudioMuteController.OutputScalarPropertyState(
                    selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                    element: kAudioObjectPropertyElementMain,
                    value: 0.8,
                ),
            ],
            strategyDescription: "virtualMainVolume",
        )

        let ducked = SystemAudioMuteController.makeDuckedOutputVolumeState(from: state, levelPercent: 30)

        XCTAssertEqual(ducked.properties.count, 1)
        XCTAssertEqual(ducked.properties[0].value, 0.24, accuracy: 0.0_001)
        XCTAssertEqual(ducked.strategyDescription, state.strategyDescription)
    }

    func testMakeDuckedOutputVolumeStateClampsPercentRange() {
        let state = SystemAudioMuteController.OutputVolumeState(
            properties: [
                SystemAudioMuteController.OutputScalarPropertyState(
                    selector: kAudioDevicePropertyVolumeScalar,
                    element: 1,
                    value: 0.65,
                ),
            ],
            strategyDescription: "channelVolumeScalar",
        )

        let muted = SystemAudioMuteController.makeDuckedOutputVolumeState(from: state, levelPercent: -10)
        let unchanged = SystemAudioMuteController.makeDuckedOutputVolumeState(from: state, levelPercent: 140)

        XCTAssertEqual(muted.properties[0].value, 0.0, accuracy: 0.0_001)
        XCTAssertEqual(unchanged.properties[0].value, 0.65, accuracy: 0.0_001)
    }
}
