@testable import MeetingAssistantCoreUI
import XCTest

final class SettingsSectionTests: XCTestCase {
    func testPrimarySections_OrderStartsWithCaptureWorkflows() {
        XCTAssertEqual(
            SettingsSection.primarySections,
            [.activity, .dictation, .meetings, .assistant, .integrations],
        )
    }

    func testSettingsSections_OrderStartsWithConsolidatedSections() {
        XCTAssertEqual(
            SettingsSection.settingsSections,
            [.system],
        )
    }

    func testVisibleSections_OrderMatchesProductConcepts() {
        XCTAssertEqual(
            SettingsSection.visibleSections,
            [.activity, .dictation, .meetings, .assistant, .integrations, .system],
        )
    }

    func testLegacyRedirect_MetricsAndTranscriptionsMapToActivity() {
        XCTAssertEqual(SettingsSection.metrics.visibleSection, .activity)
        XCTAssertEqual(SettingsSection.transcriptions.visibleSection, .activity)
        XCTAssertTrue(SettingsSection.metrics.isLegacyRedirect)
        XCTAssertTrue(SettingsSection.transcriptions.isLegacyRedirect)
    }

    func testLegacyRedirect_ModelsEnhancementsVocabularyMapToNewHomes() {
        XCTAssertEqual(SettingsSection.models.visibleSection, .system)
        XCTAssertEqual(SettingsSection.enhancements.visibleSection, .dictation)
        XCTAssertEqual(SettingsSection.vocabulary.visibleSection, .system)
        XCTAssertTrue(SettingsSection.models.isLegacyRedirect)
        XCTAssertTrue(SettingsSection.enhancements.isLegacyRedirect)
        XCTAssertTrue(SettingsSection.vocabulary.isLegacyRedirect)
    }

    func testLegacyRedirect_PermissionsGeneralAndAudioMapToSystem() {
        XCTAssertEqual(SettingsSection.audio.visibleSection, .system)
        XCTAssertEqual(SettingsSection.permissions.visibleSection, .system)
        XCTAssertEqual(SettingsSection.general.visibleSection, .system)
        XCTAssertTrue(SettingsSection.audio.isLegacyRedirect)
        XCTAssertTrue(SettingsSection.permissions.isLegacyRedirect)
        XCTAssertTrue(SettingsSection.general.isLegacyRedirect)
    }

    func testVisibleSections_AreNotLegacyRedirects() {
        for section in SettingsSection.visibleSections {
            XCTAssertFalse(section.isLegacyRedirect, "\(section) should not be a legacy redirect")
        }
    }

    func testResolvedVisibleSection_ParsesOldRawValues() {
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "metrics"), .activity)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "transcriptions"), .activity)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "models"), .system)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "enhancements"), .dictation)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "vocabulary"), .system)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "audio"), .system)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "permissions"), .system)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "general"), .system)
    }

    func testResolvedDestination_PreservesLegacyActivitySubroutes() {
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "metrics"),
            SettingsDestination(section: .activity, activityRoute: .modelPerformance),
        )
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "transcriptions"),
            SettingsDestination(section: .activity, activityRoute: .history),
        )
    }

    func testResolvedDestination_PreservesSystemSubroutes() {
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "general"),
            SettingsDestination(section: .system),
        )
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "permissions"),
            SettingsDestination(section: .system, systemRoute: .permissions),
        )
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "audio"),
            SettingsDestination(section: .system, systemRoute: .sound),
        )
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "models"),
            SettingsDestination(section: .system, systemRoute: .models),
        )
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "vocabulary"),
            SettingsDestination(section: .system, systemRoute: .dictionary),
        )
        XCTAssertEqual(
            SettingsSection.resolvedDestination(for: "enhancements"),
            SettingsDestination(section: .dictation, dictationRoute: .postProcessing),
        )
    }

    func testResolvedVisibleSection_ParsesNewRawValues() {
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "activity"), .activity)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "dictation"), .dictation)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "intelligence"), .system)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "system"), .system)
        XCTAssertEqual(SettingsSection.resolvedVisibleSection(for: "audio"), .system)
    }

    func testOldRawValuesStillParseAsSettingsSection() {
        XCTAssertEqual(SettingsSection(rawValue: "metrics"), .metrics)
        XCTAssertEqual(SettingsSection(rawValue: "transcriptions"), .transcriptions)
        XCTAssertEqual(SettingsSection(rawValue: "models"), .models)
        XCTAssertEqual(SettingsSection(rawValue: "enhancements"), .enhancements)
        XCTAssertEqual(SettingsSection(rawValue: "vocabulary"), .vocabulary)
        XCTAssertEqual(SettingsSection(rawValue: "audio"), .audio)
        XCTAssertEqual(SettingsSection(rawValue: "permissions"), .permissions)
        XCTAssertEqual(SettingsSection(rawValue: "general"), .general)
    }

    func testNewRawValuesParse() {
        XCTAssertEqual(SettingsSection(rawValue: "activity"), .activity)
        XCTAssertEqual(SettingsSection(rawValue: "intelligence"), .intelligence)
        XCTAssertEqual(SettingsSection(rawValue: "system"), .system)
    }
}
