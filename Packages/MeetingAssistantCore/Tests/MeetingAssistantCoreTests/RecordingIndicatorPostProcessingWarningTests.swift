import XCTest
@testable import MeetingAssistantCore
@testable import MeetingAssistantCoreUI

@MainActor
final class RecordingIndicatorPPWarningTests: XCTestCase {
    func testMessageKey_ForMissingModel() {
        let descriptor = RecordingIndicatorPostProcessingWarningDescriptor(
            issue: .missingModel,
            mode: .meeting
        )

        XCTAssertEqual(descriptor.messageKey, "recording_indicator.post_processing_warning.missing_model")
        XCTAssertEqual(descriptor.settingsSection, SettingsSection.intelligence.rawValue)
    }

    func testMessageKey_ForMissingAPIKey() {
        let descriptor = RecordingIndicatorPostProcessingWarningDescriptor(
            issue: .missingAPIKey,
            mode: .dictation
        )

        XCTAssertEqual(descriptor.messageKey, "recording_indicator.post_processing_warning.missing_api_key")
    }

    func testMessageKey_ForInvalidBaseURL() {
        let descriptor = RecordingIndicatorPostProcessingWarningDescriptor(
            issue: .invalidBaseURL,
            mode: .assistant
        )

        XCTAssertEqual(descriptor.messageKey, "recording_indicator.post_processing_warning.invalid_base_url")
    }

    func testOpenSettings_UsesIntelligenceSection() {
        let descriptor = RecordingIndicatorPostProcessingWarningDescriptor(
            issue: .missingModel,
            mode: .meeting
        )
        var capturedSection: String?

        descriptor.openSettings { section in
            capturedSection = section
        }

        XCTAssertEqual(capturedSection, SettingsSection.intelligence.rawValue)
    }
}
