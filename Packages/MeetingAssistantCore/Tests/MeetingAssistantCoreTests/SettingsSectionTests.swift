@testable import MeetingAssistantCoreUI
import XCTest

final class SettingsSectionTests: XCTestCase {
    func testPrimarySections_OrderStartsWithCaptureWorkflows() {
        XCTAssertEqual(
            SettingsSection.primarySections,
            [.dictation, .meetings, .assistant, .integrations, .transcriptions, .metrics]
        )
    }

    func testSettingsSections_OrderStartsWithModelAndTextConfiguration() {
        XCTAssertEqual(
            SettingsSection.settingsSections,
            [.models, .enhancements, .vocabulary, .audio, .permissions, .general]
        )
    }
}
