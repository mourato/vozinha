@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreAudio
import XCTest

@MainActor
final class RecordingIndicatorConfigurationTests: XCTestCase {
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

    func testRecordingIndicatorStyle_PersistsSuperRawValueInUserDefaults() {
        settings.recordingIndicatorStyle = .super

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "recordingIndicatorStyle"),
            RecordingIndicatorStyle.super.rawValue,
        )
    }

    func testRecordingIndicatorStyle_ResetToDefaultsRestoresMini() {
        settings.recordingIndicatorStyle = .super

        settings.resetToDefaults()

        XCTAssertEqual(settings.recordingIndicatorStyle, .mini)
    }

    func testWaveformBarCount_ForSuper_IsEighty() {
        XCTAssertEqual(AudioRecorder.waveformBarCount(for: .super), 80)
    }
}
